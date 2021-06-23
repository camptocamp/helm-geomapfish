{{/* vim: set filetype=mustache: */}}
/*
Expand the name of the chart.
*/}}
{{- define "c2cgeoportal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "c2cgeoportal.fullname" -}}
{{-   if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{-   else -}}
{{-     $name := default .Chart.Name .Values.nameOverride -}}
{{-     if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{-     else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{-     end -}}
{{-   end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "c2cgeoportal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "c2cgeoportal.redisUrl" -}}
{{-   if .Values.redis.external.enabled -}}
redis://{{ .Values.redis.external.host }}:6379/{{ .Values.redis.external.db }}
{{-   else -}}
redis://{{ template "c2cgeoportal.fullname" . }}-redis:6379
{{-   end -}}
{{- end -}}

{{- define "commonPodConfig" }}
{{-   template "common.podConfig" . }}
{{-   if .root.Values.imagePullSecrets }}
imagePullSecrets:
  - name: {{ template "c2cgeoportal.fullname" .root }}-dockerhubcred
{{-    end }}
{{- end -}}

{{- define "c2cwsgiutilsEnv" }}
            - name: C2C_BROADCAST_PREFIX
              value: broadcast_{{ .service }}{{ if .root.Values.redis.external.enabled }}{{ .root.Values.redis.external.db }}{{ end }}
            {{- if .root.Values.redis.external.sentinel }}
            - name: C2C_REDIS_SENTINELS
              value: {{ .root.Values.redis.external.host }}:{{ .root.Values.redis.external.port }}
            - name: C2C_REDIS_TIMEOUT
              value: {{ .root.Values.redis.external.timeout | quote }}
            - name: C2C_REDIS_SERVICENAME
              value: {{ .root.Values.redis.external.servicename }}
            {{- else }}
            - name: C2C_REDIS_URL
              value: {{ template "c2cgeoportal.redisUrl" .root }}
            {{- end }}
            - name: C2C_REDIS_DB
              value: {{ .root.Values.redis.external.db | quote }}
          {{- if .root.Values.c2c.profiler.enabled }}
            - name: C2C_PROFILER_PATH
              value: /{{ .root.Values.c2c.profiler.pathPrefix }}{{ .service }}
          {{- end }}
            - name: GUNICORN_PARAMS
              value: >-
                --bind=:8080
                --worker-class=gthread
                --threads={{ .root.Values.c2c.nbThreads }}
                --workers={{ if .root.Values.c2c.profiler.enabled }}1{{ else }}{{ .root.Values.c2c.nbProcesses }}{{ end }}
                {{- if gt .root.Values.c2c.nbProcesses 1.0 }}
                --max-requests=2000
                --max-requests-jitter=200
                {{- end }}
                --timeout={{.root.Values.timeout}}
                {{- if .root.Values.c2c.statsd.enabled }}
                --statsd-host={{ .root.Values.c2c.statsd.url }}
                --statsd-prefix={{ .service }}.{{ .root.Release.Name }}
                {{- end }}
                {{- if .root.Values.c2c.gunicorn_config }}
                 --config={{ .root.Values.c2c.gunicorn_config }}
                {{- end }}
                --worker-tmp-dir=/dev/shm
            - name: C2C_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ template "c2cgeoportal.fullname" .root }}
                  key: c2c-secret
            - name: C2C_LOG_VIEW_ENABLED
              value: "1"
            - name: C2C_DEBUG_VIEW_ENABLED
              value: "1"
            - name: C2C_SQL_PROFILER_ENABLED
              value: "1"
            - name: LOG_TYPE
              value: {{ .root.Values.c2c.logging.type }}
          {{- if eq .root.Values.c2c.logging.type "logstash" }}
            - name: LOG_HOST
              value: {{ .root.Values.c2c.logging.host }}
            - name: LOG_PORT
              value: {{ .root.Values.c2c.logging.port }}
          {{- end }}
            - name: C2C_REQUESTS_DEFAULT_TIMEOUT
              value: {{ .root.Values.c2c.requestsDefaultTimeout | quote }}
          {{- if .root.Values.c2c.sentry.enabled }}
            - name: SENTRY_URL
              value: https://{{ .root.Values.c2c.sentry.key }}@{{ .root.Values.c2c.sentry.hostname }}/{{ .root.Values.c2c.sentry.project }}
            - name: SENTRY_CLIENT_RELEASE
              value: {{ .root.Values.version | quote }}
            - name: SENTRY_CLIENT_ENVIRONMENT
              value: {{ .root.Release.Name }}
            - name: SENTRY_TAG_SERVICE
              value: {{ .service }}
          {{- end }}
            {{- include "statsd.config" .  | nindent 12 }}
{{- end -}}


{{- define "c2cgeoportal.db" }}
- name: PGPORT
  value: "5432"
- name: PGPORT_SLAVE
  value: "5432"
{{- if .Values.postgresql.schema }}
- name: PGSCHEMA
  value: {{ .Values.postgresql.schema | quote }}
{{- end }}
- name: PGSCHEMA_STATIC
  value: {{ .Values.postgresql.staticSchema | quote }}
- name: PGOPTIONS
  value: "-c statement_timeout={{ .Values.postgresql.statementTimeout}}"
- name: PGHOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.secret }}
      key: hostname
- name: PGHOST_SLAVE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.secret }}
      key: hostnameSlave
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.secret }}
      key: database
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.secret }}
      key: username
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.secret }}
      key: password
{{- end -}}


{{- define "c2cgeoportal.config" }}
          {{- if .Values.openshift }}
          image: " "
          {{- else }}
          image: "{{ .Values.image.repositoryPrefix }}-config:{{ .Values.image.tag }}"
          {{- end }}
          imagePullPolicy: {{ .Values.openshift | ternary "IfNotPresent" .Values.image.pullPolicy }}
          {{- include "common.containerConfig" (dict "service" .Values.config "root" .) | indent 10 }}
          securityContext:
            runAsNonRoot: true
            {{- if not .Values.openshift }}
            runAsUser: 33  # www-data
            {{- end }}
          env:
            # Config env
            {{- include "c2cgeoportal.configEnv" . | indent 12}}
{{- end }}

{{- define "c2cgeoportal.configEnv" }}
- name: TILECLOUDCHAIN_INTERNAL_URL
  value: "http://{{ template "c2cgeoportal.fullname" . }}-tilecloudchain/"
{{- if .Values.s3.enabled }}
- name: TILEGENERATION_S3_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.secretRef }}
      key: hostname
- name: TILEGENERATION_S3_BUCKET
  value: {{ .Values.tilecloudchain.s3.bucket }}
{{- end }}
- name: GEOPORTAL_INTERNAL_URL
  value: "http://{{ template "c2cgeoportal.fullname" . }}-geoportal/"
- name: VISIBLE_WEB_HOST
  value: "{{ (index .Values.ingress.hosts 0).host }}"
- name: VISIBLE_WEB_PROTOCOL
  {{- if .Values.ingress.tls }}
  value: https
  {{- else }}
  value: http
  {{- end }}
- name: VISIBLE_ENTRY_POINT
  value: "{{ .Values.geoportal.entrypoint }}"
{{- if and .Values.sharedConfigManager.enabled .Values.sharedConfigManager.print }}
- name: VISIBLE_ENTRY_POINT_RE_ESCAPED
  value: {{ replace "." "\\." .Values.geoportal.entrypoint | quote }}
- name: VISIBLE_WEB_HOST_RE_ESCAPED
  value: {{ replace "." "\\." (index .Values.ingress.hosts 0).host | quote }}
- name: GEOPORTAL_INTERNAL_HOST
  value: "{{ template "c2cgeoportal.fullname" . }}-geoportal"
- name: GEOPORTAL_INTERNAL_PORT
  value: "80"
- name: TILECLOUDCHAIN_INTERNAL_HOST
  value: "{{ template "c2cgeoportal.fullname" . }}-tilecloudchain"
- name: TILECLOUDCHAIN_INTERNAL_PORT
  value: "80"
{{- end }}
{{- template "c2cgeoportal.db" . }}
{{- if .Values.redis.external.enabled }}
- name: REDIS_HOST
  value: {{ .Values.redis.external.host }}
- name: REDIS_DB
  value: {{ .Values.redis.external.db | quote }}
{{- if .Values.redis.external.sentinel }}
- name: REDIS_SERVICENAME
  value: {{ .Values.redis.external.servicename }}
- name: REDIS_TIMEOUT
  value: {{ .Values.redis.external.timeout | quote }}
{{- end }}
- name: REDIS_PORT
  value: {{ .Values.redis.external.port | quote }}
{{- else }}
- name: REDIS_HOST
  value: {{ template "c2cgeoportal.fullname" . }}-redis
- name: REDIS_PORT
  value: "6379"
{{- end }}
{{- if and .Values.tilecloudchain.enabled .Values.mapcache.enabled }}
- name: MAPCACHE_URL
  value: "http://{{ template "c2cgeoportal.fullname" . }}-mapcache/mapcache/"
{{- end }}
{{- if .Values.mapserver.enabled }}
- name: MAPSERVER_URL
  value: "http://{{ template "c2cgeoportal.fullname" . }}-mapserver/"
{{-   if .Values.postgresql.schema }}
{{-   if lt .Values.version 2.4 }}
- name: MAPSERVER_DATA_SUBSELECT
  value: "SELECT ST_Collect(ra.area)
          FROM {{ .Values.postgresql.schema }}.restrictionarea AS ra,
          {{ .Values.postgresql.schema }}.role_restrictionarea AS rra,
          {{ .Values.postgresql.schema }}.layer_restrictionarea AS lra,
          {{ .Values.postgresql.schema }}.treeitem AS la
          WHERE rra.role_id in (%role_ids%) AND rra.restrictionarea_id = ra.id
          AND lra.restrictionarea_id = ra.id AND lra.layer_id = la.id AND la.name = "
- name: MAPSERVER_DATA_NOAREA_SUBSELECT
  value: "SELECT rra.role_id
          FROM {{ .Values.postgresql.schema }}.restrictionarea AS ra,
          {{ .Values.postgresql.schema }}.role_restrictionarea AS rra,
          {{ .Values.postgresql.schema }}.layer_restrictionarea AS lra,
          {{ .Values.postgresql.schema }}.treeitem AS la
          WHERE rra.restrictionarea_id = ra.id AND lra.restrictionarea_id = ra.id
          AND lra.layer_id = la.id AND la.name = "
- name: MAPSERVER_JOIN_TABLES
  value: "{{ .Values.postgresql.schema }}.restrictionarea AS ra,
          {{ .Values.postgresql.schema }}.role_restrictionarea AS rra,
          {{ .Values.postgresql.schema }}.layer_restrictionarea AS lra,
          {{ .Values.postgresql.schema }}.treeitem AS la"
- name: MAPSERVER_JOIN_WHERE
  value: "rra.role_id in (%role_ids%) AND rra.restrictionarea_id = ra.id AND
          lra.restrictionarea_id = ra.id AND lra.layer_id = la.id AND la.name = "
{{-   end }}
{{-   end }}
{{- end }}
{{- if .Values.qgisserver.enabled }}
- name: QGISSERVER_URL
  value: "http://{{ template "c2cgeoportal.fullname" . }}-qgisserver/"
{{- end }}
{{- if and .Values.tilecloudchain.enabled .Values.mapcache.enabled }}
- name: MEMCACHED_HOST
  value: "{{ template "c2cgeoportal.fullname" . }}-memcached"
- name: MEMCACHED_PORT
  value: "11211"
{{- end }}
{{- template "c2cgeoportal.awscreds" (.Values.geoportal.s3 | default .Values.s3) }}
{{- range $name, $value := .Values.config.env }}
{{- if not ( kindIs "invalid" $value ) }}
- name: {{ $name | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end -}}


{{- define "dockercred" -}}
{
  "auths": {
    {{ .Values.imagePullSecrets.registry | quote }}: {
      "auth": {{ (printf "%s:%s" .Values.imagePullSecrets.username .Values.imagePullSecrets.password) | b64enc | quote}},
      "email": {{ .Values.imagePullSecrets.email | quote }}
    }
  }
}
{{- end }}


{{- define "c2cgeoportal.awscreds" -}}
{{-   if .enabled }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .secretRef }}
      key: access_key
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .secretRef }}
      key: secret_key
- name: AWS_DEFAULT_REGION
  valueFrom:
    secretKeyRef:
      name: {{ .secretRef }}
      key: region
- name: AWS_S3_ENDPOINT
  valueFrom:
    secretKeyRef:
      name: {{ .secretRef }}
      key: hostname
{{-   end }}
{{- end }}


{{- define "c2cgeoportal.sharedConfig" }}
          {{- if .root.Values.openshift }}
          image: " "
          {{- else }}
          image: {{ .root.Values.sharedConfigManager.image.name }}:{{ .root.Values.sharedConfigManager.image.tag }}
          {{- end }}
          imagePullPolicy: {{ .root.Values.openshift | ternary "IfNotPresent" .root.Values.image.externalPullPolicy }}
          readinessProbe: &configProbe
            exec:
              command:
                - scm-is-ready
            initialDelaySeconds: 30
          livenessProbe: *configProbe
          env:
            - name: MASTER_CONFIG
              value: |
                key: {{ .root.Values.sharedConfigManager.key | quote }}
                sources:
                  {{- if and .root.Values.mapserver.enabled .root.Values.sharedConfigManager.mapserver }}
                  mapserver:
                    type: git
                    repo: {{ .root.Values.sharedConfigManager.repo | quote }}
                    branch: {{ .root.Values.sharedConfigManager.branch | quote }}
                    sub_dir: mapserver
                    template_engines:
                      - type: shell
                        environment_variables: true
                    tags: ["mapserver"]
                  {{- end }}
                  {{- if and .root.Values.qgisserver.enabled .root.Values.sharedConfigManager.qgisserver }}
                  qgisserver:
                    type: git
                    repo: {{ .root.Values.sharedConfigManager.repo | quote }}
                    branch: {{ .root.Values.sharedConfigManager.branch | quote }}
                    sub_dir: qgisserver
                    template_engines:
                      - type: shell
                        environment_variables: true
                    tags: ["qgisserver"]
                  {{- end }}
                  {{- if and .root.Values.print.enabled .root.Values.sharedConfigManager.print }}
                  {{-   if .root.Values.sharedConfigManager.customPrintSources }}
{{ indent 18 .root.Values.sharedConfigManager.customPrintSources }}
                  {{-   else }}
                  print:
                    type: git
                    repo: {{ .root.Values.sharedConfigManager.repo | quote }}
                    branch: {{ .root.Values.sharedConfigManager.branch | quote }}
                    sub_dir: print/print-apps
                    template_engines:
                      - type: shell
                        environment_variables: true
                    tags: ["print"]
                  {{-   end }}
                  {{- end }}
            {{- include "statsd.config" .  | nindent 12 }}
            - name: C2C_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ template "c2cgeoportal.fullname" .root }}
                  key: c2c-secret
            - name: C2C_REDIS_URL
              value: {{ template "c2cgeoportal.redisUrl" .root }}
            - name: C2C_BROADCAST_PREFIX
              value: broadcast_scm{{ if .root.Values.redis.external.enabled }}{{ .root.Values.redis.external.db }}{{ end }}_
            {{- if .root.Values.c2c.sentry.enabled }}
            - name: SENTRY_URL
              value: https://{{ .root.Values.c2c.sentry.key }}@{{ .root.Values.c2c.sentry.hostname }}/{{ .root.Values.c2c.sentry.project }}
            - name: SENTRY_CLIENT_RELEASE
              value: {{ .root.Values.image.tag | quote }}
            - name: SENTRY_CLIENT_ENVIRONMENT
              value: {{ .root.Release.Name }}
            - name: SENTRY_TAG_SERVICE
              value: {{ .service }}
            {{- end }}
            - name: LOG_TYPE
              value: {{ .root.Values.c2c.logging.type }}
            {{- if eq .root.Values.c2c.logging.type "logstash" }}
            - name: LOG_HOST
              value: {{ .root.Values.c2c.logging.host }}
            - name: LOG_PORT
              value: {{ .root.Values.c2c.logging.port }}
            {{- end }}
            - name: C2C_REQUESTS_DEFAULT_TIMEOUT
              value: {{ .root.Values.c2c.requestsDefaultTimeout | quote }}
            - name: SCM_ENV_PREFIXES
              value: ""
{{- end }}


{{- define "c2cgeoportal.trigger" -}}
        {
          "from": {
            "kind": "ImageStreamTag",
            "name": "{{ template "c2cgeoportal.fullname" .root }}-{{ .image }}:{{ .tag }}"
          },
          {{- if .container }}
          "fieldPath": "spec.template.spec.containers[?(@.name==\"{{.container}}\")].image"
          {{- else }}
          "fieldPath": "spec.template.spec.initContainers[?(@.name==\"{{.initContainer}}\")].image"
          {{- end }}
        }
{{- end }}
