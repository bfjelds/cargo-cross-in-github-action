const exec = require('@actions/exec');
const core = require('@actions/core');
const child_process = require('child_process');
const fs = require("fs");

(async () => {
    try {
        console.log(`Start main.js`)

        var dev_suffix = (core.getInput('github_event_name') == "release") ? "" : "-dev";
        const versioned_label = `v${fs.readFileSync('./version.txt').toString().trim()}${dev_suffix}`;
        const latest_label = `latest${dev_suffix}`;
        console.log(`Use labels: versioned=${versioned_label} latest=${latest_label}`);

        console.log(`Login into Container Registry repo=${core.getInput('acr_name')} user=${core.getInput('acr_repo')}`)
        await exec.exec(`echo "${core.getInput('acr_password')}" | docker login -u ${core.getInput('acr_name')} --password-stdin ${core.getInput('acr_repo')}`);

        process.env.DOCKER_CLI_EXPERIMENTAL = `enabled`
        process.env.PREFIX = `${core.getInput('acr_repo')}`
        process.env.LABEL_PREFIX = `${versioned_label}`

        console.log(`echo Create multi-arch versioned manifest`)
        await exec.exec(`make foo-docker-push-multi-arch-create`)

        console.log(`echo Inspect multi-arch versioned manifest`)
        await exec.exec(`docker manifest inspect ${core.getInput('acr_repo')}/${core.getInput('container_name')}:${versioned_label}`)

        console.log(`echo Push multi-arch versioned manifest`)
        await exec.exec(`make foo-docker-push-multi-arch-push`)

        process.env.LABEL_PREFIX = `${latest_label}`

        console.log(`echo Create multi-arch latest manifest`)
        await exec.exec(`make foo-docker-push-multi-arch-create`)

        console.log(`echo Inspect multi-arch latest manifest`)
        await exec.exec(`docker manifest inspect ${core.getInput('acr_repo')}/${core.getInput('container_name')}:${latest_label}`)

        console.log(`echo Push multi-arch latest manifest`)
        await exec.exec(`make foo-docker-push-multi-arch-push`)
    } catch (error) {
        core.setFailed(error);
    }        
})();