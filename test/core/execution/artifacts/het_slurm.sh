#!/bin/bash
#
# Generated by NeMo Run
# Run with: sbatch --parsable
#

# Parameters
#SBATCH --account=your_account
#SBATCH --gpus-per-node=8
#SBATCH --job-name=your_account-account.sample_job-0
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --open-mode=append
#SBATCH --output=/some/job/dir/sample_job-0/sbatch_your_account-account.sample_job-0_%j.out
#SBATCH --partition=your_partition
#SBATCH --time=00:30:00
#SBATCH hetjob
#SBATCH --account=your_account
#SBATCH --gpus-per-node=0
#SBATCH --job-name=your_account-account.sample_job-1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --open-mode=append
#SBATCH --output=/some/job/dir/sample_job-1/sbatch_your_account-account.sample_job-1_%j.out
#SBATCH --partition=your_partition
#SBATCH --time=00:30:00

set -evx

export PYTHONUNBUFFERED=1
export SLURM_UNBUFFEREDIO=1
export TORCHX_MAX_RETRIES=3
export ENV_VAR=value

set +e

# setup

nodes=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
nodes_array=($nodes)
head_node=${nodes_array[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address)


het_group_host_0=$(scontrol show hostnames=$SLURM_JOB_NODELIST_HET_GROUP_0 | head -n1)
het_group_host_1=$(scontrol show hostnames=$SLURM_JOB_NODELIST_HET_GROUP_1 | head -n1)



# Command 1

export CUSTOM_ENV_1=some_value_1


srun --het-group=0 --output /some/job/dir/sample_job-0/log-your_account-account.sample_job-0_%j_${SLURM_RESTART_COUNT:-0}.out --container-image image_1 --container-mounts /some/job/dir/sample_job-0:/sample_job-0 --container-workdir /sample_job-0/code --wait=60 --kill-on-bad-exit=1 bash ./scripts/start_server.sh & pids[0]=$!

sleep 30


# Command 2

export CUSTOM_ENV_2=some_value_2

export HOST_1=$het_group_host_0


srun --het-group=1 --output /some/job/dir/sample_job-1/log-your_account-account.sample_job-1_%j_${SLURM_RESTART_COUNT:-0}.out --container-image image_2 --container-mounts /some/job/dir/sample_job-1:/sample_job-1 --container-workdir /sample_job-1/code --wait=60 --kill-on-bad-exit=1 bash ./scripts/echo.sh server_host=$het_group_host_0 & pids[1]=$!

wait


# The code below monitors the four SLURM jobs to ensure any failure forces them all to stop
# (otherwise some jobs may remain pending until they reach the cluster time limit).
all_done=false
while ! $all_done; do
    all_done=true
    for pid in "${pids[@]}"; do
        if ps -p "$pid" > /dev/null; then
            # Process is still running.
            all_done=false
        else
            # Process is no longer running => check its exit status.
            wait "$pid"
            exitcode=$?
            echo "Process $pid exited with code $exit_code at $(date '+%Y-%m-%d %H:%M:%S')"
            # Wait a bit (to get a clean stack trace in case there is one being generated), then kill the
            # remaining processes if needed.
            sleep 60
            for other_pid in "${pids[@]}"; do
                if ps -p "$other_pid" > /dev/null; then
                    echo "Killing process $other_pid"
                    kill -9 "$other_pid"
                fi
            done
        fi
    done

    # Sleep for a while before checking again.
    sleep 60
done

set -e

echo "job exited with code $exitcode"
if [ $exitcode -ne 0 ]; then
    if [ "$TORCHX_MAX_RETRIES" -gt "${SLURM_RESTART_COUNT:-0}" ]; then
        scontrol requeue "$SLURM_JOB_ID"
    fi
    exit $exitcode
fi
