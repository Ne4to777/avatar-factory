"""
Setup script for Avatar Factory GPU Worker
"""

from setuptools import setup, find_packages

setup(
    name="avatar-factory-gpu-worker",
    version="1.0.0",
    description="GPU Worker for Avatar Factory - AI model processing server",
    # long_description omitted to support Docker builds without README.md
    author="Avatar Factory",
    author_email="contact@avatar-factory.local",
    url="https://github.com/Ne4to777/avatar-factory",
    packages=find_packages(),
    python_requires=">=3.10",
    install_requires=[
        "fastapi>=0.109.0",
        "uvicorn[standard]>=0.27.0",
        "python-multipart>=0.0.6",
        "diffusers>=0.25.1",
        "transformers>=4.37.0",
        "accelerate>=0.26.1",
        "safetensors>=0.4.1",
        "soundfile>=0.12.1",
        "librosa>=0.10.1",
        "opencv-python>=4.9.0",
        "pillow>=10.2.0",
        "imageio>=2.33.1",
        "numpy>=1.26.3",
        "scipy>=1.11.4",
        "tqdm>=4.66.1",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.0",
            "pytest-asyncio>=0.21.0",
            "black>=23.0.0",
            "ruff>=0.1.0",
        ],
        "gpu": [
            "xformers>=0.0.23",
            "gfpgan>=1.3.8",
            "realesrgan>=0.3.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "avatar-gpu-server=server:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Multimedia :: Video",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
)
