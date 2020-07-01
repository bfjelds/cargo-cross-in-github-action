const core = require('@actions/core');
const child_process = require('child_process');
const fs = require("fs");

console.log(`Start main.js`)

var dev_suffix = (core.getInput('github_event_name') == "release") ? "" : "-dev";
const versioned_label = `v${fs.readFileSync('./version.txt').toString()}${dev_suffix}`;
const latest_label = `latest${dev_suffix}`;
console.log(`Use labels: versioned=${versioned_label} latest=${latest_label}`);

console.log(`Login into Container Registry repo=${core.getInput('acr_name')} user=${core.getInput('acr_repo')}`)
await exec.exec('docker', 
                [
                    'login', 
                    '-u', core.getInput('acr_name'), 
                    '-p', core.getInput('acr_password'), 
                    core.getInput('acr_repo')
                ],
                options);

console.log(`echo Create multi-arch versioned manifest`)
await exec.exec(`LABEL_PREFIX=${versioned_label} PREFIX=${core.getInput('acr_repo')} make ${core.getInput('component_name')}-docker-multi-arch-create`)

console.log(`echo Inspect multi-arch versioned manifest`)
await exec.exec(`DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect ${core.getInput('acr_repo')}/${core.getInput('container_name')}:${versioned_label}`)

console.log(`echo Push multi-arch versioned manifest`)
await exec.exec(`LABEL_PREFIX=${versioned_label} PREFIX=${core.getInput('acr_repo')} make ${core.getInput('component_name')}-docker-multi-arch-push`)

console.log(`echo Create multi-arch latest manifest`)
await exec.exec(`LABEL_PREFIX=${latest_label} PREFIX=${core.getInput('acr_repo')} make ${core.getInput('component_name')}-docker-multi-arch-create`)

console.log(`echo Inspect multi-arch latest manifest`)
await exec.exec(`DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect ${core.getInput('acr_repo')}/${core.getInput('container_name')}:${latest_label}`)

console.log(`echo Push multi-arch latest manifest`)
await exec.exec(`LABEL_PREFIX=${latest_label} PREFIX=${core.getInput('acr_repo')} make ${core.getInput('component_name')}-docker-multi-arch-push`)
