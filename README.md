The script metersphere/runTestPlan.sh is compatible with MeterSphere version 2.10.x

Usage of the script:
 bash runTestPlan.sh accessKey secretKy projectName envName testPlanName HOST_URL resourcePoolName userId

Explanation of the parameters:
 - accessKey: the accessKey of the user in MeterSphere
 - secretKey: the secretKey of the user in MeterSphere
 - projectName: the project name in MeterSphere
 - envName: the environment name in MeterSphere, with which the test case runs
 - testPlanName: the test plan name in MeterSphere, which is to be executed
 - HOST_URL: the URL of the MeterSphere. e.g. https://metersphere.company.com:9443
 - resourcePoolName: the resource pool name in MeterSphere, where the job will be running
 - userId: the userId of the user who will kick off the test case. 
