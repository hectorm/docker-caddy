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
