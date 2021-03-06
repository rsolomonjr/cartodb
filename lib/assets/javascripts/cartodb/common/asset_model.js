var cdb = require('cartodb.js');
var Backbone = require('backbone');
var _ = require('underscore');

/** 
 *  Model that let user upload files
 *  to our endpoints
 *
 */

module.exports = Backbone.Model.extend({

  url: function(method) {
    var version = cdb.config.urlVersion('asset', method);
    return '/api/' + version + '/users/' + this.userId + '/assets'
  },

  fileAttribute: 'filename',

  initialize: function(attrs, opts) {
    if (!opts.userId) {
      throw new Error('user id is required');
    }
    this.userId = opts.userId;
  }

});