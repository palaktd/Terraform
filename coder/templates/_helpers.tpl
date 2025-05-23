{{/*
Selector labels
# SelectorLabels are immutable. Add labels here which should not be changed with new version upgrade.
*/}}

{{- define "coder.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/*
Coder app common labels
# These are the common labels used which can be changed at appversion or chart version upgrade.
*/}}

{{- define "coder.labels" -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/Chart: "{{ .Chart.Name }}-{{.Chart.Version | replace "+" "_" | trunc 6 | trimSuffix "_"}}"
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{ include "coder.selectorLabels" . }}
app.kubernetes.io/component: {{ .Chart.Name | quote }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end -}}

{{- define "probe.fields" -}}
initialDelaySeconds: 60
periodSeconds: 10
timeoutSeconds: 5
failureThreshold: 3
{{- end -}}
