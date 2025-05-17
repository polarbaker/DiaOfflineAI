#!/bin/bash
#
# Dia Voice Assistant RAG Update Script
# 
# This script updates the RAG database with documents from external sources
# such as USB drives or directories.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
DIA_PATH="/opt/dia"
VENV_PATH="$DIA_PATH/venv"
RAG_PATH="/mnt/nvme/dia/rag"
FALLBACK_RAG_PATH="$DIA_PATH/models/rag"

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}===== $1 =====${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# Display help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --source <path>   Path to source directory containing documents (required)"
    echo "  --format <type>   Format of documents (txt, pdf, md, all)"
    echo "  --tag <tag>       Tag to apply to imported documents"
    echo "  --recursive       Search recursively for documents"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --source /media/usb --format all --recursive"
    echo "  $0 --source ~/Documents --format pdf --tag reference"
    exit 0
}

# Check for no arguments
if [ $# -eq 0 ]; then
    show_help
fi

# Default values
FORMAT="all"
RECURSIVE=false
TAG=""

# Process options
while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --recursive)
            RECURSIVE=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            ;;
    esac
done

# Check required parameters
if [ -z "$SOURCE_PATH" ]; then
    print_error "Source path is required. Use --source <path>"
fi

# Verify source path exists
if [ ! -d "$SOURCE_PATH" ]; then
    print_error "Source path '$SOURCE_PATH' not found or is not a directory"
fi

# Display welcome message
print_header "Dia Voice Assistant RAG Update Tool"

# Check if we have an NVMe mounted
if [ -d "/mnt/nvme" ]; then
    RAG_PATH="/mnt/nvme/dia/rag"
else
    print_warning "NVMe not detected, using fallback storage path"
    RAG_PATH="$FALLBACK_RAG_PATH"
fi

# Ensure RAG path exists
mkdir -p "$RAG_PATH"

# Check for Python virtual environment
if [ ! -d "$VENV_PATH" ]; then
    print_error "Python virtual environment not found at $VENV_PATH"
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Create a temporary Python script for importing documents
TMP_SCRIPT=$(mktemp)
cat > "$TMP_SCRIPT" << 'EOF'
#!/usr/bin/env python3
"""
Script to update the RAG database with documents from external sources.
"""

import os
import sys
import argparse
import json
import logging
from pathlib import Path

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("rag_update")

# Add the Dia assistant path to Python path
dia_path = "/opt/dia"
sys.path.append(dia_path)

# Import RAG modules
try:
    from src.rag.retriever import RagRetriever
    from src.utils.config_loader import load_config
except ImportError as e:
    logger.error(f"Error importing Dia modules: {e}")
    logger.error(f"Check that Dia is correctly installed at {dia_path}")
    sys.exit(1)

def read_text_file(file_path):
    """Read text from a file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        # Try with Latin-1 encoding if UTF-8 fails
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Failed to read {file_path}: {e}")
            return None
    except Exception as e:
        logger.error(f"Failed to read {file_path}: {e}")
        return None

def read_pdf_file(file_path):
    """Read text from a PDF file."""
    try:
        import pypdf
        text = ""
        with open(file_path, 'rb') as f:
            pdf = pypdf.PdfReader(f)
            for page in pdf.pages:
                text += page.extract_text() + "\n\n"
        return text
    except ImportError:
        logger.error("pypdf module not installed. Install with: pip install pypdf")
        return None
    except Exception as e:
        logger.error(f"Failed to read PDF {file_path}: {e}")
        return None

def read_markdown_file(file_path):
    """Read text from a markdown file."""
    return read_text_file(file_path)

def get_file_reader(file_format):
    """Get the appropriate file reader function for a format."""
    readers = {
        "txt": read_text_file,
        "text": read_text_file,
        "pdf": read_pdf_file,
        "md": read_markdown_file,
        "markdown": read_markdown_file
    }
    return readers.get(file_format.lower())

def find_documents(source_path, formats, recursive=False):
    """Find all document files in the source path."""
    documents = []
    
    if isinstance(formats, str):
        formats = [formats]
    
    # Convert formats to lowercase
    formats = [f.lower() for f in formats]
    
    # Handle 'all' format
    if "all" in formats:
        formats = ["txt", "text", "pdf", "md", "markdown"]
    
    # Find files
    p = Path(source_path)
    
    # Define glob pattern based on recursivity
    pattern = "**/*" if recursive else "*"
    
    # Find files with matching extensions
    for format in formats:
        for file_path in p.glob(f"{pattern}.{format}"):
            if file_path.is_file():
                documents.append(str(file_path))
    
    return documents

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="Update Dia's RAG database with documents")
    parser.add_argument("--source", required=True, help="Source directory containing documents")
    parser.add_argument("--format", default="all", help="Document format (txt, pdf, md, all)")
    parser.add_argument("--tag", default="", help="Tag to apply to imported documents")
    parser.add_argument("--recursive", action="store_true", help="Search recursively")
    
    args = parser.parse_args()
    
    # Check source path
    if not os.path.isdir(args.source):
        logger.error(f"Source path '{args.source}' not found or is not a directory")
        return 1
    
    # Split format string if comma-separated
    formats = args.format.split(",")
    
    # Find documents
    logger.info(f"Searching for documents in {args.source} (formats: {formats}, recursive: {args.recursive})")
    documents = find_documents(args.source, formats, args.recursive)
    
    if not documents:
        logger.warning(f"No matching documents found in {args.source}")
        return 0
    
    logger.info(f"Found {len(documents)} documents")
    
    # Load configuration
    config_path = os.path.join(dia_path, "config", "dia.yaml")
    config = load_config(config_path)
    
    # Initialize RAG system
    rag_config = config.get("rag", {})
    rag_config["enabled"] = True  # Ensure RAG is enabled
    
    rag = RagRetriever(rag_config)
    
    # Process each document
    success_count = 0
    error_count = 0
    
    for doc_path in documents:
        try:
            # Get file format
            file_format = os.path.splitext(doc_path)[1][1:].lower()
            
            # Get appropriate reader
            reader = get_file_reader(file_format)
            
            if not reader:
                logger.warning(f"Unsupported file format: {file_format} for {doc_path}")
                error_count += 1
                continue
            
            # Read content
            content = reader(doc_path)
            
            if not content:
                logger.warning(f"Failed to read content from {doc_path}")
                error_count += 1
                continue
            
            # Get file name as title
            title = os.path.basename(doc_path)
            
            # Create metadata
            metadata = {
                "source_path": doc_path,
                "format": file_format
            }
            
            if args.tag:
                metadata["tag"] = args.tag
            
            # Add to RAG system
            doc_id = rag.add_document(title, content, source=doc_path, metadata=metadata)
            
            if doc_id:
                logger.info(f"Added document: {title} ({doc_id})")
                success_count += 1
            else:
                logger.error(f"Failed to add document: {title}")
                error_count += 1
                
        except Exception as e:
            logger.error(f"Error processing {doc_path}: {e}")
            error_count += 1
    
    # Final report
    logger.info(f"RAG update complete. Added {success_count} documents, {error_count} errors.")
    
    return 0 if error_count == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
EOF

# Make the temporary script executable
chmod +x "$TMP_SCRIPT"

# Run the Python script with appropriate arguments
print_header "Updating RAG Database"
echo "Source path: $SOURCE_PATH"
echo "Format: $FORMAT"
echo "Recursive: $RECURSIVE"
echo "Tag: $TAG"
echo ""

RECURSIVE_ARG=""
if [ "$RECURSIVE" = true ]; then
    RECURSIVE_ARG="--recursive"
fi

TAG_ARG=""
if [ ! -z "$TAG" ]; then
    TAG_ARG="--tag $TAG"
fi

python3 "$TMP_SCRIPT" --source "$SOURCE_PATH" --format "$FORMAT" $RECURSIVE_ARG $TAG_ARG

RESULT=$?
if [ $RESULT -eq 0 ]; then
    print_success "RAG database updated successfully"
else
    print_warning "RAG database update completed with errors"
fi

# Clean up temporary script
rm "$TMP_SCRIPT"

# Final message
print_header "RAG Update Complete!"
echo "The Dia assistant's knowledge base has been updated."
echo "The assistant will now be able to reference these documents in its responses."
echo ""
echo "To test the updated knowledge, ask a question related to the imported documents."

exit $RESULT
