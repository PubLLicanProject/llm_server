#!/bin/bash
#SBATCH --ntasks=8
#SBATCH --mem=64gb                     # Job memory request
#SBATCH --time=24:00:00               # Time limit hrs:min:sec
#SBATCH --output=slurm_%j.log   # Standard output and error log
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu
./start.sh $@
