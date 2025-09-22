# IPFS Building Materials Indexing System

This repository contains the infrastructure for an IPFS-based Network Attached Storage (NAS) system designed specifically for building materials management, site planning, and continuous CI/CD integration.

## Overview

The system provides:

- **Decentralized Storage**: Uses IPFS for distributed storage of building materials data
- **File Type Support**: CAD files (.cad), images (.jpg, .heic), CMake projects, and Go repositories
- **Price Tracking**: Real-time pricing data collection and market analysis
- **Access Control**: Role-based access for different user groups
- **Continuous Sync**: Automated synchronization and backup processes
- **Material Catalog**: Comprehensive building materials database with pricing

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   IPFS Network  │    │  GitHub Actions │    │   User Groups   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ File Storage│ │◄──►│ │ Workflows   │ │◄──►│ │Site Planners│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Indexing    │ │    │ │ Monitoring  │ │    │ │Material Mgrs│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Price Data  │ │    │ │ Health Chk  │ │    │ │Order Trackrs│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Features

### 🏗️ Building Materials Management
- **CAD File Storage**: Store and index .cad files with version control
- **Image Management**: Handle .jpg and .heic images with metadata
- **Project Integration**: Support for CMake and Go repositories
- **Material Catalog**: Comprehensive database of building materials

### 💰 Price Tracking & Market Analysis
- **Real-time Pricing**: Daily price updates for key materials
- **Market Analysis**: Weekly trend analysis and forecasting
- **Supplier Comparison**: Multi-supplier price and quality comparison
- **Cost Optimization**: Automated recommendations for purchasing

### 👥 Access Control & User Management
- **Role-based Access**: Different permissions for different user groups
- **Site Planners**: Full access to CAD files and project data
- **Material Managers**: Focus on pricing and supplier management
- **Order Trackers**: Specialized access for logistics and tracking
- **Pricing Analysts**: Market data and analysis tools
- **Administrators**: Full system access and management

### 🔄 Continuous Integration
- **Automated Indexing**: Files are automatically indexed when added
- **Health Monitoring**: Continuous system health checks
- **Backup & Sync**: Regular synchronization across the network
- **Performance Tracking**: Monitor system performance and optimization

## Quick Start

### 1. System Setup
The system automatically sets up when workflows are triggered. Key components include:

- IPFS node initialization and configuration
- User group setup and access control
- Monitoring and health check systems
- Price tracking and analysis tools

### 2. Adding Files
Files are automatically indexed when pushed to the repository:

```bash
# Add CAD files
git add designs/*.cad
git commit -m "Add new building designs"
git push

# Add images 
git add photos/*.jpg photos/*.heic
git commit -m "Add building material photos"
git push
```

### 3. Managing Access
Access control is managed through the GitHub Actions workflow:

```bash
# Trigger user management workflow
gh workflow run access-control.yml -f user_group=site_planners
```

### 4. Price Tracking
Price tracking runs automatically but can be manually triggered:

```bash
# Trigger price analysis
gh workflow run price-tracking.yml -f analysis_type=daily_price_update
```

## User Groups & Permissions

### Site Planners
- **Access**: CAD files, images, project data
- **Permissions**: Read, write, share
- **Storage Quota**: 10GB
- **Use Cases**: Building design, site planning, project visualization

### Material Managers
- **Access**: Pricing data, supplier information, orders
- **Permissions**: Read, write, manage suppliers
- **Storage Quota**: 20GB
- **Use Cases**: Material procurement, supplier management, cost control

### Order Trackers
- **Access**: Order data, logistics, tracking information
- **Permissions**: Read, write, track, update orders
- **Storage Quota**: 5GB
- **Use Cases**: Order fulfillment, logistics coordination, delivery tracking

### Pricing Analysts
- **Access**: Market data, pricing trends, analysis tools
- **Permissions**: Read, write, analyze, export reports
- **Storage Quota**: 15GB
- **Use Cases**: Market research, price forecasting, trend analysis

### Administrators
- **Access**: Full system access
- **Permissions**: All operations including user management
- **Storage Quota**: Unlimited
- **Use Cases**: System administration, user management, backup operations

## Workflows

### 1. IPFS Indexing (`ipfs-indexing.yml`)
- **Triggers**: File changes, schedule, manual
- **Functions**: File indexing, IPFS storage, catalog management
- **Frequency**: On push, every 6 hours

### 2. Access Control (`access-control.yml`)
- **Triggers**: Access control changes, manual
- **Functions**: User management, permission matrix, key generation
- **Frequency**: On demand

### 3. Price Tracking (`price-tracking.yml`)
- **Triggers**: Schedule, manual
- **Functions**: Price collection, market analysis, supplier comparison
- **Frequency**: Daily (prices), Weekly (analysis)

### 4. System Monitoring (`monitoring.yml`)
- **Triggers**: Schedule, manual
- **Functions**: Health checks, performance monitoring, alerting
- **Frequency**: Hourly (health), Daily (comprehensive)

## Directory Structure

```
.github/
├── workflows/
│   ├── ipfs-indexing.yml      # Main indexing system
│   ├── access-control.yml     # User management
│   ├── price-tracking.yml     # Price analysis
│   └── monitoring.yml         # Health monitoring
├── catalog/
│   ├── materials/             # Material specifications
│   ├── pricing/              # Price data and analysis
│   ├── suppliers/            # Supplier information
│   └── orders/               # Order tracking
├── access-control/
│   ├── groups/               # User group definitions
│   ├── permissions/          # Permission matrices
│   └── keys/                 # IPFS access keys
├── monitoring/
│   ├── health/               # Health check reports
│   ├── storage/              # Storage analysis
│   └── alerts/               # System alerts
└── scripts/
    ├── ipfs/                 # IPFS utilities
    ├── indexing/             # Indexing scripts
    └── monitoring/           # Monitoring tools
```

## Data Flow

1. **File Upload**: Files are added to repository
2. **Trigger Detection**: GitHub Actions detect file changes
3. **IPFS Processing**: Files are added to IPFS network
4. **Indexing**: Metadata and hashes are recorded
5. **Access Control**: Permissions are applied based on user groups
6. **Monitoring**: System health and performance are tracked
7. **Reporting**: Status reports are generated and stored

## Security & Access

- **IPFS Keys**: Unique keys for each user group
- **Permission Matrix**: Granular access control
- **Audit Logging**: All access and changes are logged
- **Backup**: Critical data is automatically backed up
- **Encryption**: Sensitive data is encrypted at rest

## Monitoring & Health

The system includes comprehensive monitoring:

- **Node Health**: IPFS node status and connectivity
- **Storage Usage**: Repository size and optimization
- **Performance**: Response times and throughput
- **Data Integrity**: Verification of stored content
- **Alerting**: Automated notifications for issues

## Pricing & Market Data

Real-time market intelligence:

- **Daily Updates**: Material prices updated daily
- **Trend Analysis**: Weekly market trend reports
- **Supplier Comparison**: Multi-supplier price analysis
- **Cost Optimization**: Automated purchasing recommendations
- **Global Markets**: Support for international pricing

## Support & Maintenance

- **Health Checks**: Automated every hour
- **Performance Monitoring**: Continuous tracking
- **Storage Optimization**: Weekly cleanup and optimization
- **Backup Verification**: Daily backup integrity checks
- **System Updates**: Automated security and feature updates

## Contributing

To contribute to this system:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the monitoring system
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contact

For support and questions:
- System Monitoring: Check the monitoring workflow results
- Access Issues: Use the access-control workflow
- Price Data: Check the price-tracking workflow results
- General Support: Create an issue in this repository