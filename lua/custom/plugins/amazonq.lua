return {
  'awslabs/amazonq.nvim',
  enabled = require('nixCatsUtils').enableForCategory 'ai' and require('utils.init').nowork(),
  opts = {
    ssoStartUrl = os.getenv 'AMAZON_Q_SSO_URL' or 'https://view.awsapps.com/start', -- Authenticate with Amazon Q Free Tier
  },
}
