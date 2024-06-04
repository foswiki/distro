# Dockerfile for Foswiki

Run pristine Foswiki in Debian container with Apache 2 + mod_fcgid/mod_proxy_fcgi/mod_perl or Nginx.

## Build

```sh
docker build . -t foswiki --progress plain
```

Notice this Dockerfile uses volume for `/var/www/foswiki`.

## Run

```sh
# Use Apache, may use `-e MODULE=[fcigd|proxy_fcgi|perl]` to choose different Apache module.
docker run -dt --init --name foswiki -p 8888:80 -e TZ=Asia/Shanghai -e HTTPD=apache foswiki


# Use Nginx
docker run -dt --init --name foswiki -p 8888:80 -e TZ=Asia/Shanghai foswiki
```

Access http://localhost:8888 to further configure Foswiki:

1. http://localhost:8888/bin/configure
   1. `Security and Authentication` -> `Registration`: select `Enable User Registration`
   2. `General settings` -> `File System Paths`: set `Safe PATH` to `/bin:/usr/bin`
   3. Click button `Save 2 changes` on the top right corner
2. http://localhost:8888/System/UserRegistration Register your first user, such as WikiName `FirstAdmin`
3. http://localhost:8888/Main/WikiGroups Click `Add Members...` in the group `AdminGroup`, add newly registered user's WikiName
4. Run `docker restart foswiki` to restart the Docker container

Although you can directly access Foswiki in the container, this container is expected to be behind a reverse proxy that terminates HTTPS connections and handles virtual site, you must replace the hostname above to `https://your-reverse-proxy?SSL=1`.

## Extensions

Highly recommended extension for Nginx:

``` sh
su -s /bin/bash www-data
cd /var/www/foswiki
tools/extension_installer XSendFileContrib -r install
tools/configure -save -set '{XSendFileContrib}{Header}=X-Accel-Redirect'
tools/configure -save -set '{XSendFileContrib}{Location}=/files'
```

Beautiful skin extension [NatSkin](https://foswiki.org/Extensions/NatSkin):
``` sh
su -s /bin/bash www-data
cd /var/www/foswiki
tools/extension_installer NatSkin -r install
```

Check https://foswiki.org/Extensions for more extensions.

## Reference

* https://github.com/timlegge/docker-foswiki
* https://foswiki.org/System/InstallationGuide
* https://foswiki.org/System/InstallationGuidePart2
* https://foswiki.org/Support/FoswikiOnNginx
* https://foswiki.org/System/FastCGIEngineContrib#Nginx

