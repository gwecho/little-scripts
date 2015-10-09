#!/bin/sh

ds_salt_nodegroup="ds-all"
fs_salt_nodegroup="fs-all"
xidan_haproxy="0.0.0.0"
shaxi_haproxy="0.0.0.0"
rabbitmq_server="msg.ds.pub.sina.com.cn"

function usage()
{
    echo "usage(): switch_rabbitmq.sh switch_to(xidan|shaxi)"
    exit 1
}

function switch_hostaddr()
{
    ha_addr=$1
    echo "switch $rabbitmq_server to $ha_addr"
    salt -N ds-all cmd.run "sed -i \"s/.\+\(msg.ds.pub.sina.com.cn\)/$ha_addr \1/g\" /etc/hosts"
    salt -N fs-all cmd.run "sed -i \"s/.\+\(msg.ds.pub.sina.com.cn\)/$ha_addr \1/g\" /etc/hosts"
}

function restart_backwrite()
{
    backwrite_hosts=(0.0.0.1 0.0.0.2)
    echo "restart backwrite daemon"
    for host in ${backwrite_hosts[@]}
    do
        echo "  restart $host..."
        supervisorctl -s http://$host:6543/ -u backwrite -p backwrite restart all
        if [ $? -ne 0 ]; then echo "  failed"; echo $?; else echo "  succeed"; fi
    done
}

function restart_docservice_daemon()
{
    docservice_daemon_hosts=(0.0.0.1 0.0.0.2 0.0.0.3 0.0.0.4)
    echo "restart docservice daemon"
    for host in ${docservice_daemon_hosts[@]}
    do
        echo "  restart $host..."
        supervisorctl -s http://$host:9001/  restart dpdm:* 
        supervisorctl -s http://$host:9001/  restart dpdm_schedule 
        if [ $? -ne 0 ]; then echo "  failed"; echo $?; else echo "  succeed"; fi
    done
}

function restart_refreshDocCache()
{
    refreshDocCache_hosts=(0.0.0.1 0.0.0.2 0.0.0.3 0.0.0.4)
    echo "restart refreshDocCache daemon"
    for host in ${refreshDocCache_hosts[@]}
    do
        echo "  restart $host..."
        supervisorctl -s http://$host:9001/  restart refreshDocCache 
        if [ $? -ne 0 ]; then echo "  failed"; echo $?; else echo "  succeed"; fi
    done
}

function restart_fs_daemon()
{
    fs_daemon_hosts=(0.0.0.1 0.0.0.2 0.0.0.3 0.0.0.4)
    echo "restart fs daemon"
    for host in ${fs_daemon_hosts[@]}
    do
        echo "  restart $host..."
        supervisorctl -s http://$host:9001/  restart s3q_daemon:*
        if [ $? -ne 0 ]; then echo "  failed"; echo $?; else echo "  succeed"; fi
    done
}

function restart_daemon()
{
    restart_backwrite
    restart_docservice_daemon
    restart_refreshDocCache
    restart_fs_daemon
}

if [ $# -lt 1 ]; then
    usage
fi
switchto=$1
case "$switchto" in
        "toxidan"|"xidan")
                switch_hostaddr $xidan_haproxy
        ;;
        "toshaxi" | "shaxi")
                switch_hostaddr $shaxi_haproxy
        ;;
        *)
                echo "rabbitmq sits on xidan and shaxi, please input 'xidan' or 'shaxi'"
esac

restart_daemon

exit 0
