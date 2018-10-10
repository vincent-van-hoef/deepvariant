From:nfcore/base
Bootstrap:docker

%labels
    MAINTAINER Phil Palmer <phil@lifebit.ai>
    DESCRIPTION Singularity image containing all requirements for the nf-core/deepvariant pipeline
    VERSION 1.0dev

%environment
    PATH=/opt/conda/envs/nf-core-deepvariant-1.0dev/bin:$PATH
    export PATH

%files
    environment.yml /

%post
    /opt/conda/bin/conda env create -f /environment.yml
    /opt/conda/bin/conda clean -a
