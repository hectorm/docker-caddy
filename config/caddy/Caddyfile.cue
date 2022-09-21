logging: logs: {
  default: {
    exclude: ["http.log.access.log0"]
  },
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
      handle: [{
        handler: "vars"
        root: "{$CADDYWWWPATH}"
      }, {
        handler: "file_server"
      }]
    }]
    logs: default_logger_name: "log0"
  }
  tls: automation: {
    policies: [{
      issuers: [{
        module: "internal"
      }]
      on_demand: true
    }]
    on_demand: rate_limit: {
      interval: 1000000000
      burst: 1
    }
  }
  pki: certificate_authorities: local: {
    install_trust: false
  }
}
