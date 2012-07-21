stylus           = require 'stylus'
nib              = require 'nib'
browserify       = require 'browserify'
cleancss         = require 'clean-css'
path             = require 'path'
fs               = require 'fs'
{uglify, parser} = require 'uglify-js'

module.exports   = (wintersmith, callback) ->

  logger = wintersmith.logger

  class PerianPlugin extends wintersmith.ContentPlugin

    constructor: (@_filename, @_base) ->

    getFilename: ->
      @_filename.replace(/coffee$/, 'js').
                 replace(/styl$/, 'css')

    render: (locals, contents, templates, callback) ->
      self = this
      extname = path.extname(self._filename)
      file = path.join(self._base, self._filename)

      switch extname
        when '.css', '.styl'
          fs.readFile file, (error, buffer) ->
            text = buffer.toString()
            if error
              callback error
            else
              try
                if extname is '.styl'
                  logger.verbose "Stylus #{self._filename}"
                  stylus(text).
                    set('filename', self.getFilename()).
                    set('paths', [path.dirname(file)]).
                    set('include css', true).
                    use(nib()).
                    render (err, css) ->
                      if err
                        callback err
                      else
                        logger.verbose "CleanCss #{self._filename}"
                        res = cleancss.process(css)
                        callback null, new Buffer(res)
                else
                  logger.verbose "CleanCss #{self._filename}"
                  res = cleancss.process(text)
                  callback null, new Buffer(res)
              catch error
                callback error

        when '.js', '.coffee'
          bundle = browserify
            cache: false
            watch: false

          bundle.addListener 'syntaxError', (error) ->
            callback error
            callback = null # prevent twice calls

          try
            logger.verbose "Browserify #{self._filename}"
            bundle.addEntry path.join(self._base, self._filename)

            logger.verbose "Uglify #{self._filename}"
            ast = parser.parse bundle.bundle()
            ast = uglify.ast_mangle ast
            ast = uglify.ast_squeeze ast
            res = uglify.gen_code ast
            callback? null, new Buffer(res)
          catch error
            callback? error

    @fromFile: (filename, base, callback) ->
      callback null, new PerianPlugin filename, base

  wintersmith.registerContentPlugin 'scripts', '**/*.{js,coffee}', PerianPlugin
  wintersmith.registerContentPlugin 'styles',  '**/*.{css,styl}',  PerianPlugin
  callback()
