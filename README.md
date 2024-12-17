# Customized container image for Cloud Data Protection

![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.0.0-blue)

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Usage](#usage)
- [Architecture](#architecture)
- [Contributing and License](#contributing-and-license)
- [Contact](#contact)

## Introduction

The project creates customized container images specifically designed for Cloud Data Protection. This innovative solution combines the flexibility of containerization with the critical need for robust data security in cloud environments.

## Features

Each container image contains these features:

**Cloud Login**: Supports CLI, API, or Identity Management System authentication.

**Assets Discover**y: Efficient asset discovery using tagging and parameter lookup.

**Data Extraction**: Multiple methods are available for data extraction.

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://www.docker.com/) or [Podman](https://podman.io/)
- [Kubernetes](https://kubernetes.io/) 

### Installation

**Clone the Repository**

  ```bash
   git clone https://github.com/ps-iberia-public-cloud-backup/DellDPS-PaaS-Backup.git
   cd DellDPS-PaaS-Backup
  ```

### Usage

 ```bash
   ./setup.sh --containerType <value> --sourceImage <value> --sourceImageVersion <value> --targetImage <value> 
   --targetImageVersion <value> 
   --containerInstallationFolder <value> [--proxy <value>] [--azresourceGroup <value>] [--aztenantId <value>] [--azservicePrincipalClientId <value>] [--azservicePrincipalClientSecret <value>] [--azsecretSPN <value>] [--azsubscriptionID <value>] [--avamarServerName <value>] [--datadomainServerName <value>] [--containerName <value>] [--azcontainerName <value>]

   or

   ./setup.sh --jsonfile <value> 
 ```

Or use Ansible Playbooks, Jenkins Pipelines, or Terraform Execution Plans 
supplied instead of setup.sh.

**Important:** 
- --sourceImage is an image with all software stack, use DellDPS-PaaS-Image-Factory to create this source image.

- Aditional parameters must be configured filling this [file](jsonfiles/dps-setup.json). If you fill the file, you must use the --jsonFile parameter to use it.

## Contributing and License

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) file for details on our code of conduct, and the process for submitting pull requests.

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

# Contact
For any inquiries, please contact: pablo.calvo@dellteam.com
