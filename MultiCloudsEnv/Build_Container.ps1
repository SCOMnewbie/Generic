$ErrorActionPreference = 'Stop'
#docker run -it --rm -v "$(pwd):/pwshmount" -w pwshmount mcr.microsoft.com/powershell
docker run -it --rm -v "$(pwd):/pscloudevenv" -w "/pscloudevenv" pscloudevenv:latest
#docker run -it --rm pscloudevenv:latest

#Create docker image
docker build -t pscloudevenv:latest .

#Clean up image
docker image rm pscloudevenv:latest -f


