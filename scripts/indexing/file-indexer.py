#!/usr/bin/env python3
"""
Building Materials File Indexer
Indexes CAD files, images, CMake projects, and Go repositories for IPFS storage
"""

import os
import json
import hashlib
import subprocess
import sys
from datetime import datetime
from pathlib import Path
import mimetypes
import argparse

class BuildingMaterialsIndexer:
    def __init__(self, base_path="."):
        self.base_path = Path(base_path).resolve()
        self.indexes = {
            'cad': [],
            'images': [],
            'cmake': [],
            'golang': [],
            'metadata': []
        }
        
        # Supported file types
        self.file_types = {
            'cad': ['.cad', '.dwg', '.dxf', '.step', '.stp', '.iges', '.igs'],
            'images': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.heic', '.webp'],
            'cmake': ['CMakeLists.txt'],
            'golang': ['go.mod', 'go.sum', '.go']
        }
        
    def log(self, message, level="INFO"):
        """Log messages with timestamp"""
        timestamp = datetime.now().isoformat()
        print(f"[{timestamp}] [{level}] {message}")
        
    def calculate_file_hash(self, file_path):
        """Calculate SHA256 hash of a file"""
        try:
            sha256_hash = hashlib.sha256()
            with open(file_path, "rb") as f:
                for byte_block in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(byte_block)
            return sha256_hash.hexdigest()
        except Exception as e:
            self.log(f"Error calculating hash for {file_path}: {e}", "ERROR")
            return None
            
    def get_file_metadata(self, file_path):
        """Extract metadata from a file"""
        try:
            stat = file_path.stat()
            mime_type, _ = mimetypes.guess_type(str(file_path))
            
            metadata = {
                'name': file_path.name,
                'path': str(file_path.relative_to(self.base_path)),
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                'mime_type': mime_type,
                'extension': file_path.suffix.lower(),
                'hash': self.calculate_file_hash(file_path)
            }
            
            return metadata
        except Exception as e:
            self.log(f"Error getting metadata for {file_path}: {e}", "ERROR")
            return None
            
    def add_to_ipfs(self, file_path):
        """Add file to IPFS and return hash"""
        try:
            result = subprocess.run(
                ['ipfs', 'add', '-q', str(file_path)],
                capture_output=True,
                text=True,
                check=True
            )
            ipfs_hash = result.stdout.strip()
            self.log(f"Added to IPFS: {file_path.name} -> {ipfs_hash}")
            return ipfs_hash
        except subprocess.CalledProcessError as e:
            self.log(f"Error adding {file_path} to IPFS: {e}", "ERROR")
            return None
        except FileNotFoundError:
            self.log("IPFS not found. Please ensure IPFS is installed and running.", "ERROR")
            return None
            
    def index_cad_files(self):
        """Index CAD files"""
        self.log("Indexing CAD files...")
        
        for ext in self.file_types['cad']:
            for file_path in self.base_path.rglob(f"*{ext}"):
                if file_path.is_file():
                    metadata = self.get_file_metadata(file_path)
                    if metadata:
                        ipfs_hash = self.add_to_ipfs(file_path)
                        if ipfs_hash:
                            index_entry = {
                                **metadata,
                                'ipfs_hash': ipfs_hash,
                                'type': 'cad',
                                'indexed_at': datetime.now().isoformat()
                            }
                            self.indexes['cad'].append(index_entry)
                            
        self.log(f"Indexed {len(self.indexes['cad'])} CAD files")
        
    def index_images(self):
        """Index image files"""
        self.log("Indexing image files...")
        
        for ext in self.file_types['images']:
            for file_path in self.base_path.rglob(f"*{ext}"):
                if file_path.is_file():
                    metadata = self.get_file_metadata(file_path)
                    if metadata:
                        # Try to get image dimensions if possible
                        try:
                            from PIL import Image
                            with Image.open(file_path) as img:
                                metadata['width'] = img.width
                                metadata['height'] = img.height
                                metadata['format'] = img.format
                        except ImportError:
                            self.log("PIL not available for image metadata", "WARN")
                        except Exception:
                            pass  # Skip if image can't be processed
                            
                        ipfs_hash = self.add_to_ipfs(file_path)
                        if ipfs_hash:
                            index_entry = {
                                **metadata,
                                'ipfs_hash': ipfs_hash,
                                'type': 'image',
                                'indexed_at': datetime.now().isoformat()
                            }
                            self.indexes['images'].append(index_entry)
                            
        self.log(f"Indexed {len(self.indexes['images'])} image files")
        
    def index_cmake_projects(self):
        """Index CMake projects"""
        self.log("Indexing CMake projects...")
        
        cmake_files = list(self.base_path.rglob("CMakeLists.txt"))
        
        for cmake_file in cmake_files:
            project_dir = cmake_file.parent
            
            # Get project metadata
            metadata = {
                'project_name': project_dir.name,
                'project_path': str(project_dir.relative_to(self.base_path)),
                'cmake_file': str(cmake_file.relative_to(self.base_path)),
                'type': 'cmake_project'
            }
            
            # Try to extract project info from CMakeLists.txt
            try:
                with open(cmake_file, 'r') as f:
                    content = f.read()
                    
                # Look for project() declaration
                import re
                project_match = re.search(r'project\s*\(\s*([^)]+)\)', content, re.IGNORECASE)
                if project_match:
                    metadata['declared_name'] = project_match.group(1).strip().split()[0]
                    
            except Exception as e:
                self.log(f"Error reading CMakeLists.txt: {e}", "WARN")
                
            # Add entire project directory to IPFS
            try:
                result = subprocess.run(
                    ['ipfs', 'add', '-r', '-q', str(project_dir)],
                    capture_output=True,
                    text=True,
                    check=True
                )
                # Get the last hash (directory hash)
                ipfs_hash = result.stdout.strip().split('\n')[-1]
                
                index_entry = {
                    **metadata,
                    'ipfs_hash': ipfs_hash,
                    'indexed_at': datetime.now().isoformat()
                }
                self.indexes['cmake'].append(index_entry)
                self.log(f"Indexed CMake project: {metadata['project_name']} -> {ipfs_hash}")
                
            except subprocess.CalledProcessError as e:
                self.log(f"Error adding CMake project {project_dir} to IPFS: {e}", "ERROR")
                
        self.log(f"Indexed {len(self.indexes['cmake'])} CMake projects")
        
    def index_golang_projects(self):
        """Index Go projects"""
        self.log("Indexing Go projects...")
        
        go_mod_files = list(self.base_path.rglob("go.mod"))
        
        for go_mod_file in go_mod_files:
            project_dir = go_mod_file.parent
            
            # Get project metadata
            metadata = {
                'project_name': project_dir.name,
                'project_path': str(project_dir.relative_to(self.base_path)),
                'go_mod_file': str(go_mod_file.relative_to(self.base_path)),
                'type': 'golang_project'
            }
            
            # Try to extract module info from go.mod
            try:
                with open(go_mod_file, 'r') as f:
                    content = f.read()
                    
                # Look for module declaration
                import re
                module_match = re.search(r'module\s+(.+)', content)
                if module_match:
                    metadata['module_name'] = module_match.group(1).strip()
                    
                # Look for Go version
                version_match = re.search(r'go\s+(\d+\.\d+)', content)
                if version_match:
                    metadata['go_version'] = version_match.group(1)
                    
            except Exception as e:
                self.log(f"Error reading go.mod: {e}", "WARN")
                
            # Count Go source files
            go_files = list(project_dir.rglob("*.go"))
            metadata['source_files_count'] = len(go_files)
            
            # Add entire project directory to IPFS
            try:
                result = subprocess.run(
                    ['ipfs', 'add', '-r', '-q', str(project_dir)],
                    capture_output=True,
                    text=True,
                    check=True
                )
                # Get the last hash (directory hash)
                ipfs_hash = result.stdout.strip().split('\n')[-1]
                
                index_entry = {
                    **metadata,
                    'ipfs_hash': ipfs_hash,
                    'indexed_at': datetime.now().isoformat()
                }
                self.indexes['golang'].append(index_entry)
                self.log(f"Indexed Go project: {metadata['project_name']} -> {ipfs_hash}")
                
            except subprocess.CalledProcessError as e:
                self.log(f"Error adding Go project {project_dir} to IPFS: {e}", "ERROR")
                
        self.log(f"Indexed {len(self.indexes['golang'])} Go projects")
        
    def generate_master_index(self):
        """Generate master index file"""
        master_index = {
            'generated_at': datetime.now().isoformat(),
            'indexer_version': '1.0.0',
            'base_path': str(self.base_path),
            'summary': {
                'cad_files': len(self.indexes['cad']),
                'images': len(self.indexes['images']),
                'cmake_projects': len(self.indexes['cmake']),
                'golang_projects': len(self.indexes['golang']),
                'total_files': sum(len(idx) for idx in self.indexes.values())
            },
            'indexes': self.indexes
        }
        
        return master_index
        
    def save_indexes(self, output_dir="catalog"):
        """Save index files to disk and IPFS"""
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        # Save individual index files
        for index_type, index_data in self.indexes.items():
            if index_data:  # Only save non-empty indexes
                index_file = output_path / f"{index_type}-index.json"
                with open(index_file, 'w') as f:
                    json.dump(index_data, f, indent=2)
                self.log(f"Saved {index_type} index to {index_file}")
                
                # Add to IPFS
                ipfs_hash = self.add_to_ipfs(index_file)
                if ipfs_hash:
                    self.log(f"Index uploaded to IPFS: {index_type} -> {ipfs_hash}")
                    
        # Save master index
        master_index = self.generate_master_index()
        master_file = output_path / "master-index.json"
        with open(master_file, 'w') as f:
            json.dump(master_index, f, indent=2)
        self.log(f"Saved master index to {master_file}")
        
        # Add master index to IPFS
        ipfs_hash = self.add_to_ipfs(master_file)
        if ipfs_hash:
            self.log(f"Master index uploaded to IPFS: {ipfs_hash}")
            
        return master_index
        
    def run_full_index(self, output_dir="catalog"):
        """Run complete indexing process"""
        self.log("Starting full indexing process...")
        
        self.index_cad_files()
        self.index_images()
        self.index_cmake_projects()
        self.index_golang_projects()
        
        master_index = self.save_indexes(output_dir)
        
        self.log("Indexing completed successfully!")
        self.log(f"Summary: {master_index['summary']}")
        
        return master_index

def main():
    parser = argparse.ArgumentParser(description="Building Materials File Indexer")
    parser.add_argument("--path", "-p", default=".", help="Base path to index")
    parser.add_argument("--output", "-o", default="catalog", help="Output directory for index files")
    parser.add_argument("--type", "-t", choices=['cad', 'images', 'cmake', 'golang', 'all'], 
                       default='all', help="Type of files to index")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    indexer = BuildingMaterialsIndexer(args.path)
    
    if args.type == 'all':
        indexer.run_full_index(args.output)
    elif args.type == 'cad':
        indexer.index_cad_files()
        indexer.save_indexes(args.output)
    elif args.type == 'images':
        indexer.index_images()
        indexer.save_indexes(args.output)
    elif args.type == 'cmake':
        indexer.index_cmake_projects()
        indexer.save_indexes(args.output)
    elif args.type == 'golang':
        indexer.index_golang_projects()
        indexer.save_indexes(args.output)

if __name__ == "__main__":
    main()