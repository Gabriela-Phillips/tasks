#!/bin/bash

# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=8550
REPO=https://github.com/Gabriela-Phillips/tasks.git
CLUSTER=na311.openshift.opentlc.com

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# 1 -- set up Jenkins instance

oc get project ${GUID}-jenkins
echo "var Set"
oc set env bc --all GUID=8550
oc set env bc --all REPO=https://github.com/Gabriela-Phillips/tasks/openshift-tasks.git
oc set env bc --all CLUSTER=na311.openshift.opentlc.com
echo "Project Retrieved"

oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=8Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true --name='jenkins'

oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

# Create custom agent container image with skopeo
echo "build from Skopeo"
oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
USER root\nRUN yum -y install skopeo && yum clean all\n
USER 1001' --name=jenkins-agent-appdev --context-dir=https://github.com/Gabriela-Phillips/tasks/openshift-tasks.git

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`

oc patch bc jenkins-agent-appdev -p '{"spec":{"source":{"contextDir":"tasks/openshift-tasks"}}}'
echo "Patch executed."
oc get dc
echo "DC Command Run
oc get dc jenkins -n ${GUID}-jenkins -o=json
oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}'

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  echo $AVAILABLE_REPLICAS
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  echo "${AVAILABLE_REPLICAS}"
  sleep 10
done
