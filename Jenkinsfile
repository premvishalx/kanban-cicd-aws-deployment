
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    environment {
        DOCKERHUB_REPO = 'premvishalx/kanban-cicd-aws-deployment'
        CONTAINER_NAME = 'kanban-app'
        APP_PORT = '80'
    }

    stages {

        stage('Checkout') {
            steps {
                deleteDir()
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_SHA}"
                    env.IMAGE = "${DOCKERHUB_REPO}:${IMAGE_TAG}"
                }

                sh 'docker build -t "$IMAGE" .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'ada4151c-707d-4bc0-b461-4769e858b0af',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        printf '%s' "$DOCKERHUB_TOKEN" | docker login \
                            -u "$DOCKERHUB_USER" --password-stdin

                        docker push "$IMAGE"
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                sh '''
                    echo "Pulling the new Docker image..."
                    docker pull "$IMAGE"

                    echo "Recording the currently deployed image..."

                    OLD_IMAGE=$(docker inspect \
                        --format='{{.Config.Image}}' \
                        "$CONTAINER_NAME" 2>/dev/null || true)

                    printf '%s' "$OLD_IMAGE" > previous-image.txt

                    echo "Removing the previous container..."
                    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

                    echo "Starting the new application container..."

                    docker run -d \
                        --name "$CONTAINER_NAME" \
                        --restart unless-stopped \
                        -p "$APP_PORT:8080" \
                        "$IMAGE"

                    echo "Deployment command completed."
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    echo "Checking Docker health and application response..."

                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{.State.Health.Status}}' \
                            "$CONTAINER_NAME" 2>/dev/null || true)

                        if [ "$STATUS" = "healthy" ] && \
                           curl -fsS "http://127.0.0.1:$APP_PORT/" -o /dev/null; then

                            echo "SUCCESS: Container is healthy."
                            echo "SUCCESS: Application HTTP response verified."
                            exit 0
                        fi

                        echo "Attempt $i/12: Status is '$STATUS'. Waiting..."
                        sleep 5
                    done

                    echo "ERROR: Application health validation failed."
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
        }

        failure {
            script {
                if (fileExists('previous-image.txt')) {

                    def previousImage = readFile('previous-image.txt').trim()

                    if (previousImage) {

                        echo "Deployment failed. Restoring previous image: ${previousImage}"

                        withEnv(["PREVIOUS_IMAGE=${previousImage}"]) {
                            sh '''
                                docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

                                docker run -d \
                                    --name "$CONTAINER_NAME" \
                                    --restart unless-stopped \
                                    -p "$APP_PORT:8080" \
                                    "$PREVIOUS_IMAGE"

                                echo "Verifying rollback..."

                                for i in $(seq 1 12); do

                                    STATUS=$(docker inspect \
                                        --format='{{.State.Health.Status}}' \
                                        "$CONTAINER_NAME" 2>/dev/null || true)

                                    if [ "$STATUS" = "healthy" ] && \
                                       curl -fsS "http://127.0.0.1:$APP_PORT/" -o /dev/null; then

                                        echo "Rollback successful. Previous application is healthy."
                                        exit 0
                                    fi

                                    echo "Waiting for restored application..."
                                    sleep 5
                                done

                                echo "ERROR: Rollback verification failed."
                                exit 1
                            '''
                        }

                    } else {
                        echo 'No previous application image exists. Rollback is not possible on the first deployment.'
                    }

                } else {
                    echo 'No previous deployment was recorded. Nothing to roll back.'
                }
            }
        }
    }
}
