#!/bin/sh

set -eux

service cron start

httpd=${HTTPD:-nginx}
module=${MODULE:-fcgid}     # for Apache only

unset HTTPD MODULE          # unset environment variables

case "$httpd" in
    apache)
        case "$module" in
            *fcgid)
                a2enmod fcgid
                a2dismod proxy_fcgi
                a2dismod perl
                ;;

            *proxy_fcgi)
                a2enmod proxy_fcgi
                a2dismod fcgid
                a2dismod perl

                rm -f /var/run/foswiki.pid
                service foswiki start
                ;;

            *perl)
                a2enmod perl
                a2dismod fcgid
                a2dismod proxy_fcgi
                ;;

            *)
                echo "ERROR: unknown engine $module" >&2
                exit 1
        esac

        exec apache2ctl -DFOREGROUND -k start
        ;;

    nginx)
        # Enable xsendfile in Nginx if XSendFileContrib is properly configured
        foswiki_conf=/etc/nginx/sites-enabled/foswiki.conf
        localsite_cfg=/var/www/foswiki/lib/LocalSite.cfg
        if grep -q '^\s*#rewrite.*xsendfile' $foswiki_conf &&
                grep -q '{XSendFileContrib}{Header}\s*=\s*.X-Accel-Redirect.' $localsite_cfg &&
                grep -q '{XSendFileContrib}{Location}\s*=\s*./files.' $localsite_cfg; then
            sed -i -E 's|^(\s*)(rewrite.*viewfile)|\1#\2|; s|^(\s*)#(rewrite.*sendfile)|\1\2|' $foswiki_conf
        fi

        rm -f /var/run/foswiki.pid
        service foswiki start
        exec nginx -g "daemon off;"
        ;;

    *)
        echo "ERROR: unknown httpd $httpd" >&2
        exit 1
esac
