#!/bin/bash

# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=a73f
REPO=https://github.com/Gabriela-Phillips/tasks.git
CLUSTER=na311.openshift.opentlc.com

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# 1 -- set up Jenkins instance

echo "var Set"
oc set env bc --all GUID=a73f
oc set env bc --all REPO=https://github.com/Gabriela-Phillips/tasks.git
oc set env bc --all CLUSTER=na311.openshift.opentlc.com
echo "Project Retrieved"

oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=8Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true

oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

echo "Jenkins Created In SH Script"
echo "\\*****************//"
# Create custom agent container image with skopeo

oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

echo "Maven Created in SH script"
echo "\\*****************//"

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`

echo "kind: 'BuildConfig'
apiVersion: 'v1'
metadata:
	name: 'tasks-pipeline'
spec:
	strategy:
		jenkinsPipelineStrategy:
			jenkinsfile: 'tasks/openshift-tasks/'
		type: JenkinsPipeline" | oc create -f - -n ${GUID}-jenkins
oc set env bc --all GUID=a73f
oc set env bc --all REPO=https://github.com/Gabriela-Phillips/tasks.git
oc set env bc --all CLUSTER=na311.openshift.opentlc.com

echo "Pipeline Config Built in SH Script"
echo "\\*****************//"

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
