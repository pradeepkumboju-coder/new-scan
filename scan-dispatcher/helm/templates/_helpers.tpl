{{/*
Generate name
*/}}
{{- define "central-scan-listener.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Generate fullname
*/}}
{{- define "central-scan-listener.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "central-scan-listener.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "central-scan-listener.labels" -}}
app.kubernetes.io/name: {{ include "central-scan-listener.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Secret Name
*/}}
{{- define "central-scan-listener.secretName" -}}
{{ include "central-scan-listener.fullname" . }}-secrets
{{- end }}

{{/*
ServiceAccount
*/}}
{{- define "central-scan-listener.serviceAccountName" -}}
{{ include "central-scan-listener.fullname" . }}-sa
{{- end }}
