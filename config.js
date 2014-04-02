// Generated by CoffeeScript 1.7.1
(function() {
  var config;

  config = {
    ga: {
      clientEmail: "1068634003933-b8cijec64sti0if00mnrbqfnrt7vaa7a@developer.gserviceaccount.com",
      privateKeyPath: process.env.GA_KEY_PATH || null,
      profile: "75972512",
      scopeUri: "https://www.googleapis.com/auth/analytics.readonly"
    },
    types: ['users', 'ranking', 'geo'],
    db: {
      socket: '/tmp/redis.sock'
    }
  };

  module.exports = config;

}).call(this);

//# sourceMappingURL=config.map