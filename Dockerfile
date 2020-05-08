FROM nfcore/base
LABEL authors="vincent van hoef" \
      description="Docker image containing all requirements for nf-core/deepvariant pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
RUN apt-get update && apt-get install -y unzip zip
ENV PATH /opt/conda/envs/nf-core-deepvariant-1.2/bin:$PATH