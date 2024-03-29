#!groovy

version        = "0.0.${env.BUILD_NUMBER}"
awsRegion      = "us-west-1"
rebuildAmi     = false

PACKER_DIR    = 'deploy/docker-swarm/packer'
TERRAFORM_DIR = 'deploy/docker-swarm/terraform/aws'
NOTIFICATIONS = true

node {
    stage('checkout') {
        checkout scm
    }

    def tag = "git-${gitCommit()}"

    withCredentials([
        usernamePassword(credentialsId: 'docker-hub-id', passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME'),
        file(credentialsId: 'pem', variable: 'PEM')
    ]) {

        // setup
        def targetEnv = ''
        def tfState = ''
        def tfplan = ''
        if (isPR()) {
            targetEnv = 'staging'
            tfState = "git-${gitCommit()}.tfstate"
        } else if (isMaster()) {
            targetEnv = 'prod'
            tfState = 'prod.tfstate'
        } else {
            targetEnv = 'qa'
            tfState = 'qa.tfstate'
        }
        tfplan = "${targetEnv}-${tag}.tfplan"
        sh "cat $PEM > $TERRAFORM_DIR/pem.txt"

        // build ami 
        stage('build AMIs') {
            if (rebuildAmi) {
                sh """${packer()} build \
                    -var aws_region=${awsRegion} \
                    -var ami_name=docker-swarm \
                    -var git_commit=${gitCommit()} \
                    -var git_branch=${env.BRANCH_NAME} \
                    -var version=${version} \
                    -force \
                    packer.json
                """
                sleep 60 // bug where ami id is not updated in AWS by the time terraform runs
            } else {
                echo "Skipping build"
            }
        }

        stage('init') {
            sh """${terraform()} init \
                -backend-config=config/${targetEnv}-state-store.tfvars \
                -backend-config='key=tf/${targetEnv}/${tfState}' \
                -force-copy \
                .
            """
        }

        if (!isPR()) {
            stage('taint resources') {
                taintResources()
            }
        }

        stage('plan') {
            sh """${terraform()} plan \
                -var-file=config/${targetEnv}.tfvars \
                -var tag=$tag \
                -var private_key_path=pem.txt \
                -var git_commit=${gitCommit()} \
                -var git_branch=${env.BRANCH_NAME} \
                -var manager_volume_size=50 \
                -var worker_volume_size=25 \
                -var version=${version} \
                -out $tfplan \
                .
            """
        }

        // Deploy to staging environment 
        if (isPR()) {
            def masterAddress = ''
            try {
                stage('deploy staging') {
                    sh "${terraform(false)} apply $tfplan"
                    masterAddress = getMasterAddress()
                    publishStagedInfo(masterAddress) 
                }

                stage('UAT') {
                    milestone 1

                    def userInput = ''
                    timeout(time: 2, unit: 'DAYS') {
                        userInput = input(
                            id: 'userInput',
                            message: "Did staged build 'pass' or 'fail'?",
                            parameters: [choice(name: 'result', choices: 'pass\nfail', description: '')]
                        )
                    }

                    if (userInput != "pass") {
                        error("Staged build failed user acceptance testing")
                    }

                    milestone 2
                }
            } catch(e) {
                error "Failed: ${e}"
            } finally {
                sh "${terraform()} destroy -force -var private_key_path=pem.txt ."
                notifyTeardownEvent(masterAddress)
            }

        } 
        
        // Deploy to production
        else if (isMaster()) {
            stage('deploy to prod') {
                sh "${terraform(false)} apply $tfplan"
            }
        } 
        
        // Deploy to QA
        else {
            stage('deploy to QA') {
                sh "${terraform(false)} apply $tfplan"
            }
        }
    }
}

def publishStagedInfo(String ip) {
    if (NOTIFICATIONS) {
        notifyGithub("${env.JOB_NAME}, build [#${env.BUILD_NUMBER}](${env.BUILD_URL}) - Staged deployment can be viewed at: [http://$ip](http://$ip). Staged builds require UAT, click on Jenkins link when finished with UAT to mark the build as 'pass' or 'failed'")
    }
}

def notifyTeardownEvent(String ip) {
    if (NOTIFICATIONS) {
        notifyGithub("${env.JOB_NAME}, build [#${env.BUILD_NUMBER}](${env.BUILD_URL}) - Staged build @ $ip was removed")
    }
}

def notifyGithub(String comment) {
    if (NOTIFICATIONS) {
        withCredentials([
            string(credentialsId: 'b4043775-af57-4862-8213-3759bba3e2f3', variable: 'TOKEN')
        ]) {
            def pr  = env.BRANCH_NAME.split("-")[1].trim()
            sh "curl -H \"Content-Type: application/json\" -u dlish:$TOKEN -X POST -d '{\"body\": \"$comment\"}' https://api.github.com/repos/dlish/helloworld-infrastructure/issues/$pr/comments"
        }
    }
}

def packer() {
    return "docker run --rm -v ${env.WORKSPACE}:/usr/src/ -w /usr/src/$PACKER_DIR hashicorp/packer:light"
}

def terraform(def asUser = true) {
    def docker = "docker run --rm -v ${env.WORKSPACE}:/usr/src/ -w /usr/src/$TERRAFORM_DIR"
    if (asUser) {
        docker = "$docker -u \$(id -u):\$(id -g)"
    }
    return "$docker hashicorp/terraform:light"
}

def taintResources() {
    try {
        sh "${terraform()} taint null_resource.create_join_scripts"
        sh "${terraform()} taint null_resource.deploy_docker_stack"
        sh "${terraform()} taint null_resource.deploy_monitoring_stack"
        sh "${terraform()} taint null_resource.launch_weave_scope"
    } catch(e) {
        println e
    }
}

def getMasterAddress() {
    def ip = sh (returnStdout: true, script: "${terraform()} output master_address")
    return ip.trim()
}

def gitCommit() {
    def commit = sh (returnStdout: true, script: "git rev-parse --short HEAD")
    return commit.trim()
}

def convertBranchName(String name) {
    return name.replaceAll('/', '_')
}

def isMaster() {
    return env.BRANCH_NAME == "master"
}

def isPR() {
    return env.BRANCH_NAME =~ /(?i)^pr-/
}