# Use the official PyTorch conda-builder image as the base image
FROM pytorch/conda-cuda:latest

# Set the working directory
WORKDIR /app

# Copy the environment file if you have one, or specify dependencies directly
# COPY environment.yml ./environment.yml

COPY . /app
RUN    apt-get update && \
    apt install -y python3.10
RUN apt install git-all
RUN apt install build-essential

RUN cd /app \
 && source ./build.sh

 # Run a command, for example, a script to initialize your application
CMD ["bash", "/app/start.sh"]
