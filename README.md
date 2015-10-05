# Clear Measure Bootcamp 
Current Build Status [![](http://build.clear-measure.com/app/rest/builds/buildType:(id:BootCamp_CompileAndTest)/statusIcon)](http://teamcity/viewType.html?buildTypeId=btN&guest=1)

**This project is the starting point for folks taking part in the Clear Measure 
Bootcamp.** 

This course is a feature-driven walkthrough that guides participants through
a series of improvements to an existing code base, demonstrating best pracitices and 
and working through scenarios targetting 300- and 400-level developers.

## Getting Started

- Clone the repo
- Configure your db (see pre-requisites below)
- Run the click to build script
- **Build** the application in Visual Studio 2015
- **Run** the application from VS

## Application Overview

The starting point is an expense report application with a very limited feature set, and
room to improve. You will work through defining and prioritizing new features, then work 
in pairs to build these out. Your product owner/trainer/engineering manager will present you with new requirements
while you map out how things will be built, pair programming and working through a series
of iterations, writing tests and leveraging CI. Roll up the sleeves!


## Pre-requisites

You will need to have the following installed for this project to work:

 - [Visual Studio 2015 RTM] (https://www.visualstudio.com/downloads/download-visual-studio-vs)
 - [SQL Server Express 2014] (https://www.microsoft.com/en-ca/server-cloud/products/sql-server-editions/sql-server-express.aspx) with an instance named SQLEXPRESS2014 (for other options, see note below)
 - A GitHub account ([good thing you're already here](https://github.com/join))

## Automated Build

#TODO Initial build docs here

Chained Build - Create And Deploy Octopus Release

First we had to make sure the octo.exe tools were installed on the build server.
Then on the TC server we had to create the build with the three build steps.
In the build configuration for step 1 Create Octopus Deploy Release we use the OctopusDeploy: Create Release runner.
Get the API key from Octopus Deploy if it exists, if not create one.

Once we've verified that the Release is being created we can move on to the AWS environment.
The second build step will basically call a powershell script that uses the AWS CLI to create the environment from a CloudFormation build template (JSON).
To make this work easier I uploaded the template file, and another JSON file containing the parameters for the environment to a folder in our AWS S3 bucket.  #TODO add step in build to push to S3 bucket automatically instead of manually.
** Note: make sure to install the AWS CLI on the TC build agent. **

The third and final build step is to deploy the release created in step 1 of the build.
Again we use the TC octo runner to handle all the heavy lifting.  Use the same API key from step 1.
I am not sure what the problem is with this step, it keeps failing with the error: "There must be at least one machine to deploy to in the environment".
The deploy script is throwing an error that the "userName" is not valid, update and try again.
Logs on the build server to check:
C:\Program Files\Amazon\Ec2ConfigService\Logs\Ec2ConfigLog.txt
C:\TentacleInstallLog.txt

