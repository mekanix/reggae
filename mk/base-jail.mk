BASE_WORKDIR != reggae get-config BASE_WORKDIR
PKG_PROXY != reggae get-config PKG_PROXY
DHCP ?= dhcpcd
UPDATE ?= yes
MKJAIL_OPTIONS =

.if exists(${EXTRA_FSTAB})
MKJAIL_OPTIONS += -f ${EXTRA_FSTAB}
.endif

.if target(pre_up)
up: setup pre_up
.else
up: setup
.endif
	@echo -n "Booting ..."
	@mdo service jail start ${SERVICE} >/dev/null 2>&1
	@echo " done"
.if ${DEVEL_MODE} == "YES"
	@mdo sysrc -s jail jail_list-="${SERVICE}"
.if !exists(${BASE_WORKDIR}/${SERVICE}/home/devel)
	@mdo jexec ${SERVICE} pw groupadd devel -g ${GID}
	@mdo jexec ${SERVICE} pw useradd devel -u ${UID} -g devel -s /bin/tcsh -G wheel,operator -m
	@mdo jexec ${SERVICE} chpass -p '$6$MIv4IXAika7jqFH2$GkYSBax0G9CIBG0DcgQMP5gG7Qt.CojExDcU7YOQy0K.pouAd.edvo/MaQPhVO0fISxjOD4J1nzRsGVXUAxGp1' devel
.endif
.else
	@mdo sysrc -s jail jail_list+="${SERVICE}"
	@mdo jexec ${SERVICE} pw user del devel -r >/dev/null 2>&1 || true
.endif
	@mdo jexec ${SERVICE} pwd_mkdb /etc/master.passwd
.if target(post_up)
	@${MAKE} ${MAKEFLAGS} post_up
.endif
.if !exists(${BASE_WORKDIR}/${SERVICE}/.provisioned)
	@${MAKE} ${MAKEFLAGS} provision
.endif

provision: setup
	-@mdo touch ${BASE_WORKDIR}/${SERVICE}/.provisioned
.for provisioner in ${PROVISIONERS}
	@${MAKE} ${MAKEFLAGS} provision-${provisioner}
.endfor

.if target(pre_down)
down: setup pre_down
.else
down: setup
.endif
	@mdo service jail stop ${SERVICE}
.if target(post_down)
	@${MAKE} ${MAKEFLAGS} post_down
.endif

.if target(pre_destroy)
destroy: pre_destroy
.else
destroy:
.endif
	@mdo reggae rmjail ${SERVICE}
.for provisioner in ${PROVISIONERS}
	@${MAKE} ${MAKEFLAGS} clean-${provisioner}
.endfor
.if target(post_destroy)
	@${MAKE} ${MAKEFLAGS} post_destroy
.endif

.if target(pre_setup)
setup: pre_setup
.else
setup:
.endif
.for provisioner in ${PROVISIONERS}
	@${MAKE} ${MAKEFLAGS} setup-${provisioner}
.endfor
.if target(post_setup)
	@${MAKE} ${MAKEFLAGS} post_setup
.endif
.if !exists(${BASE_WORKDIR}/${SERVICE})
	@mdo env PRESTART="${PRESTART}" POSTSTART="${POSTSTART}" PRESTOP="${PRESTOP}" POSTSTOP="${POSTSTOP}" OS_VERSION="${VERSION}" UPDATE="${UPDATE}" DHCP="${DHCP}" ALLOW="${ALLOW}" PORTS="${PORTS}" reggae mkjail ${MKJAIL_OPTIONS} ${SERVICE}
.endif
.if ${DEVEL_MODE} == "YES"
.if !exists(${BASE_WORKDIR}/${SERVICE}/usr/src)
	@mdo mkdir ${BASE_WORKDIR}/${SERVICE}/usr/src >/dev/null 2>&1
.endif
	-@mdo mount -t nullfs ${PWD} ${BASE_WORKDIR}/${SERVICE}/usr/src >/dev/null 2>&1
.endif
.if !exists(${BASE_WORKDIR}/${SERVICE}/home/provision/.ssh/authorized_keys)
	@mdo cp ~/.ssh/id_rsa.pub ${BASE_WORKDIR}/${SERVICE}/home/provision/.ssh/authorized_keys
	@mdo chmod 600 ${BASE_WORKDIR}/${SERVICE}/home/provision/.ssh/authorized_keys
	@mdo chown -R 666:666 ${BASE_WORKDIR}/${SERVICE}/home/provision/.ssh
.endif
.if target(post_create)
	@${MAKE} ${MAKEFLAGS} post_create
.endif

login:
.if defined(user)
	@mdo jexec ${SERVICE} login -f ${user}
.else
	@mdo jexec ${SERVICE} login -f root
.endif

exec:
	@mdo jexec ${SERVICE} ${command}

.if target(pre_export)
export: pre_export
.else
export:
.if !exists(build)
	@mkdir build
.endif
	@mdo reggae export ${SERVICE} build
	@echo "Chowning ${SERVICE}.img to ${UID}:${GID} ..."
	@mdo chown ${UID}:${GID} build/${SERVICE}.img
.if target(post_export)
	@${MAKE} ${MAKEFLAGS} post_export
.endif
.endif

devel_check:
.if ${DEVEL_MODE} != "YES"
	@echo "DEVEL_MODE must be set to YES"
	@exit 1
.endif

.if target(do_devel)
devel: devel_check up do_devel
.else
devel: devel_check up
	mdo jexec -U devel ${SERVICE} env OFFLINE=${offline} SYSPKG=${SYSPKG} /usr/src/bin/devel.sh
.if target(post_devel)
	@${MAKE} ${MAKEFLAGS} post_devel
.endif
.endif

.if target(do_test)
test: up do_test
.else
test: up
	@mdo jexec -U devel ${SERVICE} env OFFLINE=${offline} SYSPKG=${SYSPKG} /usr/src/bin/test.sh
.endif

upgrade: up
	@mdo jexec ${SERVICE} pkg upgrade -y
