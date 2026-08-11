{{- define "masaren.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "masaren.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "masaren.selectorLabels" -}}
app.kubernetes.io/name: {{ include "masaren.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
