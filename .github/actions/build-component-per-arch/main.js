const exec = require('@actions/exec');
const core = require('@actions/core');
const child_process = require('child_process');
const fs = require("fs");

(async () => {
    try {
        console.log(`Start main.js`)

        console.log(`Use multiarch/qemu-user-static to configure cross-plat`);
        await exec.exec('docker run --rm --privileged multiarch/qemu-user-static --reset -p yes');

        var dev_suffix = (core.getInput('github_event_name') == "release") ? "" : "-dev";
        const versioned_label = `v${fs.readFileSync('./version.txt').toString()}${dev_suffix}`;
        const latest_label = `latest${dev_suffix}`;
        console.log(`Use labels: versioned=${versioned_label} latest=${latest_label}`);

        var push_containers = 0;
        if (core.getInput('github_event_name') == 'release') push_containers = 1;
        else if (core.getInput('github_event_name') == 'push' && 
                core.getInput('github_ref') == 'refs/heads/master') push_containers = 1;
        else if (core.getInput('github_event_name') == 'pull_request' && 
                core.getInput('github_event_action') == 'closed' && 
                core.getInput('github_ref') == 'refs/heads/master' && 
                core.getInput('github_merged') == 'true') push_containers = 1;
        else console.log(`Not pushing containers ... event: ${core.getInput('github_event_name')}, ref: ${core.getInput('github_ref')}, action: ${core.getInput('github_event_action')}, merged: ${core.getInput('github_merged')}`);
        console.log(`Push containers: ${push_containers}`);

        var makefile_target_suffix = "";
        switch (core.getInput('platform')) {
            case "amd64":   makefile_target_suffix = "amd64"; break;
            case "arm32v7": makefile_target_suffix = "arm32"; break;
            case "arm64v8": makefile_target_suffix = "arm64"; break;
            default:
                core.setFailed(`Failed with unknown platform: ${core.getInput('platform')}`)
                return
        }
        console.log(`Makefile build target suffix: ${makefile_target_suffix}`)

        console.log(`Login into Container Registry repo=${core.getInput('acr_name')} user=${core.getInput('acr_repo')}`)
        await exec.exec(`echo "${core.getInput('acr_password')}" | docker login -u ${core.getInput('acr_name')} --password-stdin ${core.getInput('acr_repo')}`);


        if (core.getInput('build_rust') == '1') {
            console.log(`Install Rust`)
            child_process.execSync(`curl https://sh.rustup.rs | sh -s -- -y --default-toolchain=none --profile=minimal`);
            const bindir = `${process.env.HOME}/.cargo/bin`;
            process.env.PATH = `${process.env.PATH}:${bindir}`;

            console.log(`Check cargo version`)
            await exec.exec('cargo --version')
            console.log(`Install Cross`)
            await exec.exec('make install-cross')
            await exec.exec('cross --version')
            // console.log(`Cargo.toml contents: ${fs.readFileSync("./Cargo.toml").toString()}`)
            // console.log(`Filter projects in [${core.getInput('do_not_build')}]`)
            // await exec.exec(`for PROJECT_NOT_TO_BUILD in $INPUT_DO_NOT_BUILD; do sed -i s/\"..\"$PROJECT_NOT_TO_BUILD\"/\"/g Cargo.toml; done`);
            // console.log(`Filtered Cargo.toml contents: ${fs.readFileSync("./Cargo.toml").toString()}`)
            console.log(`Cross compile: foo-cross-build-${makefile_target_suffix}`)
            await exec.exec(`make foo-cross-build-${makefile_target_suffix}`)
        } else {
            console.log(`Not building Rust: ${core.getInput('build_rust')}`)
        }

        process.env.PREFIX = `${core.getInput('acr_repo')}`

        console.log(`Build the versioned container: make foo-build-${makefile_target_suffix}`)
        process.env.LABEL_PREFIX = `${versioned_label}`
        await exec.exec(`make foo-docker-build-${makefile_target_suffix}`)

        console.log(`Build the latest container: make foo-build-${makefile_target_suffix}`)
        process.env.LABEL_PREFIX = `${latest_label}`
        await exec.exec(`make foo-docker-build-${makefile_target_suffix}`)

        if (push_containers == "1") {
            console.log(`Push the versioned container: make foo-docker-push-per-arch-${makefile_target_suffix}`)
            process.env.LABEL_PREFIX = `${versioned_label}`
            await exec.exec(`make foo-docker-push-per-arch-${makefile_target_suffix}`)

            console.log(`Push the latest container: make foo-docker-push-per-arch-${makefile_target_suffix}`)
            process.env.LABEL_PREFIX = `${latest_label}`
            await exec.exec(`make foo-docker-push-per-arch-${makefile_target_suffix}`)
        } else {
            console.log(`Not pushing containers: ${push_containers}`)
        }
    } catch (error) {
        core.setFailed(error);
    }        
})();