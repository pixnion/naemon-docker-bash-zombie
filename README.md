# naemon-docker-bash-zombie

Build and start:

`docker build -t pixnion/naemon-zombie . && docker run --rm --name naemon_zombie pixnion/naemon-zombie`

Once started, in another terminal, look for zombies, ~~which should show up quite quickly~~:

`while :; do docker exec naemon_zombie ps auxwwf; sleep 1; done`

**UPDATE:** No longer an issue by running naemon through supervisor in docker.
