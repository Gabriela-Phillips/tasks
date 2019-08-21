#!/bin/bash

# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=573d
REPO=https://github.com/Gabriela-Phillips/tasks.git
CLUSTER=na311.openshift.opentlc.com

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# 1 -- set up Jenkins instance

echo "var Set"
oc set env bc --all GUID=573d
oc set env bc --all REPO=https://github.com/Gabriela-Phillips/tasks/openshift-tasks.git
oc set env bc --all CLUSTER=na311.openshift.opentlc.com
echo "Project Retrieved"

oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=8Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true --name='jenkins'

oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

# Create custom agent container image with skopeo
echo "apiVersion: v1
kind: "List"
items:
- apiVersion: "v1"
  kind: "ImageStream"
  metadata:
    name: "jenkins-agent-appdev"
  spec:
- apiVersion: "v1"
  kind: "BuildConfig"
  metadata:
    name: "jenkins-agent-appdev"
  spec:
    output:
      to:
        kind: "ImageStreamTag"
        name: "jenkins-agent-appdev:latest"
    source:
      dockerfile: |
        FROM openshift/jenkins-agent-maven-35-centos7
        USER root
        RUN yum -y install skopeo apb && yum clean all
        USER 1001
    strategy:
      type: "Docker"
    triggers:
    - type: ConfigChange" | oc create -f -
    
oc status
echo "Get IS"
oc get is
echo "Get Logs"
oc logs -f bc/jenkins-agent-appdev

oc get project 
oc get pods
# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`

echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/Gabriela-Phillips/tasks.git"
        ref: "master"
      contextDir: "/openshift-tasks"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: Jenkinsfile
        env:
          - name: "GUID"
            value: "573d"
          - name: "REPO"
            value: "https://github.com/Gabriela-Phillips/tasks.git"
          - name: "CLUSTER"
            value: "na311.openshift.opentlc.com"
kind: List
metadata: []" | oc create -f - 
oc get project
oc get pods
# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  echo ${AVAILABLE_REPLICAS}
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  echo "${AVAILABLE_REPLICAS}"
  sleep 10
done
