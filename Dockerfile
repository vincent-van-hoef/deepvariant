FROM nfcore/base
<<<<<<< HEAD
LABEL authors="phil@lifebit.ai" \
      description="Docker image containing all requirements for nf-core/deepvariant pipeline"
=======
LABEL description="Docker image containing all requirements for nf-core/deepvariant pipeline"
>>>>>>> TEMPLATE

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-deepvariant-1.0dev/bin:$PATH
