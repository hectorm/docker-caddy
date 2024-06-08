logging: logs: {
  default: {
    exclude: ["http.log.access.log0"]
  }
  log0: {
    writer: output: "stdout"
    encoder: {
      format: "transform"
      template: #"{common_log}"#
    }
    include: ["http.log.access.log0"]
  }
}

apps: {
  http: servers: srv0: {
    listen: [":443"]
    routes: [{
      terminal: true,
      match: [{
        host: ["localhost"]
      }]
      handle: [{
        handler: "subroute"
        routes: [{
          handle: [{
            handler: "vars"
            root: "{$CADDYWWWPATH:/var/www/html}"
          }, {
            handler: "file_server"
          }]
        }]
      }]
    }]
    logs: logger_names: {
      localhost: ["log0"]
    }
  }
  tls: automation: {
    policies: [{
      subjects: ["localhost"]
      issuers: [{
        module: "internal"
      }]
    }]
  }
  pki: certificate_authorities: local: {
    install_trust: false
  }
}
