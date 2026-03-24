"""Setup script for infras-cli package."""

from setuptools import setup, find_packages

setup(
    name="infras-cli",
    version="1.0.0",
    description="Infrastructure ACL management CLI and API for Kubernetes services",
    packages=find_packages(include=["app*"]),
    install_requires=[
        "fastapi>=0.109.0",
        "uvicorn[standard]>=0.27.0",
        "typer>=0.9.0",
        "rich>=13.7.0",
        "hvac>=2.1.0",
        "kubernetes>=28.1.0",
        "requests>=2.31.0",
        "pydantic>=2.5.3",
        "pydantic-settings>=2.1.0",
        "structlog>=24.1.0",
        "python-multipart>=0.0.6",
    ],
    entry_points={
        "console_scripts": [
            "infras-cli=app.cli.__main__:app",
        ],
    },
    python_requires=">=3.10",
)
