From:nfcore/base:latest
Bootstrap:docker

%labels
    MAINTAINER Vincent van Hoef
    DESCRIPTION Singularity image containing all requirements for the nf-core/deepvariant pipeline
    VERSION 1.2

%environment
    PATH=/opt/conda/envs/nf-core-deepvariant-1.2/bin:$PATH
    export PATH

%files
    environment.yml /

%post
    /opt/conda/bin/conda env create -f /environment.yml
    /opt/conda/bin/conda clean -a
