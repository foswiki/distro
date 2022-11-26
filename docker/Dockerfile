FROM debian:11

ARG url=https://github.com/foswiki/distro/releases/download/FoswikiRelease02x01x07/Foswiki-2.1.7.tgz
ARG sha512=7196ce5a586a3770e2d198a79d0856f34724893746a40500b7f72d3efc48dcbdfb0292a3583186cf4e5b217a70df3b5dd8af80aa3e5c34987ca202a62dada0bf
ARG root=/var/www/foswiki
ARG user=www-data
ARG group=www-data
ARG port=80
ARG lang=C.UTF-8
ARG tz=Asia/Shanghai
ARG mirror

ENV LANG=$lang TZ=$tz

RUN set -eux; \
    [ -z "$mirror" ] || sed -i -E "s|http(s?)://deb.debian.org|$mirror|" /etc/apt/sources.list; \
    apt update -y \
    && apt install -y curl diffutils grep less logrotate vim w3m \
        apache2 libapache2-mod-perl2 \
        libalgorithm-diff-perl \
        libapache2-request-perl \
        libarchive-zip-perl \
        libcgi-session-perl \
        libconvert-pem-perl \
        libcrypt-eksblowfish-perl \
        libcrypt-passwdmd5-perl \
        libcrypt-smime-perl \
        libcrypt-x509-perl \
        libdbd-mariadb-perl \
        libdbd-mysql-perl \
        libdbd-pg-perl \
        libdbd-sqlite3-perl \
        libemail-address-xs-perl \
        libemail-mime-perl \
        libemail-simple-perl \
        liberror-perl \
        libfcgi-procmanager-perl \
        libfile-copy-recursive-perl \
        libjson-perl \
        liblocale-codes-perl \
        liblocale-maketext-lexicon-perl \
        liblocale-msgfmt-perl \
    && apt install -y --no-install-recommends \
        libimage-magick-perl \
    && rm -rf /var/lib/apt/lists/* \
    && a2enmod access_compat perl rewrite \
    && a2dissite 000-default

COPY foswiki.conf /etc/apache2/sites-enabled/

RUN set -eux; \
    mkdir -p $root \
    && cd $root \
    && curl -L -s -o foswiki.tgz "$url" \
    && echo "$sha512  foswiki.tgz" > foswiki.tgz.sha512 \
    && sha512sum -c --status foswiki.tgz.sha512 \
    && tar -xzvf foswiki.tgz --strip-components=1 \
    && rm foswiki.tgz foswiki.tgz.sha512 \
    && sh tools/fix_file_permissions.sh \
    && chown -R $user:$group $root \
    && echo "0,30 * * * *  cd $root/bin && perl ../tools/tick_foswiki.pl" | crontab -u $user -

VOLUME $root

EXPOSE $port

CMD ["/bin/sh", "-c", "service cron start && exec apache2ctl -DFOREGROUND -k start"]
