## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Reporting Issues](#reporting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Code Style](#code-style)
- [Commit Messages](#co)
- [Running Tests](#running-tests)
- [Project Structure](#project-structure)
- [Getting Help](#getting-help)

# Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report any unacceptable behavior to pablo.calvo@dellteam.com.

# How to Contribute

1) Fork the Repository

    To contribute, first fork the repository on GitHub:

    Go to the project repository.

    Click the "Fork" button in the upper-right corner.

    Clone your fork locally:

```
    git clone https://github.com/ps-iberia-public-cloud-backup/DellDPS-PaaS-Backup.git
    cd DellDPS-PaaS-Backup
```

2) Create a New Branch

    Create a new branch for your feature or bugfix:

```
    git checkout -b feature/your-feature-name
```

3)  Make Your Changes

    Implement your changes in the new branch. Ensure that your code adheres to the project’s coding standards and passes all tests.

4) Test Your Changes

    Before submitting your changes, run the tests to ensure everything works as expected:

    If you've added new features, please include tests for those features.

5) Submit a Pull Request

    Push your changes to your fork:

```
    git push origin feature/your-feature-name
```

6) Go to the original repository on GitHub and open a pull request. Provide a clear and detailed description of what your changes do, including any relevant issue numbers.

# Reporting Issues

If you find a bug or have a feature request, please open an issue on GitHub:

Go to the Issues page.
Click "New Issue".
Provide a clear title and description, including steps to reproduce the issue if applicable.

# Submitting Pull Requests

When submitting a pull request:

Ensure your changes are well-tested.
Ensure your commit history is clean (rebase your branch if necessary).
Include a descriptive title and detailed description in your pull request.
Reference any relevant issues (e.g., "Fixes #123").
We review all pull requests, and feedback will be provided as needed. Thank you for your contribution!

# Code Style

To maintain consistency across the codebase, please adhere to the following guidelines:

Follow consistent indentation (4 spaces per indentation level).
Write clear and descriptive comments where necessary.
Keep functions and classes small and focused.
Avoid unnecessary complexity.

# Commit Messages

Please write meaningful commit messages that describe what your commit does. Follow this format:

Short summary of the changes (50 characters or less)

Detailed explanation of the changes:
- What has changed and why.
- Any relevant details or context.
- Reference issues if applicable (e.g., "Fixes #123").


# Running Tests

Testing is crucial for the stability of the project.

If you add new features or fix bugs, ensure that you also write corresponding tests.

# Project Structure

Here is a brief overview of the project's structure:
```
DellDPS-PaaS-Backup/
│
├── automation/             # Automation platforms
      └── executionsPlans/  # Terraform executions plans
      └── pipelines/        # Jenkins pipelines
      └── playbooks/        # Ansible playbooks
├── code/                   # Business code, i.e. the backup scripts
├── common/                 # Common funtions than can be used by the scripts, incluuding the bash functions, cloud functions, etc.
├── deployements/           # Container deployments. How to deploy the project in the different cloud providers and/or orchestrators.
├── docs/                   # Use case documentation. The cvs files is the main one.
├── jsonfiles/              # Config files. Json files to configure the project.
├── CONTRIGUTING.md         # Contributing file
├── LICENSE                 # License file
└── README.md               # Project README
└── setup.sh                # Command to run the project
```

# Getting Help
If you need help or have questions, feel free to reach out:

Open an issue with your question.
Contact me via pablo.calvo@dellteam.com.
