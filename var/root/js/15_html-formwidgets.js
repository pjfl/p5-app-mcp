Date.extend( 'nowMET', function() { // Calculate Middle European Time UTC + 1
   var now = new Date();

   now.setTime( now.getTime() + (now.getTimezoneOffset() + 60) * 60 * 1000 );

   return now;
} );

Date.extend( 'nowUTC', function() { // Calculate UTC
   var now = new Date();

   now.setTime( now.getTime() + now.getTimezoneOffset() * 60 * 1000 );

   return now;
} );

Date.implement( {
   dayFraction: function() { // Elapsed time since SOD in thousandths of a day
      return ( this.getHours() * 3600 + this.getMinutes() * 60
               + this.getSeconds() ) /  86.4;
   },

   swatchTime: function() {
      var met_day_fraction = Date.nowMET().dayFraction();

      return Number.from( met_day_fraction ).format( { decimals: 2 } );
   }
} );

Options.implement( {
   aroundSetOptions: function( options ) {
      options         = options || {};
      this.collection = [];
      this.context    = {};
      this.debug      = false;
      this.log        = function() {};

      [ 'config', 'context', 'debug' ].each( function( attr ) {
         if (options[ attr ] != undefined) {
            this[ attr ] = options[ attr ]; delete options[ attr ];
         }
      }.bind( this ) );

      this.setOptions( options ); var opt = this.options;

      if (! this.config && this.context.config && opt.config_attr)
         this.config = this.context.config[ opt.config_attr ];

      if (! this.config) this.config = {};

      if (this.context.collect) this.context.collect( this );

      if (this.context.window && this.context.window.logger)
         this.log = this.context.window.logger

      return this;
   },

   build: function() {
      var selector = this.options.selector;

      if (selector) $$( selector ).each( function( el ) {
         if (! this.collection.contains( el )) {
            this.collection.include( el ); this.attach( el );
         }
      }, this );
   },

   mergeOptions: function( arg ) {
      arg = arg || 'default';

      if (typeOf( arg ) != 'object') { arg = this.config[ arg ] || {} }

      return Object.merge( Object.clone( this.options ), arg );
   }
} );

String.implement( {
   escapeHTML: function() {
      var text = this;
      text = text.replace( /\&/g, '&amp;'  );
      text = text.replace( /\>/g, '&gt;'   );
      text = text.replace( /\</g, '&lt;'   );
      text = text.replace( /\"/g, '&quot;' );
      return text;
   },

   pad: function( length, str, direction ) {
      if (this.length >= length) return this;

      var pad = (str == null ? ' ' : '' + str)
         .repeat( length - this.length )
         .substr( 0, length - this.length );

      if (!direction || direction == 'right') return this + pad;
      if (direction == 'left') return pad + this;

      return pad.substr( 0, (pad.length / 2).floor() )
           + this + pad.substr( 0, (pad.length / 2).ceil() );
   },

   repeat: function( times ) {
      return new Array( times + 1 ).join( this );
   },

   unescapeHTML: function() {
      var text = this;
      text = text.replace( /\&amp\;/g,    '&' );
      text = text.replace( /\&dagger\;/g, '\u2020' );
      text = text.replace( /\&gt\;/g,     '>' );
      text = text.replace( /\&hellip\;/g, '\u2026' );
      text = text.replace( /\&lt\;/g,     '<' );
      text = text.replace( /\&nbsp\;/g,   '\u00a0' );
      text = text.replace( /\&\#160\;/g,  '\u00a0' );
      text = text.replace( /\&quot\;/g,   '"' );
      return text;
   }
} );

var Calendars = new Class( {
   Implements: [ Options ],

   options: { config_attr: 'calendars', selector: '.calendars' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var cfg; if (! (cfg = this.config[ el.id ])) return;

      var button, opt = this.options, submit = this.context.submit;

      if (submit && (button = $( el.id + '_clear' )))
         button.addEvent( 'click', function( ev ) {
            return submit.clearField( el.id ) } );

      Calendar.setup( Object.append( cfg, {
         inputField: el.id, button: el.id + '_trigger' } ) );
   }
} );

/* Originally created by: Adam Wulf adam.wulf@gmail.com Version 1.4.0
 * http://welcome.totheinter.net/columnizer-jquery-plugin/ */

var Columnizer = new Class( {
   Implements: [ Events, Options ],

   options         : {
      accuracy     : false,
      // true to build columns once regardless of window resize
      // false to rebuild when content box changes bounds
      buildOnce    : false,
      // Percentage left + right padding in CSS for column class
      columnPadding: 1.5,
      // optional # of columns instead of width
      columns      : false,
      // this function is called after content is columnized
      // should columns float left or right
      float        : 'left',
      height       : false,
      // re-columnizing when images reload might make things
      // run slow. so flip this to true if it's causing delays
      ignoreImageLoading: true,
      // ensure the last column is never the tallest column
      lastNeverTallest  : false,
      // an object with options if the text should overflow
      // it's container if it can't fit within a specified height
      lineHeight   : 18,
      maxLoops     : 3,
      overflow     : false,
      // if the content should be columnized into a
      // container node other than it's own node
      target       : false,
      // default width of columnx
      width        : 400
   },

   initialize: function( el, options ) {
      if (options.columns && typeOf( options.columns ) != 'number')
         options.columns = null;

      this.setOptions( options ); var opt = this.options;

      el = $( el ); this.node = $( opt.target ) || el;

      if (! this.node.data) this.node.data = {
          lastWidth: 0, size: this.node.getSize() };

      // images loading after dom load can screw up the column heights,
      // so recolumnize after images load
      if (! opt.ignoreImageLoading && ! opt.target) {
         if (! this.node.data.imageLoaded) {
            this.node.data.imageLoaded = true;

            var images = el.getElements( 'img' );

            if (images.length > 0) {
               // only bother if there are actually images...
               var func = function( obj, el, images ) {
                  return function() {
                     if (! this.node.data.firstImageLoaded) {
                        this.node.data.firstImageLoaded = true;
                        new Columnizer( el, this.options ); // Recurse
                        images.removeEvent( 'abort', func );
                        images.removeEvent( 'load',  func );
                     }
                  }.bind( obj );
               }(this, el, images);

               images.addEvents( { abort: func, load: func } );
               return;
            }
         }
      }

      // this is where we'll put the real content
      this.cache = new Element( 'div' );
      this.cache.adopt( this.node.getChildren().clone() );

      this.build(); this.node.store( 'columnizer', this );

      if (! opt.buildOnce)
         window.addEvent( 'resize', function() { this.build() }.bind( this ) );
   },

   build: function() {
      var opt        = this.options;
      var data       = this.node.data;
      var num_cols   = opt.columns ? opt.columns
                                   : Math.round( data.size.x / opt.width );
      var padding    = opt.columnPadding;
      var width      = Math.floor( (100 - (2 * padding * num_cols)) / num_cols);

      if (data.columnizing || data.lastWidth == width) return;

      data.columnizing = true; data.lastWidth = width;

      if (num_cols <= 1) return this.singleColumnize();

      var style      = { float  : opt.float,
                         padding: '0px ' + padding + '%',
                         width  : width + '%' };

      this.node.setStyles( style );
      this.cache.getChildren().each( function( el ) {
         this.node.grab( el.clone() ) }.bind( this ) );

      var tgt_height = Math.floor( this.node.getHeight() / num_cols );

      this.node.removeProperty( 'style' );

      var horizontal = false, max_loops = opt.maxLoops;

      if (opt.overflow) {
         max_loops = 1; tgt_height = opt.overflow.height;
      }
      else if (opt.height && opt.width) {
         max_loops = 1; tgt_height = opt.height; horizontal = true;
      }

      this.state = [ 0, max_loops, tgt_height ];

      while (this.state[ 0 ] < this.state[ 1 ]) {
         var destroyable
              = this._buildDestroyable( style, num_cols, horizontal );

         this._buildColumns( destroyable, num_cols, horizontal );

         this.state[ 0 ]++;
      }

      data.columnizing = false;

      if (opt.overflow) opt.overflow.fireEvent( 'complete' );

      this.fireEvent( 'complete' );
   },

   _buildColumns: function( destroyable, num_cols, horizontal ) {
      var columns = this.node.getChildren(), opt = this.options;

      if (opt.overflow && ! horizontal) {
         var overflow = $( opt.overflow.id );
         var kids     = destroyable.getChildren();

         overflow.empty().adopt( kids.clone() );
      }
      else if (! horizontal) {
         // the last column in the series
         var col = columns.getLast();

         while (destroyable.childNodes.length ) {
            col.appendChild( destroyable.childNodes[ 0 ] );
         }

         this._buildNewState( columns, num_cols );
      }
      else {
         // it's scrolling horizontally, fix width/classes of the columns
         columns.each( function( col, i ) {
            col.width( this.options.width + 'px' );

            if (i == 0) {
               col.addClass( 'first' );
            }
            else if (i == this.node.childNodes.length - 1) {
               col.addClass( 'last' );
            }
            else {
               col.removeClass( 'first' ); col.removeClass( 'last' );
            }
         }.bind( this ) );

         this.node.width( (columns.length * opt.width) + 'px' );
      }
   },

   _buildDestroyable: function( style, num_cols, horizontal ) {
      var destroyable = this.cache.clone(), opt = this.options;

      this.node.empty(); destroyable.setOpacity( 0 ); // Hide

      // create the columns
      for (var i = 0; i < num_cols; i++) {
         var className = (i == 0) ? 'column first' : 'column';
         var className = (i == num_cols - 1)
                       ? (className + ' last') : className;
         var el = new Element( 'div', { class: className, styles: style } );

         el.inject( this.node, 'inside' );
      }

      // fill all but the last column (unless overflowing)
      var i = 0;

      while (i < num_cols - (opt.overflow ? 0 : 1)
             || horizontal && destroyable.childNodes.length) {
         if (this.node.childNodes.length <= i) {
            // we ran out of columns, make another
            var el = new Element( 'div', { class: className, styles: style } );

            el.inject( this.node, 'inside' );
         }

         var col = $( this.node.childNodes[ i ] );

         this.columnize( col, destroyable, col, this.state[ 2 ] );

         // make sure that the last item in the column isn't a 'dontend'
         if (destroyable.firstChild
             && ! $( destroyable.firstChild ).hasClass( 'dontend' ))
            this.split( col, destroyable, col, this.state[ 2 ] );

         while (this._checkDontEndColumn( col.lastChild )) {
            var para = $( col.lastChild );

            para.dispose(); para.inject( destroyable, 'top' );
         }

         i++;
      }

      return destroyable;
   },

   _buildNewState: function( columns, num_cols ) {
      var opt       = this.options;
      var lastIsMax = false;
      var max       = 0;
      var min       = 10000000;
      var totalH    = 0;

      columns.each( function( col ) {
         var h = col.getHeight(); lastIsMax = false; totalH += h;

         if (h > max) { max = h; lastIsMax = true; }
         if (h < min) { min = h; }
      } );

      var avgH = Math.floor( totalH / num_cols );

      if (opt.lastNeverTallest && lastIsMax) {
         // the last column is the tallest so allow columns
         // to be taller and retry
         this.state[ 2 ] += opt.lineHeight;

         if (this.state[ 0 ] == this.state[ 1 ] - 1) this.state[ 1 ]++;
      }
      else if (max - min > 2 * opt.lineHeight) {
         // too much variation, try again
          this.state[ 2 ] = avgH + opt.lineHeight;
      }
      else if (Math.abs( avgH - this.state[ 2 ] ) > opt.lineHeight) {
         this.state[ 2 ] = avgH; // too much variation, try again
      }
      else {
         this.state[ 0 ] = this.state[ 1 ]; // solid, we're done
      }
   },

   _checkDontEndColumn: function( el ) {
      el = $( el );

      if (el == undefined)           return false;
      if (typeOf( el ) != 'element') return false;
      if (el.hasClass( 'dontend' ))  return true;
      if (el.childNodes.length == 0) return false;

      return this._checkDontEndColumn( el.lastChild );
   },

   columnize: function( putInHere, pullOutHere, parentColumn, height ) {
      while (parentColumn.getHeight() < height
             && pullOutHere.childNodes.length ) {
         putInHere.appendChild( pullOutHere.childNodes[ 0 ] );
      }

      if (putInHere.childNodes.length == 0) return;

      // now we're too tall, undo the last one
      var kids = putInHere.childNodes, kid = kids[ kids.length - 1 ];

      putInHere.removeChild( kid );

      var is_textnode = typeOf( kid ) == 'textnode'
                     || typeOf( kid ) == 'whitespace';

      if (is_textnode) {
         // it's a text node, split it up
         var oText    = kid.nodeValue;
         var counter2 = this.options.accuracy
                      ? this.options.accuracy : this.options.width / 18;
         var columnText, latestTextNode = null;

         while (parentColumn.getHeight() < height && oText.length) {
            if (oText.indexOf( ' ', counter2 ) != '-1')
               columnText = oText.substring( 0, oText.indexOf( ' ', counter2));
            else columnText = oText;

            latestTextNode = document.createTextNode( columnText );
            putInHere.appendChild( latestTextNode );

            if (oText.length > counter2)
               oText = oText.substring( oText.indexOf( ' ', counter2 ) );
            else oText = '';
         }

         if (parentColumn.getHeight() >= height
             && latestTextNode != null) {
            // too tall :(
            putInHere.removeChild( latestTextNode );
            oText = latestTextNode.nodeValue + oText;
         }

         if (oText.length) kid.nodeValue = oText;
         else return false; // we ate the whole text node, move on
      }


      if (pullOutHere.childNodes.length)
         pullOutHere.insertBefore( kid, pullOutHere.firstChild );
      else pullOutHere.appendChild( kid );

      return is_textnode;
   },

   singleColumnize: function() {
      var options = this.options;
      var style   = { float: options.float, padding: '0px 1.5%', width: '97%' };
      var col     = new Element( 'div', { class : 'column first last',
                                          styles: style } );

      this.node.empty(); col.inject( this.node, 'inside' );

      if (options.overflow) {
         var destroyable  = this.cache.clone();
         var tgt_height = options.overflow.height;

         this.columnize( col, destroyable, col, tgt_height );

         // make sure that the last item in the column isn't a 'dontend'
         if (! $( destroyable.firstChild ).hasClass( 'dontend' ))
            this.split( col, destroyable, col, tgt_height );

         while (this._checkDontEndColumn( col.lastChild )) {
            var para = $( col.lastChild );

            para.dispose(); para.inject( destroyable, 'top' );
         }

         var overflow = $( options.overflow.id ).empty();

         while (destroyable.firstChild != undefined) {
            var para = $( destroyable.firstChild );

            para.dispose(); para.inject( overflow, 'inside' );
         }
      }
      else this.cache.inject( col, 'inside' );

      this.node.data.columnizing = false;

      if (options.overflow) options.overflow.fireEvent( 'complete' );

      this.fireEvent( 'complete' );
   },

   split: function( putInHere, pullOutHere, parentColumn, height ) {
      if (! pullOutHere.childNodes.length) return;

      var opt     = this.options;
      var cloneMe = pullOutHere.firstChild, clone = cloneMe.clone();

      if (! typeOf( clone ) == 'element' || clone.hasClass( 'dontend' )) return;

      clone.inject( putInHere, 'inside' );

      if (clone.tag == 'img'
          && parentColumn.getHeight() < height + opt.lineHeight) {
         cloneMe.dispose();
      }
      else if (! cloneMe.hasClass( 'dontsplit' )
               && parentColumn.getHeight() < height + opt.lineHeight) {
         cloneMe.dispose();
      }
      else if (clone.tag == 'img' || cloneMe.hasClass( 'dontsplit' )) {
         clone.dispose();
      }
      else {
         clone.empty();

         if (! this.columnize( clone,  cloneMe,  parentColumn, height )
             && cloneMe.childNodes.length) {
            this.split( clone, cloneMe, parentColumn, height ); // Recurse
         }

         if (clone.childNodes.length == 0) {
            // it was split, but nothing is in it :(
            clone.dispose();
         }
      }
   }
} );

var Columnizers = new Class( {
   Implements   : [ Options ],

   options      : {
      classNames: [ 'zero', 'one', 'two', 'three', 'four', 'five', 'six',
                    'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
                    'thirteen', 'fourteen', 'fifteen' ],
      selector  : '.multiColumn'
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var klass = el.getProperty( 'class' ).split( ' ' )[ 0 ];
      var cols  = this.options.classNames.indexOf( klass );

      new Columnizer( el, this.mergeOptions( { columns: cols } ));
   }
} );

var Cookies = new Class( {
   Implements: [ Options ],

   options  : {
      domain: '',
      expire: 90,
      name  : 'state',
      path  : '/',
      prefix: '',
      secure: false
   },

   initialize: function( options ) {
      this.setOptions( options ); var opt = this.options;

      var cookie_name = (opt.prefix ? opt.prefix + '_' : '') + opt.name;
      var cookie_opts = { domain: opt.domain, duration: opt.expire,
                          path  : opt.path,   secure  : opt.secure };

      this.cookie = new Cookie( cookie_name, cookie_opts );
   },

   get: function( name ) {
      var cookie  = this.cookie.read(); if (! (name && cookie)) return cookie;

      var cookies = cookie.split( '+' );

      for (var i = 0, cl = cookies.length; i < cl; i++) {
         var pair = cookies[ i ].split( '~' );

         if (unescape( pair[ 0 ] ) == name)
            return pair[ 1 ] != 'null' ? unescape( pair[ 1 ] ) : null;
      }

      return '';
   },

   remove: function( name ) {
      var i, cookie = this.cookie.read();

      if (cookie && name) name = escape( name );
      else return false;

      if ((i = cookie.indexOf( name + '~' )) < 0) return false;

      var j = cookie.substring( i ).indexOf( '+' );

      if (i == 0) cookie = (j < 0) ? '' : cookie.substring( j + 1 );

      if (i > 0) {
         cookie = (j < 0)
                ? cookie.substring( 0, i - 1 )
                : cookie.substring( 0, i - 1 ) + cookie.substring( i + j );
      }

      return this.cookie.write( cookie );
   },

   set: function( name, value ) {
      var cookie = this.cookie.read(), i;

      if (name) name = escape( name );
      else return;

      if (value) value = escape( value );

      if (cookie) {
         if ((i = cookie.indexOf( name + '~' )) >= 0) {
            var j = cookie.substring( i ).indexOf( '+' );

            if (i == 0) {
               cookie = (j < 0) ? name + '~' + value
                                : name + '~' + value + cookie.substring( j );
            }
            else {
               cookie = (j < 0) ? cookie.substring( 0, i ) + name + '~' + value
                                : cookie.substring( 0, i ) + name + '~' + value
                                + cookie.substring( i + j );
            }
         }
         else { cookie += '+' + name + '~' + value }
      }
      else { cookie = name + '~' + value }

      return this.cookie.write( cookie );
   }
} );

var Dialog = new Class( {
   Implements: [ Options ],

   Binds: [ '_keyup' ],

   options: {
      klass   : 'dialog',
      maskOpts: {},
      title   : 'Options',
      useMask : true,
   },

   initialize: function( el, body, options ) {
      this.setOptions( options ); this.attach( this.create( el, body ) );
   },

   attach: function( el ) {
      el.addEvent( 'click', function( ev ) {
         ev.stop(); this.hide() }.bind( this ) );
      window.addEvent( 'keyup', this._keyup );
   },

   create: function( el, body ) {
      var opt = this.options;

      if (opt.useMask) this.mask = new Mask( el, opt.maskOpts );

      this.parent = this.mask ? this.mask.element : $( document.body );
      this.dialog = new Element( 'div', { 'class': opt.klass } ).hide()
          .inject( this.parent );

      var title   = new Element( 'div', { 'class': opt.klass + '-title' } )
          .appendText( opt.title ).inject( this.dialog );

      this.close  = new Element( 'span', { 'class': opt.klass + '-close' } )
          .appendText( 'x' ).inject( title );

      body.addClass( opt.klass + '-body' ).inject( this.dialog );
      return this.close;
   },

   hide: function() {
      this.visible = false; this.dialog.hide(); if (this.mask) this.mask.hide();
   },

   position: function() {
      this.dialog.position( { relativeTo: this.parent } );
   },

   show: function() {
      if (this.mask) this.mask.show();

      this.position(); this.dialog.show(); this.visible = true;
   },

   _keyup: function( ev ) {
      ev = new Event( ev ); ev.stop();

      if (this.visible && (ev.key == 'esc')) this.hide();
   }
} );

var FreeList = new Class( {
   Implements: [ Options ],

   options: { selector: 'input.freelist' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      $( el.id + '_add' ).addEvent( 'click', function( ev ) {
         ev.stop(); this.addItem( el.id );
      }.bind( this ) );

      $( el.id + '_remove' ).addEvent( 'click', function( ev ) {
         ev.stop(); this.removeItem( el.id );
      }.bind( this ) );
   },

   addItem: function( id ) {
      var el = $( id ), list = $( id + '_list' ), options = list.options;

      new Element( 'input', {
         name: id, type: 'hidden', value: el.value
      } ).inject( list, 'after' );

      options[ options.length ] = new Option( el.value );
      el.value = null;
      el.focus();
   },

   removeItem: function( id ) {
      var el = $( id ), list = $( id + '_list' ), options = list.options;

      for (var i = options.length - 1; i >= 0; i--) {
         if (options[ i ].selected != true) continue;

         var value = options[ i ].value;

         $$( 'input[name=' + id + ']' ).some( function( el ) {
            if (el.type == 'hidden' && el.value == value) {
               el.destroy(); return true;
            }

            return false;
         } );

         options[ i ].destroy();
      }

      el.focus();
   }
} );

/* Description: An Fx.Elements extension which allows you to easily
 *              create accordion type controls.
 * License: MIT-style license
 * Authors: Valerio Proietti, Peter Flanigan */

Fx.Accordion = new Class( {
   Extends: Fx.Elements,

   options               : {
      alwaysHide        : false,
      display           : 0,
      fixedHeight       : false,
      fixedWidth        : false,
      height            : true,
      initialDisplayFx  : true,
/*    onActive          : function( togglers, index, section ) {}, */
/*    onBackground      : function( togglers, index, section ) {}, */
      opacity           : true,
      returnHeightToAuto: true,
      show              : false,
      trigger           : 'click',
      wait              : false,
      width             : false
   },

   initialize: function() {
      var defined = function( obj ) { return obj != null };
      var params  = Array.link( arguments, {
         'options'  : Type.isObject,
         'togglers' : defined,
         'elements' : defined
      } );

      this.parent( params.elements, params.options );
      this.togglers      = $$( params.togglers );
      this.internalChain = new Chain();
      this.previous      = -1;
      this.effects       = {};

      var opt = this.options;

      if (opt.alwaysHide) opt.wait = true;

      if (opt.show || opt.show === 0) {
         opt.display = false; this.previous = opt.show;
      }

      if (opt.opacity) this.effects.opacity = 'fullOpacity';

      if (opt.width) this.effects.width = opt.fixedWidth ? 'fullWidth'
                                                         : 'offsetWidth';

      if (opt.height) this.effects.height = opt.fixedHeight ? 'fullHeight'
                                                            : 'scrollHeight';

      for (var i = 0, l = this.togglers.length; i < l; i++) {
         var toggler = this.togglers[ i ];

         if (i == 0) toggler.addClass( 'accordion_header_first' );

         this.addSection( toggler, this.elements[ i ] );
      }

      this.elements.each( function( el, i ) {
         if (opt.show === i) {
            this.fireEvent( 'active', [ this.togglers, i, el ] );
         }
         else {
            for (var fx in this.effects) el.setStyle( fx, 0 );
         }
      }, this );

      if (opt.display || opt.display === 0)
         this.display( opt.display, opt.initialDisplayFx );

      this.addEvent( 'complete',
                     this.internalChain.callChain.bind( this.internalChain ) );
   },

   addSection: function( toggler, el ) {
      toggler = document.id( toggler ); el = document.id( el );

      var test = this.togglers.contains( toggler );

      this.togglers.include( toggler ); this.elements.include( el );

      var opt       = this.options;
      var index     = this.togglers.indexOf( toggler );
      var displayer = this.display.pass( [ index, true ], this );

      toggler.addEvent( opt.trigger, displayer );
      toggler.store( 'accordion:display', displayer );
      el.setStyle( 'overflow-y', opt.fixedHeight ? 'auto' : 'hidden' );
      el.setStyle( 'overflow-x', opt.fixedWidth  ? 'auto' : 'hidden' );
      el.fullOpacity = 1;

      if (! test) { for (var fx in this.effects) el.setStyle( fx, 0 ); }

      this.internalChain.chain( function() {
         if (! opt.fixedHeight && opt.returnHeightToAuto
             && ! this.selfHidden) {
            if (this.now == index) el.setStyle( 'height', 'auto' );
         };
      }.bind( this ) );

      return this;
   },

   detach: function( toggler ) {
      var remove = function( toggler ) {
         toggler.removeEvent( this.options.trigger,
                              toggler.retrieve( 'accordion:display' ) );
      }.bind( this );

      if (! toggler) this.togglers.each( remove );
      else remove( toggler );

      return this;
   },

   display: function( index, useFx ) {
      if (! this.check( index, useFx )) return this;

      var els = this.elements, opt = this.options;

      index = (typeOf( index ) == 'element') ? els.indexOf( index )
                                             : index;
      index = index >= els.length ? els.length - 1 : index;
      useFx = useFx != null ? useFx : true;

      if (! opt.fixedHeight && opt.returnHeightToAuto) {
         var prev = this.previous > -1 ? els[ this.previous ] : false;

         if (prev && ! this.selfHidden) {
            for (var fx in this.effects) {
               prev.setStyle( fx, prev[ this.effects[ fx ] ] );
            }
         }
      }

      if (this.timer && opt.wait) return this;

      this.previous = this.now != undefined ? this.now : -1;
      this.now      = index;

      var obj = this._element_iterator( function( el, i, hide ) {
         this.fireEvent( hide ? 'background' : 'active',
                         [ this.togglers, i, el ] );
      }.bind( this ) );

      return useFx ? this.start( obj ) : this.set( obj );
   },

   _element_iterator: function( f ) {
      var obj = {}, opt = this.options;

      this.elements.each( function( el, i ) {
         var hide = false; obj[ i ] = {};

         if (i != this.now) { hide = true }
         else if (opt.alwaysHide && ((el.offsetHeight > 0 && opt.height)
                                   || el.offsetWidth  > 0 && opt.width)) {
            hide = this.selfHidden = true;
         }

         f( el, i, hide );

         for (var fx in this.effects)
            obj[ i ][ fx ] = hide ? 0 : el[ this.effects[ fx ] ];
      }, this );

      return obj;
   },

   removeSection: function( toggler, displayIndex ) {
      var index   = this.togglers.indexOf( toggler );
      var el      = this.elements[ index ];
      var remover = function() {
         this.togglers.erase( toggler );
         this.elements.erase( el );
         this.detach( toggler );
      }.bind( this );

      if (this.now == index || displayIndex != null){
         this.display( displayIndex != null ? displayIndex
                       : (index - 1 >= 0 ? index - 1 : 0) ).chain( remover );
      }
      else { remover() }

      return this;
   },

   resize: function() {
      var opt    = this.options;
      var height = typeOf( opt.fixedHeight ) == 'function'
                 ? opt.fixedHeight.call() : opt.fixedHeight;
      var width  = typeOf( opt.fixedWidth  ) == 'function'
                 ? opt.fixedWidth.call()  : opt.fixedWidth;
      var obj    = this._element_iterator( function( el, i, hide ) {
         if (height) el.fullHeight = height;
         if (width)  el.fullWidth  = width;
      }.bind( this ) );

      this.set( obj );
   }
} );

var GroupMember = new Class( {
   Implements: [ Options ],

   options: { selector: 'select.groupmembers' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      $( el.id + '_add' ).addEvent( 'click', function( ev ) {
         ev.stop(); this.addItem( el.id );
      }.bind( this ) );

      $( el.id + '_remove' ).addEvent( 'click', function( ev ) {
         ev.stop(); this.removeItem( el.id );
      }.bind( this ) );
   },

   addItem: function( id ) {
      var all = $( id ), members = $( id + '_current' );

      for (var i = all.length - 1; i >= 0; i--) {
         if (all.options[ i ].selected != true) continue;

         var value = all.options[ i ].value;

         if (! this.deleteHidden( id + '_deleted', value )) {
            var name = all.name.replace( /^_/g, '' ) + '_added';

            new Element( 'input', {
               name: name, type: 'hidden', value: value
            } ).inject( members, 'after' );
         }

         members.options[ members.length ] = all.options[ i ];
         // This suddenly started happening, weird but works after v0.1.657
         // all.options[ i ] = null;
      }
   },

   deleteHidden: function( id, value ) {
      return $$( 'input[name=' + id + ']' ).some( function( el ) {
         if (el.type == 'hidden' && el.value == value) {
            el.destroy(); return true;
         }

         return false;
      } );
   },

   removeItem: function( id ) {
      var all = $( id ), members = $( id + '_current' );

      for (var i = members.length - 1; i >= 0; i--) {
         if (members.options[ i ].selected != true) continue;

         var value = members.options[ i ].value;

         if (! this.deleteHidden( id + '_added', value )) {
            var name = all.name.replace( /^_/g, '' )+ '_deleted' ;

            new Element( 'input', {
               name: name, type: 'hidden', value: value
            } ).inject( members, 'after' );
         }

         all.options[ all.length ] = members.options[ i ];
         // This suddenly started happening, weird but works after v0.1.657
         // members.options[ i ] = null;
      }
   }
} );

var LinkFader = new Class( {
   Implements: [ Options ],

   options    : {
      fc      : 'ff0000', // Fade to colour
      inBy    : 6,        // Fade in colour inc/dec by
      outBy   : 6,        // Fade out colour inc/dec by
      selector: '.fade',  // Class name matching links to fade
      speed   : 20        // Millisecs between colour changes
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      el.addEvent( 'mouseover', this.startFade.bind( this, el ) );
      el.addEvent( 'mouseout',  this.clearFade.bind( this, el ) );
   },

   clearFade: function( el ) {
      if (el.timer) clearInterval( el.timer );

      el.timer = this.fade.periodical( this.options.speed, this, [ el, 0 ] );
   },

   currentColour: function( el ) {
      var cc = el.getStyle( 'color' ), temp = '';

      if (cc.length == 4 && cc.substring( 0, 1 ) == '#') {
         for (var i = 0; i < 3; i++) {
            temp += cc.substring( i + 1, i + 2 ) + cc.substring( i + 1, i + 2);
         }

         cc = temp;
      }
      else if (cc.indexOf('rgb') != -1) { cc = cc.rgbToHex().substring(1, 7) }
      else if (cc.length == 7)          { cc = cc.substring( 1, 7 ) }
      else                              { cc = this.options.fc }

      return cc;
   },

   fade: function( el, d ) {
      var cc = this.currentColour( el ).hexToRgb( true );
      var tc = (d == 1)  ? this.options.fc.hexToRgb( true )
             : el.colour ? el.colour.hexToRgb( true )
                         : [ 0, 0, 0 ];

      if (tc[ 0 ] == cc[ 0 ] && tc[ 1 ] == cc[ 1 ] && tc[ 2 ] == cc[ 2 ]) {
         clearInterval( el.timer ); el.timer = null; return;
      }

      el.setStyle( 'color', this.nextColour( tc, cc, d ) );
   },

   nextColour: function( tc, cc, d ) {
      var change = (d == 1) ? this.options.inBy : this.options.outBy;
      var colour;

      for (var i = 0; i < 3; i++) {
         var diff, nc = cc[ i ];

         if (! colour) colour = 'rgb(';
         else colour += ',';

         if (tc[ i ]-cc[ i ] > 0) { diff   = tc[ i ] - cc[ i ] }
         else                     { diff   = cc[ i ] - tc[ i ] }
         if (diff  < change)      { change = diff }
         if (cc[ i ] > tc[ i ])   { nc     = cc[ i ] - change }
         if (cc[ i ] < tc[ i ])   { nc     = cc[ i ] + change }
         if (nc    < 0)           { nc     = 0 }
         if (nc    > 255)         { nc     = 255 }

         colour += nc;
      }

      colour += ')';
      return colour;
   },

   startFade: function( el ) {
      if (el.timer) {
         clearInterval( el.timer ); el.timer = null;

         if (el.colour) el.setStyle( 'color', el.colour.hexToRgb() );
      }

      el.colour = this.currentColour( el );
      el.timer  = this.fade.periodical( this.options.speed, this, [ el, 1 ] );
   }
} );

var LiveGrid = new Class( {
   initialize: function( tableId, url, options ) {
      this.url      = url;
      this.tableId  = tableId;
      this.options  = options = options || {};
      this.table    = $( tableId );
      this.metaData = new LiveGridMetaData( options );
      this.buffer   = new LiveGridBuffer( this.metaData );

      this.lastDisplayedStartPos = -1;
      this.timeoutHander         = null;
      this.additionalParms       = options.requestParameters || {};
      this.processingRequest     = null;
      this.unprocessedRequest    = null;

      if (options.prefetchBuffer || options.prefetchOffset) {
         var offset = 0;

         if (options.prefetchOffset) {
            this.scroller.moveScroll( options.prefetchOffset );
            offset = options.prefetchOffset;
         }

         this.fetchBuffer( offset, false );
      }
      else { this.scroller = new LiveGridScroller( this ) }
   },

   ajaxUpdate: function( resp) {
      clearTimeout( this.timeoutHandler ); this.timeoutHandler = null;

      var totalrows = parseInt( resp.totalcount );

      if (totalrows) this.setTotalRows( totalrows );

      this.buffer.update( resp );

      if (this.unprocessedRequest == null)
         this.updateContent( this.processingRequest.requestOffset );

      this.processingRequest = null;

      if (! this.scroller) {
         this.scroller = new LiveGridScroller( this );

         if (this.options.onFirstContent) this.options.onFirstContent( this );
      }

      if (this.options.onComplete) this.options.onComplete( this );

      this.processQueuedRequest();
      return;
   },

   fetchBuffer: function( offset, sequence_buffers ) {
      var page, page_size;

      if (this.processingRequest) {
         this.unprocessedRequest = new LiveGridRequest( offset );
         return;
      }

      this.processingRequest = new LiveGridRequest( offset );

      if (! this.ajaxRequest) {
         var options = {}; Object.extend( options, this.options );

         options.onSuccess = this.ajaxUpdate.bind( this );
         options.url       = this.url;
         this.ajaxRequest  = new Request.JSON( options );
      }

      page_size = this.metaData.getBufferSize() * this.metaData.getPageSize();
      page      = Math.floor( offset / page_size );

      if (sequence_buffers)
         page  += offset - page * page_size > page_size / 2 ? 1 : -1;

      if (page < 0) page = 0;

      var callParms = { 'id'       : this.tableId,
                        'page'     : page,
                        'page_size': page_size,
                        'button'   : this.options.button };

      Object.merge( callParms, this.additionalParms );
      this.ajaxRequest.get( callParms );
      this.timeoutHandler = setTimeout( this.handleTimedOut.bind(this), 10000);
      return;
   },

   handleTimedOut: function() {
      //server did not respond in n secs assume that there could have been
      //an error or something, and allow requests to be processed again...
      this.processingRequest = null;
      this.processQueuedRequest();
      return;
   },

   processQueuedRequest: function() {
      if (this.unprocessedRequest != null) {
         this.requestContentRefresh( this.unprocessedRequest.requestOffset );
         this.unprocessedRequest = null
      }

      return;
   },

   replaceCellContents: function( buffer, start ) {
      if (start == this.lastDisplayedStartPos) return;

      var opt = this.options, tbody = this.table.getElements( 'tbody' )[ 0 ];

      if (opt.beforeReplace) opt.beforeReplace();

      tbody.set( 'html', buffer.getRows( start ).join( '' ) );
      this.lastDisplayedStartPos = start

      if (opt.afterReplace) opt.afterReplace();

      return;
   },

   requestContentRefresh: function( offset ) {
      if ( this.buffer.isFullyInRange( offset ) ) {
         this.updateContent( offset );

         if (this.buffer.needsMorePages( offset ))
            this.fetchBuffer( offset, true );
      }
      else if (this.buffer.isClose( offset )) {
         this.fetchBuffer( offset, true );
      }
      else { this.fetchBuffer( offset, false ) }

      return;
   },

   setRequestParams: function( params ) {
      this.additionalParms = params;
      return;
   },

   setTotalRows: function( newTotalRows ) {
      this.metaData.setTotalRows( newTotalRows );
      this.scroller.updateSize();
      return;
   },

   updateContent: function( offset ) {
      return this.replaceCellContents( this.buffer, offset );
   }
} );

var LiveGridBuffer = new Class( {
   initialize: function( metaData ) {
      this.start    = 0;
      this.size     = 0;
      this.metaData = metaData;
      this.rows     = [];
   },

   getRows: function( start ) {
      return this.rows.slice( start, start + this.metaData.getPageSize() );
   },

   isClose: function( start ) {
      return this.rows[start] || this.rows[start + this.metaData.getPageSize()];
   },

   isFullyInRange: function( start ) {
      return this.rows[start] && this.rows[start + this.metaData.getPageSize()];
   },

   needsMorePages: function( start ) {
      return this.needsPrevPage( start ) || this.needsNextPage( start );
   },

   needsNextPage: function( start ) {
      return ! this.rows[ start + 2 * this.metaData.getPageSize() ];
   },

   needsPrevPage: function( start ) {
      return ! this.rows[ start - this.metaData.getPageSize() ];
   },

   update: function( resp ) {
      this.start = parseInt( resp.offset ); this.size = parseInt( resp.count );

      for (var i = 0; i < this.size; i++) {
         this.rows[ this.start + i ] = resp.fields[ i ].content;
      }

      if (resp.script) Browser.exec( resp.script );
   }
} );

var LiveGridMetaData = new Class( {
   initialize: function( options ) {
      this.bufferSize   = options.bufferSize   || 7;
      this.onscroll     = options.onScroll     || null;
      this.onscrollidle = options.onScrollidle || null;
      this.pageSize     = options.pageSize     || 10;
      this.totalRows    = options.totalRows    || 0;
   },

   getBufferSize: function()    { return this.bufferSize },

   getPageSize:   function()    { return this.pageSize },

   getTotalRows:  function()    { return this.totalRows },

   setTotalRows:  function( n ) { this.totalRows = n }
} );

var LiveGridRequest = new Class( {
   initialize: function( requestOffset, options ) {
      this.requestOffset = requestOffset;
   }
} );

var LiveGridScroller = new Class( {
   initialize: function( liveGrid ) {
      this.liveGrid      = liveGrid;
      this.metaData      = liveGrid.metaData;
      this.scrollTimeout = null;
      this.lastScrollPos = 0;
      this.createScrollBar();
   },

   adjustScrollTop: function() {
      var sd = this.scrollerDiv, rem = sd.scrollTop % this.lineHeight;

      this.unplug();

      if (rem != 0)
         sd.scrollTop +=
            (this.lastScrollPos < sd.scrollTop ? this.lineHeight : 0) - rem;

      this.lastScrollPos = sd.scrollTop;
      this.plugin();
      return;
   },

   createScrollBar: function() {
      var table         = this.liveGrid.table;
      var visibleHeight = table.offsetHeight;
      var pageSize      = this.metaData.getPageSize();
      var lineHeight    = parseInt( 0.5 + visibleHeight / (pageSize + 1) );
      var height        = this.metaData.getTotalRows() * lineHeight;

      this.lineHeight = lineHeight; visibleHeight -= lineHeight;
      this.heightDiv    = new Element( 'div', {
         styles: { height: parseInt( height ) + 'px', width: '1px' } } );
      this.scrollerDiv  = new Element( 'div', {
         class : 'grid_scrollBar', styles: { height: visibleHeight + 'px' } } );
      this.scrollerDiv.appendChild( this.heightDiv );
      this.scrollerDiv.inject( table.parentNode, 'after' );
      this.plugin();

      table.addEvent( 'mousewheel', function( ev ) {
         ev.stop();
         this.scrollerDiv.scrollTop
            += (ev.wheel < 0 ? 1 : -1) * this.lineHeight;
         this.handleScroll( true );
      }.bind( this ) );

      return;
   },

   handleScroll: function( skiptimeout ) {
      if (this.scrollTimeout) {
         clearTimeout( this.scrollTimeout ); this.scrollTimeout = null;
      }

      if (this.metaData.onscroll) {
         var contentOffset = parseInt( this.metaData.getTotalRows()
                * this.scrollerDiv.scrollTop / this.heightDiv.offsetHeight );

         this.metaData.onscroll( contentOffset, this.metaData );
      }

      if (skiptimeout == true) this.scrollIdle();
      else this.scrollTimeout = setTimeout( this.scrollIdle.bind( this ), 100 );

      return;
   },

   isUnPlugged: function() { return this.scrollerDiv.onscroll == null },

   moveScroll: function( rowOffset ) {
      this.scrollerDiv.scrollTop = this.heightDiv.offsetHeight
                                     * rowOffset / this.metaData.getTotalRows();
      return;
   },

   plugin: function() {
      this.scrollerDiv.onscroll = this.handleScroll.bind( this ); return;
   },

   scrollIdle: function() {
      if (this.scrollTimeout) {
         clearTimeout( this.scrollTimeout ); this.scrollTimeout = null;
      }

      //this.adjustScrollTop();
      var contentOffset = parseInt( this.metaData.getTotalRows()
             * this.scrollerDiv.scrollTop / this.heightDiv.offsetHeight );

      this.liveGrid.requestContentRefresh( contentOffset );

      if (this.metaData.onscrollidle) this.metaData.onscrollidle();

      return;
   },

   unplug: function() { this.scrollerDiv.onscroll = null; return },

   updateSize: function() {
      this.heightDiv.style.height = parseInt(
         this.lineHeight * this.metaData.getTotalRows() ) + 'px';
      return;
   }
} );

var LiveGrids = new Class( {
   Implements: [ Options ],

   options       : {
      button     : null,
      config_attr: 'anchors',
      gridSize   : 10,
      gridToggle : true,
      iconClasses: [ 'a', 'b' ],
      onComplete : false,
      selector   : '.live_grid',
      url        : null
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var opt = this.mergeOptions( el.id ), event = opt.event || 'click';

      if (event == 'load') { this.requestGrid( el ); return; }

      el.addEvent( event, function( ev ) {
         ev.stop(); this.requestGrid( el ) }.bind( this ) );
   },

   requestGrid: function( el ) {
      var a = el.id.split( '_' ), key = a[ 0 ], id = a[ 1 ], disp, icon;

      if (! key || ! id || ! (disp = $( el.id + 'Disp' ))) return;

      var opt = this.mergeOptions( el.id );

      if (opt.gridToggle && disp.isDisplayed()) {
         disp.hide();

         if (icon = $( el.id + 'Icon' )) icon.className = opt.iconClasses[ 0 ];

         this.gridKey = null; this.gridId = null; this.gridObj = null;
         return;
      }

      if (this.gridKey && this.gridId) {
         var keyid = this.gridKey + '_' + this.gridId, prev;

         if (prev = $( keyid + 'Disp' )) prev.hide();
         if (prev = $( keyid + 'Icon' )) prev.className = opt.iconClasses[ 0 ];

         this.gridKey = null; this.gridId = null; this.gridObj = null;
      }

      disp.show(); this.gridKey = key; this.gridId = id;

      if (icon = $( el.id + 'Icon' )) icon.className = opt.iconClasses[ 1 ];

      new Request.JSON( {
         onSuccess       : this._createGrid.bind( this ),
         url             : opt.url + key +  '_grid_table' } ).get( {
            'field_value': opt.fieldValue,
            'id'         : id,
            'page_size'  : opt.gridSize,
            'button'     : opt.button } );
   },

   _createGrid: function( resp ) {
      var keyid  = this.gridKey + '_' + this.gridId;
      var opt    = this.mergeOptions( keyid );
      var count  = parseInt( resp.totalcount );
      var value  = resp.field_value || '';
      var url    = opt.url + this.gridKey + '_grid_rows';
      var before = function() { this.submit.detach() }.bind( this.context );
      var after  = function() { this.rebuild()       }.bind( this.context );
      var opts   = {
         button           : opt.button,
         bufferSize       : 7,
         gridSize         : opt.gridSize,
         prefetchBuffer   : true,
         beforeReplace    : before,
         afterReplace     : after,
         onScroll         : this._updateHeader.bind( this ),
         onFirstContent   : this._updateHeader.bind( this, 0 ),
         requestParameters: { 'field_value': value },
         totalRows        : count };

      var html = ''; resp.fields.each( function( field ) {
         html += field.content;
      } );

      $( keyid + 'Disp' ).set( 'html', html );

      this.gridObj = new LiveGrid( keyid + '_grid', url, opts );

      if (opt.onComplete) opt.onComplete.call( this.context );
   },

   _updateHeader: function( offset ) {
      var meta_data = this.gridObj.metaData;
      var keyid     = this.gridKey + '_' + this.gridId;
      var header    = $( keyid + '_header' );
      var text      = 'Listing ' + (offset + 1) + ' - ';
          text     += (offset + meta_data.getPageSize());
          text     += ' of ' + meta_data.getTotalRows();

      header.set( 'html', text );

      var sort_info; if (this.gridObj.sortCol) {
         sort_info  = '&data_grid_sort_col=' + this.gridObj.sortCol;
         sort_info += '&data_grid_sort_dir=' + this.gridObj.sortDir;
      }
      else sort_info = '';

      var url = this.options.url + this.gridKey + '_grid_page';

      header.href = url + '?data_grid_index=' + offset + sort_info;
   }
} );

var LoadMore = new Class( {
   attach: function( el ) {
      var cfg; if (! (cfg = this.config[ el.id ])) return;

      var event = cfg.event || 'click';

      if (event == 'load') {
         this[ cfg.method ].apply( this, cfg.args ); return;
      }

      el.addEvent( event, function( ev ) {
         ev.stop(); this[ cfg.method ].apply( this, cfg.args ) }.bind( this ) );
   },

   request: function( url, id, val, on_complete ) {
      if (on_complete) this.onComplete = on_complete;

      if (url.substring( 0, 4 ) != 'http') url = this.options.url + url;

      new Request.JSON( { onSuccess: this._response.bind( this ), url: url } )
                  .get( { 'id': id, 'val': val } );
   },

   _response: function( resp ) {
      var html = ''; resp.fields.each( function( field ) {
         html += field.content;
      } );

      $( resp.id ).set( 'html', html );

      if (resp.script) Browser.exec( resp.script );

      if (this.onComplete) this.onComplete.call( this.context, resp );
   }
} );

/* Formally jquery-notification 1.1
 * Dual licensed under the MIT or GPL Version 2 licenses.
 * http://www.opensource.org/licenses/mit-license.php
 * http://www.gnu.org/licenses/gpl-2.0.html
 */

var NoticeBoard = new Class( {
   Implements: Options,

   options      : {
      canClose  : true,
      click     : function() {},
      content   : '',
      fadeIn    : 400,
      fadeOut   : 600,
      hideDelay : 7000,
      horizontal: 'right',
      limit     : 3,
      noshow    : false,
      queue     : true,
      slideUp   : 600,
      vertical  : 'bottom'
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); var opt = this.options;

      var klass = 'notice-board nb-' + opt.vertical + ' nb-' + opt.horizontal;

      this.board = $$( '.' + klass )[ 0 ];

      // Create notification container
      if (! this.board) this.board =
         new Element( 'div', { class: klass } ).inject( $( 'body' ) );

      this.queue = [];
   },

   create: function( content, options ) { // Create new notification and show
      var opt  = this.mergeOptions( options );
      var qlen = this.board.getChildren( '.notice:not(.hiding)' ).length;

      if (opt.limit && qlen >= opt.limit) { // Limit reached
         if (opt.queue) this.queue.push( [ content, opt ] );
         return;
      }

      var el = new Element( 'div', { class: 'notice' } ).set( 'html', content );

      if (opt.canClose) {
         new Element( 'div', { class: 'close_icon' } ).inject( el, 'top' );
      }

      el.store( 'notice:options', opt ); this.attach( el );

      if (!opt.noshow) this.show( el );

      return el;
   },

   attach: function( el ) {
      var opt = el.retrieve( 'notice:options' ) || this.options;

      el.addEvents( {
         click: function( ev ) {
            ev.stop(); opt.click.call( this, el ) }.bind( this ),

         mouseenter: function( ev ) { // Avoid hide when hover
            ev.stop(); el.addClass( 'hover' );

            if (el.hasClass( 'hiding' )) {
               el.get( 'slide' ).pause(); // Recover
               el.get( 'tween' ).pause();
               el.set( 'tween', { duration: opt.fadeIn, property: 'opacity' } );
               el.tween( 1 );
               el.get( 'slide' ).show();
               el.removeClass( 'hiding' );
               el.addClass( 'pending' );
            }
         },

         mouseleave: function( ev ) { // Hide was pending
            if (el.hasClass( 'pending' )) this.hide( el );
            el.removeClass( 'hover' );
         }.bind( this )
      } );

      var icon; if (icon = el.getChildren( '.close_icon' )[ 0 ]) {
         icon.addEvent( 'click', function( ev ) { // Close button
            ev.stop(); this.hide( el ) }.bind( this ) );
      }
   },

   show: function( el ) { // Append to board and show
      var opt    = el.retrieve( 'notice:options' ) || this.options;
      var fadein = opt.fadeIn;

      el.inject( this.board, opt.vertical == 'top' ? 'bottom' : 'top' );
      el.set( 'tween', { duration: fadein, property: 'opacity' } ).tween( 1 );

      if (!opt.hideDelay) return;

      el.noticeTimer = function() { // Hide timer
         el.hasClass( 'hover' ) ? el.addClass( 'pending' ) : this.hide( el );
      }.delay( opt.hideDelay, this );
   },

   hide: function( el ) {
      var opt = el.retrieve( 'notice:options' ) || this.options;

      el.addClass( 'hiding' );

      el.set( 'tween', { duration: opt.fadeOut, onComplete: function() {
         var q; if (q = this.queue.shift()) this.create( q[ 0 ], q[ 1 ] );
      }.bind( this ), property: 'opacity' } ).tween( 0 );

      el.set( 'slide', { duration: opt.slideUp, onComplete: function() {
         el.getParent().destroy() } } ).slide( 'out' );
   }
} );

var PersistantStyleSheet = new Class( {
   initialize: function( options ) {
      var opt = options || {}; this.cookies = opt.cookies || function() {};

      this.setActive( this.cookies.get( 'stylesheet' ) || this.getPreferred() );

      window.addEvent( 'unload', function( ev ) {
         this.cookies.set( 'stylesheet', this.getActive() ) }.bind( this ) );
   },

   getActive: function() {
      var active;

      $$( 'link' ).some( function( el ) {
         return (el.rel.indexOf( 'style' ) != -1
                 && ! el.disabled && (active = el.title)) ? true : false;
      } );

      return active;
   },

   getPreferred: function() {
      var preferred;

      $$( 'link' ).some( function( el ) {
         return (el.rel.indexOf( 'style' ) != -1
                 && el.rel.indexOf( 'alt' ) == -1 && (preferred = el.title))
              ? true : false;
      } );

      return preferred;
   },

   setActive: function( active ) {
      $$( 'link' ).each( function( el ) {
         if (el.rel.indexOf( 'style' ) != -1 && el.title)
            el.disabled = el.title != active ? true : false;
      } );
   }
} );

var Replacements = new Class( {
   Implements: [ Options ],

   options              : {
      textarea_container: 'expanding_area',
      textarea_preformat: 'expanding_spacer',
      config_attr       : 'inputs',
      event             : 'click',
      method            : 'toggle',
      selector          : [ '.autosize', 'input[type=checkbox]',
                            'input[type=password].reveal',
                            'input[type=radio]' ],
      suffix            : '_replacement'
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   build: function() {
      this.options.selector.each( function( selector ) {
         $$( selector ).each( function( el, index ) {
            if (! el.id) { $uid( el ); el.id = el.type + el.uid }

            if (! this.collection.contains( el.id )) {
               this.collection.include( el.id ); this.createMarkup( el, index );
            }

            this.attach( el );
         }, this );
      }, this );
   },

   createMarkup: function( el, index ) {
      var opt = this.mergeOptions( el.id ), new_id = el.id + opt.suffix;

      if (el.type == 'checkbox' || el.type == 'radio') {
         el.setStyles( { position: 'absolute', left: '-9999px' } );
         new Element( 'span', {
            'class': 'checkbox' + (el.checked ? ' checked' : ''),
            id     : new_id,
            name   : el.name
         } ).inject( el, 'after' );
         return;
      }

      if (el.type == 'textarea') {
         var div  = new Element( 'div',  { 'class': opt.textarea_container } );
         var pre  = new Element( 'pre',  { 'class': opt.textarea_preformat } );
         var span = new Element( 'span', { id: new_id } );

         div.inject( el, 'before' ); pre.inject( div ); div.grab( el );
         span.inject( pre ); new Element( 'br' ).inject( pre );
         span.set( 'text', el.value );
      }

      return;
   },

   attach: function( el ) {
      var opt = this.mergeOptions( el.id );

      if (el.type == 'textarea') {
         this._add_events( el, el, 'keyup', 'set_text' );
      }
      else {
         var replacement = $( el.id + opt.suffix ) || el;

         this._add_events( el, replacement, opt.event, opt.method );
      }
   },

   _add_events: function( el, replacement, events, methods ) {
      methods = Array.from( methods );

      Array.from( events ).each( function( event, index ) {
         var handler, key = 'event:' + event;

         if (! (handler = replacement.retrieve( key ))) {
            handler = function( ev ) {
               ev.stop(); this[ methods[ index ] ].call( this, el );
            }.bind( this );
            replacement.store( key, handler );
         }

         replacement.addEvent( event, handler );
      }, this );
   },

   hide_password: function( el ) {
      el.setProperty( 'type', 'password' );
   },

   set_text: function( el ) {
      var opt = this.mergeOptions( el.id );

      $( el.id + opt.suffix ).set( 'text', el.value );
   },

   show_password: function( el ) {
      el.setProperty( 'type', 'text' );
   },

   toggle: function( el ) {
      var opt         = this.mergeOptions( el.id );
      var replacement = $( el.id + opt.suffix );

      if (el.getProperty( 'disabled' )) return;

      replacement.toggleClass( 'checked' );

      if (replacement.hasClass( 'checked' )) {
         el.setProperty( 'checked', 'checked' );

         if (el.type == 'radio') {
            this.collection.each( function( box_id ) {
               var box = $( box_id ), replacement = $( box_id + opt.suffix );

               if (replacement && box_id != el.id && box.name == el.name
                   && replacement.hasClass( 'checked' )) {
                  replacement.removeClass ( 'checked' );
                  box.removeProperty( 'checked' );
               }
            }, this );
         }
      }
      else el.removeProperty( 'checked' );
   }
} );

var RotateList = new Class( {
   Implements: [ Options ],

   options       : {
      config_attr: 'lists',
      direction  : 'up',      // Direction in which to scroll
      duration   : 1000,      // Millisecs for each transition
      nitems     : 3,         // Number of items to display
      selector   : '.rotate', // Class name matching lists to rotate
      speed      : 5000,      // Millisecs between rotations
      transition : 'linear',  // Transition style
      zero_style : { height : 0, marginBottom : 0, marginTop : 0,
                     opacity: 0, paddingBottom: 0, paddingTop: 0 }
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var opt = this.mergeOptions( el.id );

      var first; if (! (first = el.getElement( 'li' ))) return;

      el.setStyle( 'height', (opt.nitems * first.getHeight()) + 'px' );
      el.timer = opt.direction == 'up'
               ? this.rotateListUp.periodical  ( opt.speed, this, [ el, opt ] )
               : this.rotateListDown.periodical( opt.speed, this, [ el, opt ] );
   },

   rotateListDown: function( el, opt ) {
      var first    = el.getElement ( 'li' );
      var last     = el.getElements( 'li' ).getLast();
      var styles   = last.getStyles( 'height',        'marginBottom',
                                     'marginTop',     'opacity',
                                     'paddingBottom', 'paddingTop' );
      var disposed = last.dispose(); disposed.setStyles( opt.zero_style );
      var inserted = el.insertBefore( disposed, first );

      inserted.set  ( 'morph', { duration  : opt.duration,
                                 transition: opt.transition } );
      inserted.morph( styles );
   },

   rotateListUp: function( el, opt ) {
      var first  = el.getElement( 'li' );
      var clone  = first.clone();
      var rotate = function() {
          this.destroy(); el.appendChild( clone ) }.bind( first );

      first.set  ( 'morph', { onComplete: rotate,
                              duration  : opt.duration,
                              transition: opt.transition } );
      first.morph( opt.zero_style );
   }
} );

/* Adds markers to the page scrollbar to indicate the location of key
   elements on the page. Inspired by a simmilar mechanism used on MSNBC.com
   Was rewritten from from a Scriptaculous extension which was
   Copyright (c) 2010, Jarvis Badgley - chiper[at]chipersoft[dot]com
   Usage:

   var sp = new ScrollPins( { config: { Pintray: { pins: {
      // anchor elements are referenced via css selectors
      'hr'          : { image: 'pins/pin_gray.png' },
      // document order doesn't matter, only the order in the object
      'div'         : { image: 'pins/pin_empty.png' },
      // this line overwrites the pin created by 'div'
      'div.red'     : { image:'pins/pin_red.png' },
      // use a css selector to identify the pin contents
      'div.orange'  : { selector:'button' },
      // use an element id to get the pin contents
      'div.blue'    : { element:'bluepin' },
      // or add the element directly by variable
      //If the element was already in use as a pin, it gets cloned
      'div.lavender': { element:document.body.getChildren()[0] },
      //remove pins created by higher up in the array
      'div.eggplant': null
   } } } } ); */

var ScrollPins = new Class( {
   Implements: [ Events, Options ],

   options             : {
      config_attr      : 'scrollPins',
      scrollBarWidth   : 19,
      scrollDuration   : 500,
      scrollMargin     : 0,
      selector         : '.pintray',
      tag              : 'li',
      target           : window,
      trayPadding      : 10,
      trayPaddingBottom: undefined,
      trayPaddingTop   : undefined
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();

      this.fireEvent( 'initialize' );
   },

   build: function() {
      var opt = this.options;

      if (opt.selector) $$( opt.selector ).each( function( pintray ) {
         var cfg = this.mergeOptions( pintray.id );

         if (typeOf( cfg.target ) != 'window') cfg.target = $( cfg.target );

         pintray.cfg = cfg; pintray.pins = pintray.pins || [];

         Object.each( cfg.pins || {}, function( value, key ) {
            this.createMarkup( pintray, key, value );
         }, this );

         this.resize( pintray );

         pintray.pins.each( function( el ) { this.attach( el ) }, this );

         if (! this.collection.contains( pintray )) {
            cfg.target.addEvent( 'resize', this.resize.bind( this, pintray ) );
            this.collection.include( pintray );
         }
      }, this );

      this.fireEvent( 'build' );
   },

   attach: function( el ) {
      if (el.attached) return; el.attached = true;

      var cfg      = el.pin.pintray.cfg,
          margin   = el.getStyle( 'margin-top' ).toInt(),
          position = el.getPosition( cfg.target ),
          padding  = typeOf( cfg.target ) != 'window'
                   ? cfg.target.getStyle( 'padding-top' ).toInt() : 0;

      if (this.debug)
         this.log( 'ScrollPins attach: ' + position.y + ' ' + margin
                   + ' ' + padding );

      el.pin.addEvent( 'click', function( ev ) {
         ev.stop();
         new Fx.Scroll( cfg.target, { duration: cfg.scrollDuration } )
                .start( position.x, position.y - margin - padding );
      } );

      this.fireEvent( 'attach', [ el ] );
   },

   createMarkup: function( pintray, key, value ) {
      // key   contains a selector for the node we want the pin to point at
      // value contains an object indicating what the pin should be made of
      var template = value ? this._getTemplate( value ) : false;

      if (template) template.pin_used = template.pin_used || 0;

      $$( key ).each( function( el ) {
         if (el.pin) el.pin.destroy(); if (! template) return;

         var cfg    = pintray.cfg,
             markup = template.pin_used++ ? template.clone( true )
                                          : template.show();

         if (cfg.title) markup.title = cfg.title.call( this, el );

         el.pin = new Element( cfg.tag ).inject( pintray );

         el.pin.grab( el.pin.markup = markup ); el.pin.pintray = pintray;

         pintray.pins.include( el );
      }, this );
   },

   _getTemplate: function( obj ) {
      return obj.icon     ? new Element( 'span', { class: obj.icon  } )
           : obj.image    ? new Element( 'img',  { src  : obj.image } )
           : obj.selector ? $$( obj.selector )[ 0 ]
           : obj.element  ?  $( obj.element  )
                          : false;
   },

   resize: function( pintray ) {
      this._resizePintray( pintray );

      pintray.pins.each( function( el ) {
         var cfg         = el.pin.pintray.cfg,
             padding_bot = [ cfg.trayPaddingBottom, cfg.trayPadding ].pick(),
             padding_top = [ cfg.trayPaddingTop,    cfg.trayPadding ].pick(),
             real_height = cfg.target.getScrollHeight(),
             view_height = cfg.target.getHeight(),
             pin_height  = el.pin.getHeight(),
             offset      = el.getPosition( cfg.target ).y,
             maximum     = view_height - padding_top - pin_height - padding_bot,
             pin_top     = padding_top + (offset * maximum / real_height);

         if (this.debug)
            this.log( 'ScrollPins resize: ' + padding_bot + ' '
                    + padding_top + ' ' + real_height + ' ' + view_height + ' '
                    + pin_height  + ' ' + offset      + ' ' + maximum     + ' '
                    + pin_top );

         el.isVisible() && el.parentNode ? el.pin.show() : el.pin.hide();
         pin_top = Math.max( Math.min( pin_top, maximum ), padding_top );
         el.pin.setStyle( 'top', pin_top.round() + 'px' );
      }, this );
   },

   _resizePintray: function( pintray ) {
      var cfg = pintray.cfg, target = cfg.target;

      if (typeOf( target ) == 'window') return;

      var margin_right = target.getStyle( 'margin-right' ).toInt(),
          right        = target.getStyle( 'right' ).toInt() + margin_right,
          margin_top   = target.getStyle( 'margin-top' ).toInt(),
          top          = target.getStyle( 'top' ).toInt() + margin_top;

      pintray.setStyles( { right: (cfg.scrollBarWidth + right) + 'px',
                           top  : top + 'px' } );
   }
} );

var ServerUtils = new Class( {
   Implements: [ Options, LoadMore ],

   options: { config_attr: 'server', selector: '.server', url: null },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   checkField: function( id, form, domain ) {
      var url = 'check_field';

      if (form && domain) url += '?domain=' + domain + '&form=' + form;

      this.request( url, id, $( id ).value, function( resp ) {
         $( resp.id ).className = resp.class_name ? resp.class_name : 'hidden';
      }.bind( this ) );
   },

   requestIfVisible: function( action, id, val, on_complete ) {
      if ($( id ).isVisible()) this.request( action, id, val, on_complete );
   }
} );

var Sidebar = new Class( {
   Implements: [ Options ],

   options                : {
      config_attr         : 'sidebars',
      accordion           : 'accordionDiv',
      panel               : 0,
      panelClass          : '.accordion_panel',
      prefix              : 'sidebar',
      togglerClass        : '.accordion_header',
      togglerHeight       : 30,
      togglersMarginHeight: 12,
      togglersMinMargin   : 5,
      width               : 38
   },

   initialize: function( options ) {
      this.config  = options.config; delete options[ 'config'  ];
      this.context = options.context || {}; delete options[ 'context' ];

      this.setOptions( options ); var opt = this.options, prefix = opt.prefix;

      if (!this.config && this.context.config && opt.config_attr)
         this.config = this.context.config[ opt.config_attr ];

      if (!this.config && opt.config_attr)
         this.config = this.context.config[ opt.config_attr ];

      if (!this.config) this.config = {};

      var sb; if (! (sb = this.el = $( prefix + 'Disp' ))) return;

      var cookies  = this.context.cookies || {};
      var sb_state = cookies.get( prefix ) ? true : false;
      var sb_panel = cookies.get( prefix + 'Panel' ) || opt.panel;
      var sb_width = cookies.get( prefix + 'Width' )
                  || parseInt( opt.width * window.getWidth() / 100 );

      cookies.set( prefix + 'Width', sb_width );

      // Setup the slide in/out effect
      this.slider = new Fx.Slide( prefix + 'Container', {
         'mode'    : 'horizontal',
         onComplete: function() {
            var sb_icon = $( prefix + 'Icon' );

            // When the effect is complete toggle the state
            if (this.cookies.get( prefix )) {
               if (sb_icon) sb_icon.className = 'pushedpin_icon';
            }
            else {
               this.resize(); if (sb_icon) sb_icon.className = 'pushpin_icon';
            }
         }.bind( this.context ),
         transition: Fx.Transitions.Circ.easeInOut
      } );

      // Setup the event handler to turn the side bar on/off
      $( prefix ).addEvent( 'click', function( ev ) {
         ev.stop(); var cookies = this.context.cookies;

         if (cookies.get( prefix )) {
            cookies.remove( prefix ); this.slider.slideOut();
            this.context.noticeBoard.create( 'Sidebar closed...' );
         }
         else {
            var panel = cookies.get( prefix + 'Panel' );

            cookies.set( prefix, 'pushedpin_icon' ); this.context.resize();
            this.accordion.display( panel, false ); this.slider.slideIn();
            this.context.noticeBoard.create( 'Sidebar opened...' );
         }
      }.bind( this ) );

      // Setup the horizontal resize grippy for the side bar
      sb.makeResizable( {
         handle   : $( prefix + 'Grippy' ),
         limit    : { x: [ 150, 450 ] },
         modifiers: { x: 'width', y: false },
         onDrag   : function() {
             var sb_width = sb.getStyle( 'width' ).toInt();

             this.context.cookies.set( prefix + 'Width',  sb_width );
             this.slider.wrapper.setStyle( 'width', sb_width + 'px' );
             this.context.resize() }.bind( this )
      } );

      var togglers  = $$( opt.togglerClass ), panels = $$( opt.panelClass );
      var getHeight = this.getHeight.pass( [ togglers ], this );

      // Create an Accordion widget in the side bar
      this.accordion = new Fx.Accordion( togglers, panels, {
         display         : sb_state ? sb_panel : -1,
         fixedHeight     : getHeight,
         initialDisplayFx: false,
         opacity         : false,
         onActive        : function( togglers, index, el ) {
            var toggler = togglers[ index ];

            toggler.swapClass( 'inactive', 'active' );
            this.context.cookies.set( prefix + 'Panel', index );

            var cfg; if (! (cfg = this.config[ toggler.id ])) return;

            if (cfg.action && cfg.name) {
               this.context.server.request( cfg.action, cfg.name,
                                            cfg.value,  cfg.onComplete );
            }
         }.bind( this ),
         onBackground    : function( togglers, index, el ) {
            togglers[ index ].swapClass( 'active', 'inactive' );
         }
      } );

      return;
   },

   getHeight: function( togglers ) {
      var opt    = this.options;
      var styles = { styles: [ 'padding', 'border', 'margin' ] };
      var size   = this.el.getComputedSize( styles );
      var height = (opt.togglerHeight * togglers.length)
                 + opt.togglersMarginHeight;
      var margin = Math.max( opt.togglersMinMargin,
                             this.el.getStyle( 'marginBottom' ).toInt() );

      return Math.max( 1, size.totalHeight - (height + margin) );
   },

   getWidth: function() {
      var sb; if (! (sb = this.el)) return 0;

      return sb.getStyle( 'width' ).toInt();
   },

   resize: function() {
      var sb; if (! (sb = this.el)) return;

      var prefix        = this.options.prefix;
      var cookies       = this.context.cookies;
      var state         = cookies.get( prefix ) ? true : false;
      var margin_bottom = this.context.getContentMarginBottom();

      if (state) { sb.show() } else { sb.hide() }

      sb.setStyle( 'marginBottom', margin_bottom + 'px' );

      // Calculate and set vertical offset for side bar grippy
      var sb_height     = sb.getHeight();
      var grippy_height = $( prefix + 'Grippy' ).getHeight();
      var offset        = Math.max( 1, Math.round( sb_height / 2 )
                                     - Math.round( grippy_height / 2 ) );

      $( prefix + 'Grippy' ).setStyle( 'marginTop', offset + 'px' );

      var sb_width = state ? cookies.get( prefix + 'Width' ) : 0;

      sb.setStyle( 'width', sb_width + 'px' );
      this.accordion.resize();
      return;
   }
} );

var Sliders = new Class( {
   Implements: [ Options ],

   options: { config_attr: 'sliders', selector: '.slider' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var cfg, slider, submit = this.context.submit;

      if (! (cfg = this.config[ el.id ])) return;

      var name       = cfg.name;       delete cfg[ 'name'       ];
      var default_v  = cfg.default_v;  delete cfg[ 'default_v'  ];
      var knob_class = cfg.knob_class; delete cfg[ 'knob_class' ];
      var knob       = el.getElement( knob_class );

      cfg = Object.append( cfg, {
         onChange: function( value ) {
            submit.setField.call( submit, name, value ) }
      } );

      new Slider( el, knob, cfg ).set( default_v );
   }
} );

/* Originally Copyright (c) 2011 Felix Gnass [fgnass at neteye dot de]
 * https://fgnass.github.com/spin.js
 * Licensed under the MIT license */

Spinner.JS = new Class( {
   Extends: Spinner,

   options       : {
      fill_args  : '0 0 1px rgba(0,0,0,.1)',
      length     : 7,
      line_width : 5,
      lines      : 12,
      opacity    : 0.25,
      prefixes   : [ 'webkit', 'Moz', 'ms', 'O' ],
      radius     : 10,
      shadow     : false,
      shadow_args: '0 0 4px black',
      speed      : 1,
      tag        : [ 'group', 'roundrect', 'fill', 'stroke' ],
      trail      : 100,
      url_vml    : 'url(#default#VML)'
   },

   hide: function( no_fx ) {
      window.clearTimeout( this.timeout );

      if (this.js_spinner && this.js_spinner.parentNode)
         this.js_spinner.parentNode.removeChild( this.js_spinner );

      this.js_spinner = undefined;
      return this.parent( no_fx );
   },

   render: function() {
      this.parent();
      this.animations = {};
      this.styleSheet = this._styleSheet();
      this.use_vml    = false;

      var opt = this.options, group = new Element( opt.tag[ 0 ] );

      this._setStyles( group, 'behavior', opt.url_vml );

      if (!this._vendor( group, 'transform' ) && group.adj) {
         this.use_vml = true;

         for (var i = 0, limit = opt.tag.length; i < limit; i++) {
            this.styleSheet.addRule( opt.tag[ i ], 'behavior:' + opt.url_vml );
         }
      }
      else this.use_css_animations = this._vendor( group, 'animation' );
   },

   show: function( no_fx ) {
      this.js_spinner = this.use_vml ? this._init_vml()
                                     : this._init_css_animations();

      this._insert( this.content, this.js_spinner, this.content.firstChild );

      if (! this.use_css_animations) this._use_js_animations();

      return this.parent( no_fx );
   },


   toggle: function() {
      return this.js_spinner == undefined ? this.show() : this.hide();
   },

   /* Private methods */

   _addAnimation: function( to, end ) {
      var name  = [ 'opacity', end, ~~(to * 100) ].join( '-' );

      if (this.animations[ name ]) return name;

      var opt = this.options, dest = '{ opacity:' + to + '}';

      for (var i = 0, limit = opt.prefixes.length; i < limit; i++) {
         try {
            var rule = '@' +
               (opt.prefixes[ i ] && '-' + opt.prefixes[ i ].toLowerCase()
                + '-' || '') + 'keyframes ' + name + '{0%{opacity:1}' +
               end + '%' + dest + 'to' + dest + '}';

            this.styleSheet.insertRule( rule, this.styleSheet.cssRules.length );
         }
         catch (err) {}
      }

      this.animations[ name ] = 1;
      return name;
   },

   _eachPair: function( args, it ) {
      for (var i = 1, limit = ~~((args.length - 1) / 2); i <= limit; i++) {
         it( args[ i * 2 - 1 ], args[ i * 2 ] );
      }
   },

   _init_css_animations: function() {
      var opt     = this.options;
      var aname   = this._addAnimation( opt.opacity, opt.trail );
      var offset  = 4 + opt.length + opt.radius + opt.line_width;
      var size    = (2 * offset) + 'px';
      var el      = new Element( 'div', { 'class': 'spinner-group' } )
         .setStyles( { 'position': 'relative',
                       'height'  : size, 'width': size } );
      var content = function( i, type ) {
         var klass  = type == 'shadow' ? 'spinner-shadow' : 'spinner-fill';
         var shadow = type == 'shadow' ? opt.shadow_args  : opt.fill_args;

         return this._setStyles
         ( new Element( 'div', { 'class': klass } ),
           'position',        'absolute',
           'width',           (opt.length + opt.line_width) + 'px',
           'height',          opt.line_width + 'px',
           'boxShadow',       shadow,
           'transformOrigin', 'left',
           'transform',       'rotate( '
              + ~~(360 / opt.lines * i) + 'deg) translate('
              + opt.radius + 'px, 0px )',
           'borderRadius',    '100em'
         );
      }.bind( this );

      for (var i = 0, limit = opt.lines; i < limit; i++) {
         var segment = this._setStyles
         ( new Element( 'div' ),
           'position',  'absolute',
           'left',      offset + 'px',
           'top',       (1 + offset + ~(opt.line_width / 2)) + 'px',
           'animation', aname + ' ' + (1 / opt.speed)
              + 's linear ' + (-1 + 1 / opt.lines * i / opt.speed)
              + 's infinite'
         );

         if (opt.shadow)
            this._insert( segment, this._setStyles( content( i, 'shadow' ),
                                                    'top', '2px' ) );

         this._insert( el, this._insert( segment, content( i, 'fill' ) ) );
      }

      return el;
   },

   _init_vml: function() {
      // VML support detected. Insert CSS rules
      var opt    = this.options;
      var r      = opt.length + opt.line_width, s = 2 * r;
      var grp    = function() {
         return this._setStyles( new Element( opt.tag[ 0 ], {
            'coordSize'  :  s + ' ' +  s,
            'coordOrigin': -r + ' ' + -r } ), 'width', s, 'height', s );
      }.bind( this );
      var g      = grp();
      var seg    = function( i, dx, filter ) {
         this._insert
         ( g,
           this._insert
           ( this._setStyles( grp(),
                              'rotation', (360 / opt.lines * i) + 'deg',
                              'left', ~~dx ),
             this._insert
             ( this._setStyles( new Element( opt.tag[ 1 ], { 'arcsize': 1 } ),
                                'width', r, 'height', opt.line_width,
                                'left', opt.radius, 'top', -opt.line_width / 2,
                                'filter', filter ),
               new Element( opt.tag[ 2 ], { 'opacity': opt.opacity } ),
               new Element( opt.tag[ 3 ], { 'opacity': 0 } )
             )
           )
         );
      }.bind( this );

      if (opt.shadow) {
         for (var i = 1, limit = opt.lines; i <= limit; i++) {
            seg( i, -2, 'progid:DXImagetransform.Microsoft.Blur(pixelradius=2,makeshadow=1,shadowopacity=.3)' );
         }
      }

      for (var i = 1, limit = opt.lines; i <= limit; i++) { seg( i ) }

      var margin = ~(opt.length + opt.radius + opt.line_width) + 'px';
      var el     = new Element( 'div', { 'class': 'spinner-group' } )
         .setStyles( { 'position': 'relative',
                       'margin'  : margin + ' 0 0 ' + margin } );

      return this._insert( el, g );
   },

   _insert: function( parent, child1, child2 ) {
      if (child2 && !child2.parentNode) this._insert( parent, child2 );

      parent.insertBefore( child1, child2 || null );
      return parent;
   },

   _opacity: function( el, i, val ) {
      if (this.use_vml) {
         var opt = this.options, l = opt.shadow && opt.lines || 0;

         el.firstChild.childNodes[ i + l ].firstChild.firstChild.opacity = val;
      }
      else el.childNodes[ i ].style.opacity = val;
   },

   _setStyles: function( el ) {
      this._eachPair( arguments, function( k, v ) {
         el.style[ this._vendor( el, k ) || k ] = v;
      }.bind( this ) );

      return el;
   },

   _styleSheet: function() {
      var sheets = document.styleSheets, style = new Element( 'style' );

      this._insert( document.getElementsByTagName( 'head' )[ 0 ], style );

      return sheets[ sheets.length - 1 ];
   },

   _use_js_animations: function() {
      // No CSS animation support, use setTimeout() instead
      var i     = 0, opt = this.options, self = this;
      var f     = 20 / opt.speed;
      var ostep = (1 - opt.opacity) / (f * opt.trail / 100);
      var astep = f / opt.lines;

      (function anim() {
         i++;

         for (var s = opt.lines; s > 0; s--) {
            var alpha = Math.max( 1 - (i + s * astep) % f * ostep,
                                  opt.opacity );

            self._opacity( self.js_spinner, opt.lines - s, alpha );
         }

         self.timeout = self.js_spinner && window.setTimeout( anim, 50 );
      } )();
   },

   _vendor: function( el, prop ) {
      // Tries various vendor prefixes and returns the first supported property
      var opt = this.options, s = el.style;

      if (s[ prop ] !== undefined) return prop;

      prop = prop.charAt( 0 ).toUpperCase() + prop.slice( 1 );

      for (var i = 0, limit = opt.prefixes.length; i < limit; i++) {
         var pp = opt.prefixes[ i ] + prop;

         if (s[ pp ] !== undefined) return pp;
      }

      return;
   }
} );

var Spinners = new Class( {
   Implements: [ Options ],

   options         : {
      config_attr  : 'spinners',
      class        : 'spinner-js',
      hideOnClick  : true,
      img          : false,
      selector     : '.spinner',
      shadow       : true,
      useIframeShim: false
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      new Spinner.JS( el, this.mergeOptions( el.id ) );
   }
} );

var Storage = new Class( {
    Implements: [ Options ],

    options              : {
        document         : window.document,
        driver           : JSON,
        globalStorageName: 'globalStorage',
        localStorageName : 'localStorage',
        namespace        : '__storejs__',
        window           : window
    },

    initialize: function( options ) {
        this.setOptions( options );

        var opt = this.options, win = opt.window, doc = opt.document, storage;

        if (this._isLocalStorageSupported()) {
            storage      = win[ opt.localStorageName ];
            this.clear   = function() { storage.clear() };
            this.get     = function( key ) {
                return this.deserialize( storage.getItem( key ) );
            }.bind( this );
            this.remove  = function( key ) { storage.removeItem( key ) };
            this.set     = function( key, val ) {
                storage.setItem( key, this.serialize( val ) ) }.bind( this );
        }
        else if (this._isGlobalStorageSupported()) {
            storage      = win[ opt.globalStorageName ][ win.location.hostname];
            this.clear   = function() {
                for (var key in storage) delete storage[ key ]; };
            this.get     = function( key ) {
                return this.deserialize( storage[ key ] && storage[ key ].value)
            }.bind( this );
            this.remove  = function( key ) { delete storage[ key ] };
            this.set     = function( key, val ) {
                storage[ key ] = this.serialize( val ) }.bind( this );
        }
        else if (doc.documentElement.addBehavior) {
            storage      = doc.createElement( 'div' );
            this.clear   = this._ieStorage( storage, function( storage ) {
                var attrs = storage.XMLDocument.documentElement.attributes;

                storage.load( opt.localStorageName );

                for (var i = 0, attr; attr = attrs[ i ]; i++)
                    storage.removeAttribute( attr.name );

                storage.save( opt.localStorageName );
            } );
            this.get     = this._ieStorage( storage, function( storage, key ) {
                return this.deserialize( storage.getAttribute( key ) );
            }.bind( this ) );
            this.remove  = this._ieStorage( storage, function( storage, key ) {
                storage.removeAttribute( key );
                storage.save( opt.localStorageName );
            } );
            this.set = this._ieStorage( storage, function( storage, key, val ) {
                storage.setAttribute( key, this.serialize( val ) );
                storage.save( opt.localStorageName );
            }.bind( this ) );
        }
        else {
            this.clear   = function() {};
            this.get     = function( key ) {};
            this.remove  = function( key ) {};
            this.set     = function( key, value ) {};
        }

        this.deserialize = function( value ) {
            return this.decode( value ) }.bind( opt.driver );
        this.serialize   = function( value ) {
            return this.encode( value ) }.bind( opt.driver );
        this.transact    = function( key, callback ) {
            var val = this.get( key ); if (typeof val == 'undefined') val = {};

            callback( val ); this.set( key, val );
        }.bind( this );
        this.disabled    = false;

        try {
            this.set( opt.namespace, opt.namespace );

            if (this.get( opt.namespace ) != opt.namespace)
                this.disabled = true;

            this.remove( opt.namespace );
        }
        catch (e) { this.disabled = true }
    },

    _ieStorage: function( storage, storeFn ) {
        var opt = this.options, doc = opt.document;

        return function() {
            var args = Array.prototype.slice.call( arguments, 0 );

            args.unshift( storage );
            doc.body.appendChild( storage );
            storage.addBehavior( '#default#userData' );
            storage.load( opt.localStorageName );

            var result = storeFn.apply( this, args );

            doc.body.removeChild( storage );
            return result;
        }.bind( this );
    },

    _isLocalStorageSupported: function() {
        var opt = this.options, win = opt.window;

        try {
            return (opt.localStorageName in win && win[ opt.localStorageName ] )
        }
        catch (e) { return false }
    },

    _isGlobalStorageSupported: function() {
        var opt = this.options, win = opt.window;

        try {
            return (opt.globalStorageName in win && win[ opt.globalStorageName ]
                    && win[ opt.globalStorageName ][ win.location.hostname ] ) }
        catch (e) { return false }
    }
} );

var SubmitUtils = new Class( {
   Implements: [ Options ],

   options       : {
      config_attr: 'anchors',
      formName   : null,
      selector   : '.submit',
      wildCards  : [ '%', '*' ]
   },

   initialize: function( options ) {
      this.aroundSetOptions( options );
      this.form = document.forms ? document.forms[ this.options.formName ]
                                 : function() {};
      this.build();
   },

   attach: function( el ) {
      var cfg; if (! (cfg = this.config[ el.id ])) return;

      var event = cfg.event || 'click', key = 'submit:' + event, handler;

      if (! (handler = el.retrieve( key )))
         el.store( key, handler = function( ev ) {
            return this[ cfg.method ].apply( this, cfg.args ) }.bind( this ) );

      el.addEvent( event, handler );
   },

   chooser: function( href, options ) {
      var opt   = this.mergeOptions( options );
      var value = this.form.elements[ opt.field ].value || '';

      for (var i = 0, max = opt.wildCards.length; i < max; i++) {
         if (value.indexOf( opt.wildCards[ i ] ) > -1) {
            var uri = href + '?form=' + opt.formName + '&field='  + opt.field
                                                     + '&button=' + opt.button;

            if (opt.subtype == 'modal') {
               opt.value        = value;
               opt.name         = opt.field;
               opt.onComplete   = function() { this.rebuild() };
               this.modalDialog = this.context.window.modalDialog( uri, opt );
               return false;
            }

            opt.name = 'chooser'; uri += '&val=' + value;
            top.chooser = this.context.window.openWindow( uri, opt );
            top.chooser.opener = top;
            return false;
         }
      }

      return this.submitForm( opt.button );
   },

   clearField: function( field_name ) {
      this.setField( field_name, '' ); return false;
   },

   confirmSubmit: function( button_value, text ) {
      if (text.length < 1 || window.confirm( text ))
         return this.submitForm( button_value );

      return false;
   },

   detach: function( el ) {
      var remove = function( el ) {
         var cfg; if (! (cfg = this.config[ el.id ])) return;

         var event   = cfg.event || 'click', key = 'submit:' + event;
         var handler = el.retrieve( key );

         if (handler) el.removeEvent( event, handler ).eliminate( key );
      }.bind( this );

      if (el) { remove( el ); this.collection.erase( el ) }
      else { this.collection.each( remove ); this.collection = [] }

      return this;
   },

   historyBack: function() {
      window.history.back(); return false;
   },

   postData: function( url, data ) {
      new Request( { url: url } ).post( data ); return false;
   },

   refresh: function( name, value ) {
      if (name) this.context.cookies.set( name, value );

      this.form.submit();
      return false;
   },

   returnValue: function( form_name, field_name, value, button ) {
      if (form_name && field_name) {
         var form = opener ? opener.document.forms[ form_name ]
                           :        document.forms[ form_name ];

         var el; if (form && (el = form.elements[ field_name ])) {
            el.value = value; if (el.focus) el.focus();
         }
      }

      if (opener) window.close();
      else if (this.modalDialog) this.modalDialog.hide();

      if (button) this.submitForm( button );

      return false;
   },

   setField: function( name, value ) {
      var el; if (name && (el = this.form.elements[ name ])) el.value = value;

      return el ? el.value : null;
   },

   submitForm: function( button_value ) {
      var button; $$( '*[name=_method]' ).some( function( el ) {
         if (el.value == button_value) { button = el; return true }
         return false;
      }.bind( this ) );

      if (button) { this.detach( button ); button.click() }
      else {
         new Element( 'input', {
            name: '_method', type: 'hidden', value: button_value
         } ).inject( $( 'top' ), 'after' );
      }

      this.form.submit();
      return true;
   },

   submitOnReturn: function( button_value ) {
      ev = new Event();

      if (ev.key == 'enter') {
         if (document.forms) return this.submitForm( button_value );
         else window.alert( 'Document contains no forms' );
      }

      return false;
   }
} );

var TableSort = new Class( {
   Implements: [ Events, Options ],

   options          : {
/*    onSortComplete: function() {}, */
      selector      : 'th.sort',
      sortRowClass  : 'sortable_row' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.sortables = {}; this.build();
   },

   attach: function( el ) {
      el.addEvent( 'click', function( ev ) {
         ev.stop(); this.sortRows( el ) }.bind( this ) );
   },

   _get_sort_order: function( table_id, default_column, column_id ) {
      var sortable = this.sortables[ table_id ]
                  || { sort_column: default_column, reverse: false };
      var reverse  = (column_id == sortable.sort_column)
                   ? ! sortable.reverse : false;

      sortable.reverse = reverse; sortable.sort_column = column_id;
      this.sortables[ table_id ] = sortable;
      return reverse ? [ 1, -1 ] : [ -1, 1 ];
   },

   _get_sort_value: function( cell, type ) {
      var el = cell ? cell.firstChild : '', value = '';

      if      (el && el.nodeName == '#text') value = el.nodeValue;
      else if (el && el.nodeName == 'INPUT') value = el.value;

      if (type && type == 'date') {
         value = Date.parse( value ) || Date.parse( '01 Jan 1970' );
      }
      else if (type && type == 'hex') {
         value = value.toLowerCase().pad( 64, '0', 'left' );
      }
      else if (type && type == 'ipaddr') {
         var ipaddr = value; value = '';

         ipaddr.split( '.' ).each( function( octet ) {
            value = value + String.from( octet ).pad( 3, '0', 'left' );
         } );
      }
      else if (type && type == 'money') {
         value = value.substring( 1 );
         value.replace( /[^0-9.]/g, '' );
         value = parseFloat( value ) || 0;
      }
      else if (type && type == 'numeric') {
         value.replace( /[^+\-0-9.]/g, '' );
         value = parseFloat( value ) || 0;
      }
      else value = String.from( value );

      return value;
   },

   sortRows: function( table_header ) {
      var id       = table_header.id,
          id_a     = id.split( '.' ),
          table_id = id_a[ 0 ], column_type = id_a[ 2 ],
          table    = $( table_id ),
          columns  = table.getElements( 'th' ),
          col_ids  = columns.map( function( column ) { return column.id } );

      if (! col_ids.contains( id )) return;

      var col_id   = col_ids.indexOf( id ),
          order    = this._get_sort_order( table_id, col_ids[ 0 ], id ),
          selector = 'tr.' + this.options.sortRowClass,
          rows     = [];

      table.getElements( selector ).map( function( row, index ) {
         var value = this._get_sort_value( row.cells[ col_id ], column_type );

         rows[ index ] = row;

         return [ value, row.clone( true, true ) ];
      }.bind( this ) ).sort( function( a, b ) {
         return a[ 0 ] < b[ 0 ] ? order[ 0 ]
             : (a[ 0 ] > b[ 0 ] ? order[ 1 ] : 0);
      } ).map( function( sorted_rows, index ) {
         var old_row    = rows[ index ],
             new_row    = sorted_rows[ 1 ],
             new_row_id = new_row.id;

         new_row.removeAttribute( 'id' ); new_row.replaces( old_row );

         return [ new_row, new_row_id ];
      } ).map( function( sorted_rows, index ) {
         var id, row = sorted_rows[ 0 ];

         if (id = sorted_rows[ 1 ]) row.id = id;

         return row;
      } );

      this.fireEvent( 'sortComplete' );
   }
} );

var TableUtils = new Class( {
   Implements: [ Events, Options ],

   options           : {
      config_attr    : 'tables',
      editRowClass   : 'editable_row',
      formName       : null,
      inputCellClass : 'data_field',
/*    onRowAdded     : function(){}, */
/*    onRowsRemoved  : function(){}, */
      selector       : '.editable_table',
      sortableOptions: {
         clone       : function( ev, el, list ) {
             return new Element( 'div' ).inject( document.body ); },
         constrain   : true,
         handle      : 'td.row_drag',
         revert      : { duration: 500, transition: 'elastic:out' } },
      sortRowClass   : 'sortable_row'
   },

   initialize: function( options ) {
      this.aroundSetOptions( options );
      this.form = document.forms ? document.forms[ this.options.formName ]
                                 : function() {};
      this.build();
   },

   attach: function( el ) {
      var opt = this.options;

      el.getElements( 'tr.' + opt.editRowClass ).each( function( row ) {
         $uid( row );
      } );

      el.sortables = new Sortables( el.getElement( 'tbody' ),
                                    opt.sortableOptions );

      var button = $( el.id + '_add' );

      if (button) button.addEvent( 'click', function( ev ) {
         ev.stop(); this.addRow( el ) }.bind( this ) );

      button = $( el.id + '_remove' );

      if (button) button.addEvent( 'click', function( ev ) {
         ev.stop(); this.removeRows( el ) }.bind( this ) );
   },

   addRow: function( table ) {
      var cNo     = 0, el,
          offset  = 0,
          opt     = this.options,
          cfg     = this.config[ table.id ] || {},
          edit    = cfg.editSide   || 'left',
          select  = cfg.selectSide || 'left',
          klass   = opt.inputCellClass,
          rows    = table.getElements( 'tr.' + opt.editRowClass ),
          nrows   = rows ? rows.length : 0,
          row_id  = nrows,
          row     = new Element( 'tr', {
             id   : table.id + '_row' + row_id,
             class: opt.editRowClass + ' ' + opt.sortRowClass } ),
          id_a    = table.id.split( '.' ),
          name    = id_a[ 1 ] || id_a[ 0 ];

      if (edit == 'left') {
         row.appendChild( this._add_drag( cNo++ ) ); offset++;
      }

      if (select == 'left') {
         row.appendChild( this._add_select( name, row_id, cNo++ ) );
         offset++;
      }

      while (el = $( table.id + '_add' + (cNo - offset) )) {
         var cell  = new Element( 'td' ),
             type  = el.type == 'textarea' ? 'textarea' : 'input',
             input = new Element( type, {
                class: el.className || 'ifield',
                name : name + '_' + row_id + '_' + (cNo - offset),
                value: el.value
             } );

         if (type == 'textarea') {
            if (el.cols) input.set( 'cols', el.cols );
            if (el.rows) input.set( 'rows', el.rows );
         }
         else {
            if (el.size) input.set( 'size', el.size );
         }

         if (el.maxlength) input.set( 'maxlength', el.maxlength );

         cell.appendChild( input );
         cell.set( 'class', klass + this._col_class( cNo++ ) );
         row.appendChild( cell );
         el.value = '';
      }

      if (select == 'right')
         row.appendChild( this._add_select( name, row_id, cNo++ ) );

      if (edit == 'right') row.appendChild( this._add_drag( cNo++ ) );

      this.form.elements[ '_' + name + '_nrows' ].value = nrows + 1;
      row.inject( $( table.id ).getElement( 'tbody' ) );
      table.sortables.attach();
      this.fireEvent( 'rowAdded' );
      return false;
   },

   _add_drag: function( cNo ) {
      var span = new Element( 'span', { class: 'drag_icon' } );
      var cell = new Element( 'td', {
         class: 'row_drag' + this._col_class( cNo )
      } );

      cell.appendChild( span );
      return cell;
   },

   _add_select: function( name, new_id, cNo ) {
      var input = new Element( 'input', {
         name: name + '.select' + new_id, type: 'checkbox'
      } );
      var cell  = new Element( 'td', {
         class: 'row_select' + this._col_class( cNo )
      } );

      cell.appendChild( input );
      return cell;
   },

   _col_class: function( cNo ) {
      return (cNo + 1) % 2 == 0 ? ' even_col' : ' odd_col';
   },

   removeRows: function( table ) {
      var rows      = table.getElements( 'tr.' + this.options.editRowClass ),
          nrows     = rows ? rows.length : 0,
          id_a      = table.id.split( '.' ),
          name      = id_a[ 1 ] || id_a[ 0 ],
          destroyed = 0;

      rows.map( function( row ) {
         row.getElements( 'td.row_select' ).map( function( cell ) {
            cell.getElements( 'input[type=checkbox]' ).map( function( cb ) {
               if (cb.checked) { row.destroy(); destroyed++ }
            } );
         } );
      } );

      this.form.elements[ '_' + name + '_nrows' ].value = nrows - destroyed;

      if (destroyed > 0) this.fireEvent( 'rowsRemoved' );

      return false;
   }
} );

/* Clientcide Copyright (c) 2006-2009
   Description: Handles the scripting for a common UI layout; the tabbed box.
   License: http://www.clientcide.com/wiki/cnet-libraries#license */

var TabSwapper = new Class( {
   Implements: [ Options, Events ],

   options           : {
      clickers       : 'a',
      cookieName     : 'tabswapper_',
      deselectedClass: 'off',
      effectOptions  : { duration: 500 },
      initPanel      : 0,
      maxSize        : null,
      mouseoverClass : 'tab_over',
//    onActive       : function(){},
//    onActiveAfterFx: function(){},
//    onBackground   : function(){},
      rearrangeDOM   : true,
      sections       : 'dd.panel',
      selectedClass  : 'tab_selected',
      smooth         : false,
      smoothSize     : false,
      tabs           : 'dt',
      usePersistance : true
   },

   tabs: [],

   initialize: function( el, options ) {
      this.cookies = options.cookies || function() {};

      this.setOptions( options ); var opt = this.options;

      this.cookieName = opt.cookieName + el.id;

      var sections = el.getElements( opt.sections );

      tabs = el.getElements( opt.tabs );

      tabs.each( function( tab, index ) {
         this.addTab( $( tab ), $( sections[ index ] ), index );
         this.hideSection( index );
      }, this );

      this.show( this.recall() ); el.store( 'tabSwapper', this );
   },

   addTab: function( tab, section, index ) {
      var opt = this.options;

      // If the index isn't specified, put the tab at the end
      if (index == undefined) index = this.tabs.length;

      // If the tab is already in the interface, just move it
      if (this.tabs.indexOf( tab ) >= 0 && tab.retrieve( 'tabbered' )
          && this.tabs.indexOf( tab ) != index && opt.rearrangeDOM) {
         this.moveTab( this.tabs.indexOf( tab ), index );
         return this;
      }

      // If this isn't the first item, and there's a tab
      // already in the interface at the index 1 less than this
      // insert this after that one
      if (index > 0 && this.tabs[ index - 1 ] && opt.rearrangeDOM) {
         tab.inject( this.tabs[ index - 1 ], 'after' );
         section.inject( this.tabs[ index - 1 ].retrieve( 'section' ), 'after');
      }

      this.tabs.splice( index, 0, tab );

      tab.addEvents( {
         mouseout : function() {
            this.removeClass( opt.mouseoverClass ); }.bind( tab ),
         mouseover: function() {
            this.addClass( opt.mouseoverClass ); }.bind( tab )
      } );

      var clicker = tab.getElement( opt.clickers ) || tab;

      clicker.addEvent( 'click', function( ev ) {
         ev.stop(); this.show( index ) }.bind( this ) );

      tab.store( 'tabbered', true    );
      tab.store( 'section',  section );
      tab.store( 'clicker',  clicker );
      return this;
   },

   hideSection: function( idx ) {
      var tab; if (! (tab = this.tabs[ idx ])) return this;

      var section; if (! (section = tab.retrieve( 'section' ))) return this;

      if (section.isDisplayed()) {
         this.lastHeight = section.getHeight(); section.hide();
         tab.swapClass( this.options.selectedClass,
                        this.options.deselectedClass );
         this.fireEvent( 'onBackground', [ tab, section, idx ] );
      }

      return this;
   },

   moveTab: function( from, to ) {
      var tab       = this.tabs[ from ];
      var clicker   = tab.retrieve( 'clicker' );
      var section   = tab.retrieve( 'section' );
      var toTab     = this.tabs[ to ];
      var toClicker = toTab.retrieve( 'clicker' );
      var toSection = toTab.retrieve( 'section' );

      this.tabs.erase( tab ).splice( to, 0, tab );
      tab.inject( toTab, 'before' );
      clicker.inject( toClicker, 'before' );
      section.inject( toSection, 'before' );
      return this;
   },

   recall: function() {
      var opt = this.options, panel;

      if (opt.usePersistance) panel = this.cookies.get( this.cookieName );

      return panel ? panel.toInt() : opt.initPanel;
   },

   removeTab: function( index ) {
      var now = this.tabs[ this.now ];

      if (this.now == index) {
         if (index > 0) this.show( index - 1 );
         else if (index < this.tabs.length) this.show( index + 1 );
      }

      this.now = this.tabs.indexOf( now );
      return this;
   },

   save: function( index ) {
      var opt = this.options;

      if (opt.usePersistance) this.cookies.set( this.cookieName, index );

      return this;
   },

   show: function( i ) {
      if (! (this.now || this.now === 0)) {
         this.tabs.each( function( tab, idx ) {
            if (i != idx) this.hideSection( idx );
         }, this );
      }

      this.showSection( i ).save( i );
      return this;
   },

   showSection: function( idx ) {
      var opt = this.options, smoothOk = opt.smooth && !Browser.ie;

      var tab; if (! (tab = this.tabs[ idx ])) return this;

      var section; if (! (section = tab.retrieve( 'section' ))) return this;

      if (this.now != idx) {
         if (! tab.retrieve( 'tabFx' ))
            tab.store( 'tabFx', new Fx.Morph( section, opt.effectOptions ) );

         var effect   = false;
         var overflow = section.getStyle( 'overflow' );
         var start    = { display: 'block', overflow: 'hidden' };

         if (smoothOk) {
            start.opacity = 0; effect = { opacity: 1 };
         } else if (section.getStyle( 'opacity' ).toInt() < 1) {
            section.setStyle( 'opacity', 1 );

            if (! opt.smoothSize)
               this.fireEvent( 'onActiveAfterFx', [ tab, section, idx ] );
         }

         if (opt.smoothSize) {
            var size = section.getDimensions().height;

            if ((opt.maxSize || opt.maxSize === 0) && opt.maxSize < size)
                size = opt.maxSize;

            if (! effect) effect = {};

            effect.height = size;
         }

         if (this.now || this.now === 0) this.hideSection( this.now );

         if (opt.smoothSize && this.lastHeight) start.height = this.lastHeight;

         section.setStyles( start );

         if (effect) {
            tab.retrieve( 'tabFx' ).start( effect ).chain( function() {
               this.fireEvent( 'onActiveAfterFx', [ tab, section, idx ] );

               section.setStyles( {
                  height  : this.options.maxSize == effect.height
                          ? this.options.maxSize : 'auto',
                  overflow: overflow
               } );

               var inputs = section.getElements( 'input, textarea' );

               inputs.setStyle( 'opacity', 1 );
            }.bind( this ) );
         }

         this.now = idx; this.fireEvent( 'onActive', [ tab, section, idx ] );
      }

      tab.swapClass( opt.deselectedClass, opt.selectedClass );
      return this;
   }
} );

var TabSwappers = new Class( {
   Implements: [ Options ],

   options       : {
      config_attr: 'tabSwappers',
      selector   : '.tabswapper',
      smooth     : true,
      smoothSize : true
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var opt = this.mergeOptions( el.id ); opt.cookies = this.context.cookies;

      new TabSwapper( el, opt );
   }
} );

/* Description: Class for creating nice tips that follow the mouse cursor
                when hovering an element.
   License: MIT-style license
   Authors: Valerio Proietti, Christoph Pojer, Luis Merino, Peter Flanigan */

(function() {

var getText = function( el ) {
   return (el.get( 'rel' ) || el.get( 'href' ) || '').replace( 'http://', '' );
};

var read = function( opt, el ) {
   return opt ? (typeOf( opt ) == 'function' ? opt( el ) : el.get( opt )) : '';
};

var storeTitleAndText = function( el, opt ) {
   if (el.retrieve( 'tip:title' )) return;

   var title = read( opt.title, el ), text = read( opt.text, el );

   if (title) {
      el.store( 'tip:native', title ); var pair = title.split( opt.separator );

      if (pair.length > 1) {
         title = pair[ 0 ].trim(); text = (pair[ 1 ] + ' ' + text).trim();
      }
   }
   else title = opt.hellip;

   if (title.length > opt.maxTitleChars)
      title = title.substr( 0, opt.maxTitleChars - 1 ) + opt.hellip;

   el.store( 'tip:title', title ).erase( 'title' );
   el.store( 'tip:text',  text  );
};

this.Tips = new Class( {
   Implements: [ Events, Options ],

   options         : {
      className    : 'tips',
      fixed        : false,
      fsWidthRatio : 1.35,
      hellip       : '\u2026',
      hideDelay    : 100,
      id           : 'tips',
      maxTitleChars: 40,
      maxWidthRatio: 4,
      minWidth     : 120,
      offsets      : { x: 4, y: 36 },
/*    onAttach     : function( el ) {}, */
/*    onBound      : function( coords ) {}, */
/*    onDetach     : function( el) {}, */
      onHide       : function( tip, el ) {
         tip.setStyle( 'visibility', 'hidden'  ) },
      onShow       : function( tip, el ) {
         tip.setStyle( 'visibility', 'visible' ) },
      selector     : '.tips',
      separator    : '~',
      showDelay    : 100,
      showMark     : true,
      spacer       : '\u00a0\u00a0\u00a0',
      text         : getText,
      timeout      : 30000,
      title        : 'title',
      windowPadding: { x: 0, y: 0 }
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.createMarkup();

      this.build(); this.fireEvent( 'initialize' );
   },

   attach: function( el ) {
      var opt = this.options; storeTitleAndText( el, opt );

      var events = [ 'enter', 'leave' ]; if (! opt.fixed) events.push( 'move' );

      events.each( function( value ) {
         var key = 'tip:' + value, method = 'element' + value.capitalize();

         var handler; if (! (handler = el.retrieve( key )))
            el.store( key, handler = function( ev ) {
               return this[ method ].apply( this, [ ev, el ] ) }.bind( this ) );

         el.addEvent( 'mouse' + value, handler );
      }, this );

      this.fireEvent( 'attach', [ el ] );
   },

   createMarkup: function() {
      var opt    = this.options;
      var klass  = opt.className;
      var dlist  = this.tip = new Element( 'dl', {
         'id'    : opt.id,
         'class' : klass + '-container',
         'styles': { 'left'      : 0,
                     'position'  : 'absolute',
                     'top'       : 0,
                     'visibility': 'hidden' } } ).inject( document.body );

      if (opt.showMark) {
         this.mark = []; [ 0, 1 ].each( function( idx ) {
            var el = this.mark[ idx ] = new Element( 'span', {
               'class': klass + '-mark' + idx } ).inject( dlist );

            [ 'left', 'top' ].each( function( prop ) {
               el.store( 'tip:orig-' + prop, el.getStyle( prop ) ) } );
         }, this );
      }

      this.term = new Element( 'dt', {
         'class' : klass + '-term' } ).inject( dlist );
      this.defn = new Element( 'dd', {
         'class' : klass + '-defn' } ).inject( dlist );
   },

   detach: function() {
      this.collection.each( function( el ) {
         [ 'enter', 'leave', 'move' ].each( function( value ) {
            var ev = 'mouse' + value, key = 'tip:' + value;

            el.removeEvent( ev, el.retrieve( key ) ).eliminate( key );
         } );

         this.fireEvent( 'detach', [ el ] );

         if (this.options.title == 'title') {
            var original = el.retrieve( 'tip:native' );

            if (original) el.set( 'title', original );
         }
      }, this );

      return this;
   },

   elementEnter: function( ev, el ) {
      clearTimeout( this.timer );
      this.timer = this.show.delay( this.options.showDelay, this, el );
      this.setup( el ); this.position( ev, el );
   },

   elementLeave: function( ev, el ) {
      clearTimeout( this.timer );

      var opt = this.options, delay = Math.max( opt.showDelay, opt.hideDelay );

      this.timer = this.hide.delay( delay, this, el );
      this.fireForParent( ev, el );
   },

   elementMove: function( ev, el ) {
      this.position( ev, el );
   },

   fireForParent: function( ev, el ) {
      el = el.getParent(); if (! el || el == document.body) return;

      if (el.retrieve( 'tip:enter' )) el.fireEvent( 'mouseenter', ev );
      else this.fireForParent( ev, el );
   },

   hide: function( el ) {
      this.fireEvent( 'hide', [ this.tip, el ] );
   },

   position: function( ev, el ) {
      var opt    = this.options;
      var bounds = opt.fixed ? this._positionFixed( ev, el )
                             : this._positionVariable( ev, el );

      if (opt.showMark) this._positionMarks( bounds );
   },

   _positionFixed: function( ev, el ) {
      var offsets = this.options.offsets, pos = el.getPosition();

      this.tip.setStyles( { left: pos.x + offsets.x, top: pos.y + offsets.y } );

      return { x: false, x2: false, y: false, y2: false };
   },

   _positionMark: function( state, quads, coord, dimn ) {
      for (var idx = 0; idx < 2; idx++) {
         var el     = this.mark[ idx ];
         var colour = el.getStyle( 'border-' + quads[ 0 ] + '-color' );

         if (colour != 'transparent') {
            el.setStyle( 'border-' + quads[ 0 ] + '-color', 'transparent' );
            el.setStyle( 'border-' + quads[ 1 ] + '-color', colour );
         }

         var orig  = el.retrieve( 'tip:orig-' + coord ).toInt();
         var value = this.tip.getStyle( dimn ).toInt();

         if (coord == 'left') {
            var blsize = this.tip.getStyle( 'border-left' ).toInt();
            var left   = this.mark[ 0 ].retrieve( 'tip:orig-left' ).toInt();

            value -= 2 * left - blsize * idx;
         }

         el.setStyle( coord, (state ? value : orig) + 'px' );
      }
   },

   _positionMarks: function( coords ) {
      var quads = coords[ 'x2' ] ? [ 'left', 'right' ] : [ 'right', 'left' ];

      this._positionMark( coords[ 'x2' ], quads, 'left', 'width' );

      quads = coords[ 'y2' ] ? [ 'bottom', 'top' ] : [ 'top', 'bottom' ];

      this._positionMark( coords[ 'y2' ], quads, 'top', 'height' );
   },

   _positionVariable: function( ev, el ) {
      var opt     = this.options, offsets = opt.offsets, pos = {};
      var prop    = { x: 'left',                 y: 'top'                 };
      var scroll  = { x: window.getScrollLeft(), y: window.getScrollTop() };
      var tip     = { x: this.tip.offsetWidth,   y: this.tip.offsetHeight };
      var win     = { x: window.getWidth(),      y: window.getHeight()    };
      var bounds  = { x: false, x2: false,       y: false, y2: false      };
      var padding = opt.windowPadding;

      for (var z in prop) {
         var coord = ev.page[ z ] + offsets[ z ];

         if (coord < 0) bounds[ z ] = true;

         if (coord + tip[ z ] > scroll[ z ] + win[ z ] - padding[ z ]) {
            coord = ev.page[ z ] - offsets[ z ] - tip[ z ];
            bounds[ z + '2' ] = true;
         }

         pos[ prop[ z ] ] = coord;
      }

      this.fireEvent( 'bound', bounds ); this.tip.setStyles( pos );

      return bounds;
   },

   setup: function( el ) {
      var opt    = this.options;
      var term   = el.retrieve( 'tip:title' ) || '';
      var defn   = el.retrieve( 'tip:text'  ) || '';
      var tfsize = this.term.getStyle( 'font-size' ).toInt();
      var dfsize = this.defn.getStyle( 'font-size' ).toInt();
      var max    = Math.floor( window.getWidth() / opt.maxWidthRatio );
      var w      = Math.max( term.length * tfsize / opt.fsWidthRatio,
                             defn.length * dfsize / opt.fsWidthRatio );

      w = parseInt( w < opt.minWidth ? opt.minWidth : w > max ? max : w );

      this.tip.setStyle( 'width', w + 'px' );
      this.term.set( 'html', term.replace( /\.\.\./g, '<br>' ) || opt.spacer );
      this.defn.set( 'html', defn.replace( /\.\.\./g, '<br>' ) || opt.spacer );
   },

   show: function( el ) {
      var opt = this.options;

      if (opt.timeout) this.timer = this.hide.delay( opt.timeout, this );

      this.fireEvent( 'show', [ this.tip, el ] );
   }
} );
} )();

var Togglers = new Class( {
   Implements: [ Options ],

   options: { config_attr: 'anchors', selector: '.togglers' },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();

      this.resize = this.context.resize.bind( this.context );
   },

   attach: function( el ) {
      var cfg; if (! (cfg = this.config[ el.id ])) return;

      el.addEvent( cfg.event || 'click', function( ev ) {
         ev.stop(); this[ cfg.method ].apply( this, cfg.args ) }.bind( this ) );
   },

   toggle: function( id, name ) {
      var el = $( id ); if (! el) return;

      var toggler = el.retrieve( name ); if (! toggler) return;

      toggler.toggle( this.context.cookies ); this.resize();
   },

   toggleSwapText: function( id, name, s1, s2 ) {
      var el = $( id ); if (! el) return; var cookies = this.context.cookies;

      if (cookies.get( name ) == 'true') {
         cookies.set( name, 'false' );

         if (el) el.set( 'html', s2 );

         if (el = $( name + 'Disp' )) el.hide();
      }
      else {
         cookies.set( name, 'true' );

         if (el) el.set( 'html', s1 );

         if (el = $( name + 'Disp' )) el.show();
      }

      this.resize();
   }
} );

var Trees = new Class( {
   Implements: [ Options ],

   options          : {
      classPrefix   : 'tree',
      cookieDomain  : '',
      cookiePath    : '/',
      cookiePrefix  : 'html_formwidgets',
      cookieSuffix  : 'tree',
      selector      : '.tree',
      usePersistance: true
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); var opt = this.options;

      if (opt.usePersistance) {
         var prefix = opt.cookiePrefix + '_' + opt.cookieSuffix;

         this.cookies = new Cookies( { domain: opt.cookieDomain,
                                       path  : opt.cookiePath,
                                       prefix: prefix } );
      }

      this.build();
   },

   attach: function( el, branch ) {
      if (! el || ! el.childNodes || el.childNodes.length == 0) return;

      if (! branch) this.attachControls( el.id );

      var dt, node;

      for (var i = 0, ecl = el.childNodes.length; i < ecl; i++) {
         if (! (node = $( el.childNodes[ i ] ))) continue;

         if (node.nodeName == 'DT') { dt = node; continue; }

         if (node.nodeName != 'DD') continue; var dd = node;

         this.setState( dt, dd, ! branch ); this.attachTogglers( dt, dd );

         for (var j = 0, ddcl = dd.childNodes.length; j < ddcl; j++) {
            if ((node = $( dd.childNodes[ j ] )) && node.nodeName == 'DL')
               this.attach( node, true );
         }
      }
   },

   attachControls: function( id ) {
      $( id + '_collapse_button' ).addEvent
         ( 'click', this.collapseTree.bind( this, id ) );
      $( id + '_expand_button' ).addEvent
         ( 'click', this.expandTree.bind( this, id ) );
   },

   attachToggler: function( dt, dd, klass, event ) {
      $$( '#' + dt.id + ' span.' + klass ).each( function( el ) {
         el.addEvent( event, function( ev ) {
            ev.stop(); this.toggle( dt, dd ) }.bind( this ) );
      }, this );
   },

   attachTogglers: function( dt, dd ) {
      var prefix = this.options.classPrefix;

      this.attachToggler( dt, dd, prefix + '_node_ctrl', 'click'    );
      this.attachToggler( dt, dd, prefix + '_node_icon', 'dblclick' );
   },

   close: function( dt, dd ) {
      var prefix = this.options.classPrefix;

      if (dt.hasClass( prefix + '_node_open' )) {
         dt.swapClass( prefix + '_node_open', prefix + '_node_closed' );
         dd.swapClass( prefix + '_node_open', prefix + '_node_closed' );
      }
      else if (dt.hasClass( prefix + '_node_last_open' )) {
         dt.swapClass( prefix + '_node_last_open',
                       prefix + '_node_last_closed' );
         dd.swapClass( prefix + '_node_last_open',
                       prefix + '_node_last_closed' );
      }

      if (this.options.usePersistance) this.cookies.set( dt.id, '0' );
   },

   collapseTree: function( treeId ) {
      var list = $( treeId );

      return list == null ? false : this.expandCollapseList( list, 'close' );
   },

   expandCollapseList: function( el, dirn, itemId ) {
      if (! el || ! el.childNodes || el.childNodes.length == 0) return false;

      var dt, node;

      for (var i = 0, ecl = el.childNodes.length; i < ecl; i++) {
         if (! (node = $( el.childNodes[ i ] ))) continue;

         if (itemId != null && itemId == node.id) return true;

         if (node.nodeName == 'DT') { dt = node; continue; }

         if (node.nodeName != 'DD') continue; var dd = node;

         for (var j = 0, ddcl = dd.childNodes.length; j < ddcl; j++) {
            if ((node = $( dd.childNodes[ j ] )) && node.nodeName == 'DL') {
               var ret = this.expandCollapseList( node, dirn, itemId );

               if (itemId != null && ret) {
                  if (dirn == 'close') this.close( dt, dd );
                  else this.open( dt, dd );

                  return true;
               }
            }
         }

         if (itemId == null) {
            if (dirn == 'close') this.close( dt, dd );
            else this.open( dt, dd );
         }
      }

      return false;
   },

   expandToItem: function( treeId, itemId ) {
      var list = $( treeId ), o, ret;

      if (list == null) return false;

      if (ret = this.expandCollapseList( list, 'open', itemId )) {
         if (o = $( itemId ) && o.scrollIntoView) o.scrollIntoView( false );
      }

      return ret;
   },

   expandTree: function( treeId ) {
      var list = $( treeId );

      return list == null ? false : this.expandCollapseList( list, 'open' );
   },

   open: function( dt, dd ) {
      var prefix = this.options.classPrefix;

      if (dt.hasClass( prefix + '_node_closed' )) {
         dt.swapClass( prefix + '_node_closed', prefix + '_node_open' );
         dd.swapClass( prefix + '_node_closed', prefix + '_node_open' );
      }
      else if (dt.hasClass( prefix + '_node_last_closed' )) {
         dt.swapClass( prefix + '_node_last_closed',
                       prefix + '_node_last_open' );
         dd.swapClass( prefix + '_node_last_closed',
                       prefix + '_node_last_open' );
      }

      if (this.options.usePersistance) this.cookies.set( dt.id, '1' );
   },

   setState: function( dt, dd, state ) {
      if (this.options.usePersistance) {
         this.cookies.get( dt.id ) == '1'
            ? this.open( dt, dd ) : this.close( dt, dd );
      }
      else {
         if (state) this.open( dt, dd );
         else this.close( dt, dd );
      }
   },

   toggle: function( dt, dd ) {
      var prefix = this.options.classPrefix;

      if (dt.hasClass( prefix + '_node_last_open' )
          || dt.hasClass( prefix + '_node_last_closed' )) {
         dt.toggleClass( prefix + '_node_last_open'   );
         dt.toggleClass( prefix + '_node_last_closed' );
         dd.toggleClass( prefix + '_node_last_open'   );
         dd.toggleClass( prefix + '_node_last_closed' );
      }
      else {
         dt.toggleClass( prefix + '_node_open'   );
         dt.toggleClass( prefix + '_node_closed' );
         dd.toggleClass( prefix + '_node_open'   );
         dd.toggleClass( prefix + '_node_closed' );
      }

      if (this.options.usePersistance) {
         if (dt.hasClass( prefix + '_node_open' )
             || dt.hasClass( prefix + '_node_last_open' ))
            this.cookies.set( dt.id, '1' );
         else this.cookies.set( dt.id, '0' );
      }

      return false;
   }
} );

var WindowUtils = new Class( {
   Implements: [ Options, LoadMore ],

   options       : {
      config_attr: 'anchors',
      customLogFn: false,
      height     : 600,
      quiet      : false,
      selector   : '.windows',
      target     : null,
      url        : null,
      width      : 800
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); var opt = this.options;

      if (opt.customLogFn) {
         if (typeOf( opt.customLogFn ) != 'function')
            throw 'customLogFn is not a function';
         else this.customLogFn = opt.customLogFn;
      }

      if (opt.target == 'top') this.placeOnTop();

      this.dialogs = [];
      this.build();
   },

   location: function( href ) {
      if (document.images) top.location.replace( href );
      else top.location.href = href;
   },

   logger: function( message ) {
      if (this.options.quiet) return;

      message = 'formwidgets.js: ' + message;

      if (this.customLogFn) { this.customLogFn( message ) }
      else if (window.console && window.console.log) {
         window.console.log( message );
      }
   },

   modalDialog: function( href, options ) {
      var opt = this.mergeOptions( options ), id = opt.name + '_dialog', dialog;

      if (! (dialog = this.dialogs[ opt.name ])) {
         var content = new Element( 'div', {
            'id': id } ).appendText( 'Loading...' );

         dialog = this.dialogs[ opt.name ]
                = new Dialog( undefined, content, opt );
      }

      this.request( href, id, opt.value || '', opt.onComplete || function() {
         this.rebuild(); dialog.show() } );

      return this.dialogs[ opt.name ];
   },

   openWindow: function( href, options ) {
      return new Browser.Popup( href, this.mergeOptions( options ) );
   },

   placeOnTop: function() {
      if (self != top) {
         if (document.images) top.location.replace( window.location.href );
         else top.location.href = window.location.href;
      }
   }
} );

/* Author  : luistar15, <leo020588 [at] gmail.com>
 * Class   : wysiwyg (rev.06-07-08)
 * License : MIT License */

var WYSIWYG = new Class( {
   Implements: [ Events, Options ],

   options             : {
      barNum           : 4,
      buttonWidth      : 24,
      buttons          : {
         anchor        : [  20, 'Anchor', 'anchor', 'Enter anchor id', '#' ],
         bigger        : [  72, 'Increase Font Size', 'increasefontsize',
                                null ],
         blockquote    : [  19, 'Blockquote', 'formatblock', '<BLOCKQUOTE>' ],
         bold          : [  30, 'Bold', 'bold', null ],
         clear         : [   0, 'Clear', 'selectall+delete', null ],
         copy          : [   3, 'Copy to Clipboard', 'copy', null ],
         cut           : [   4, 'Cut to Clipboard', 'cut', null ],
         div           : [  56, 'Div Element', 'formatblock', '<DIV>' ],
         elfinder      : [ 129, 'Find Element', 'elfinder',
                                'Enter element selector', '' ],
         flash         : [   9, 'Shockwave Flash', 'flash' ],
         forecolor     : [  50, 'Text Colour', 'forecolor',
                                'Enter text colour', '#' ],
         fullscreen    : [  21, 'Full Screen', 'fullscreen' ],
         h1            : [  67, 'Header Level 1', 'formatblock', '<H1>' ],
         h2            : [  68, 'Header Level 2', 'formatblock', '<H2>' ],
         h3            : [  69, 'Header Level 3', 'formatblock', '<H3>' ],
         hilitecolor   : [  51, 'Highlight Colour', 'hilitecolor',
                                'Enter highlight colour', '#' ],
         horizontalrule: [  18, 'Horizontal Rule', 'inserthorizontalrule',
                                null ],
         image         : [   8, 'Image', 'insertimage',
                                'Enter the image URL:', 'http://' ],
         indent        : [  11, 'Indent', 'indent', null ],
         italic        : [  33, 'Italic', 'italic', null ],
         justifycenter : [  36, 'Justify Centre', 'justifycenter', null ],
         justifyfull   : [  17, 'Justify Full', 'justifyfull', null ],
         justifyleft   : [  35, 'Justify Left', 'justifyleft', null ],
         justifyright  : [  37, 'Justify Right', 'justifyright', null ],
         link          : [  31, 'Link', 'createlink', 'Enter the URL:',
                                'http://' ],
         nbsp          : [  53, 'Non Breaking Space', 'nbsp', null ],
         nexttoolbar   : [  74, 'Next Toolbar', 'nexttoolbar' ],
         orderedlist   : [  15, 'Ordered List', 'insertorderedlist', null ],
         outdent       : [  10, 'Outdent', 'outdent', null ],
         paragraph     : [  70, 'Paragraph', 'formatblock', '<P>' ],
         paste         : [   5, 'Paste from Clipboard', 'paste', null ],
         preformatted  : [  17, 'Preformatted Text', 'formatblock', '<PRE>' ],
         redo          : [  39, 'Redo Previous Action', 'redo', null ],
         removeformat  : [   7, 'Remove Format', 'removeformat', null ],
         smaller       : [  71, 'Decrease Font Size', 'decreasefontsize',
                                null ],
         strikethrough : [  16, 'Strikethrough', 'strikethrough', null ],
         subscript     : [  12, 'Subscript', 'subscript', null ],
         superscript   : [  13, 'Superscript', 'superscript', null ],
         table         : [  23, 'Insert Table', 'table' ],
         tableprops    : [  44, 'Table Properties', 'tableprops' ],
         tablerm       : [  28, 'Remove Table', 'tablerm' ],
         tbrowbefore   : [  48, 'Insert Row Before', 'tbrowbefore' ],
         tbrowafter    : [  47, 'Insert Row After', 'tbrowafter' ],
         tbrowrm       : [  26, 'Remove Row', 'tbrowrm' ],
         tbcolbefore   : [  59, 'Insert Column Before', 'tbcolbefore' ],
         tbcolafter    : [  63, 'Insert Column After', 'tbcolafter' ],
         tbcolrm       : [  29, 'Remove Column', 'tbcolrm' ],
         tbcellprops   : [  64, 'Cell Properties', 'tbcellprops' ],
         tbcellsmerge  : [  40, 'Merge Cells', 'tbcellsmerge' ],
         tbcellsplit   : [  55, 'Split Cell', 'tbcellsplit' ],
         toggle        : [  66, 'Toggle View', 'toggleview' ],
         underline     : [  34, 'Underline', 'underline', null ],
         undo          : [  38, 'Undo Last Action', 'undo', null ],
         unlink        : [  32, 'Unlink', 'unlink', null ],
         unorderedlist : [  14, 'Unordered List', 'insertunorderedlist', null ]
      },
      container     : 'content',
      defaultBody   : '\u00a0',
      defaultClass  : 'wysiwyg_container',
      defaultState  : true,
      iconGridSize  : 30,
      iconsPerRow   : 10,
      iframeMargin  : 80,
      iframePadding : 14,
      minWidth      : 600,
      panels        : {
         alignment  : [ 'justifyleft', 'justifycenter',
                        'justifyright', 'justifyfull' ],
         control    : [ 'toggle', 'clear', 'nexttoolbar' ],
         edit1      : [ 'undo', 'redo' ],
         edit2      : [ 'undo', 'redo', 'copy', 'cut', 'paste', 'pastetext',
                        'pasteformattext', 'removeformat' ],
         edit3      : [ 'undo', 'redo', 'copy', 'cut', 'paste', 'pastetext',
                        'pasteformattext', 'removeformat', 'elfinder' ],
         elements   : [ 'horizontalrule', 'nbsp' ],
         fonts      : [ 'bigger', 'smaller', 'forecolor' ],
         format     : [ 'h1', 'h2', 'h3', 'paragraph',
                        'preformatted', 'div', 'blockquote' ],
         images     : [ 'image' ],
         indent     : [ 'outdent', 'indent' ],
         links      : [ 'link', 'unlink', 'anchor' ],
         lists      : [ 'orderedlist', 'unorderedlist' ],
         media      : [ 'image', 'flash' ],
         style      : [ 'bold', 'italic', 'underline', 'strikethrough',
                        'subscript', 'superscript' ],
         tables     : [ 'table', 'tableprops', 'tablerm',  'tbrowbefore',
                        'tbrowafter', 'tbrowrm', 'tbcolbefore', 'tbcolafter',
                        'tbcolrm', 'tbcellprops', 'tbcellsmerge',
                        'tbcellsplit' ],
         view       : [ 'hilitecolor', 'fullscreen' ]
      },
      selector      : '.wysiwyg',
      spacerWidth   : 10,
      toolbars      : [
         [ 'control', 'style' ],
         [ 'control', 'style', 'alignment', 'lists', 'links' ],
         [ 'control', 'style', 'format', 'fonts', 'alignment',
           'indent', 'lists', 'links', 'elements', 'images' ],
         [ 'control', 'edit1',
           'style', 'format', null, 'fonts', 'alignment',
          'indent', 'lists', 'links', 'elements', 'images' ],
         [ 'control', 'edit2', 'view',
           'style', 'format', null, 'fonts', 'alignment',
           'indent', 'lists', 'links', 'elements', 'images' ],
         [ 'control', 'edit3', 'view',
           'style', 'format', null, 'fonts', 'alignment',
           'indent', 'lists', 'links', 'elements', 'media', null, 'tables' ]
      ]
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();
   },

   attach: function( el ) {
      var opt   = this.options,
         editor = {
         element: el,
         height : -1,
         barNum : opt.barNum,
         open   : ! opt.defaultState,
         toolbar: new Element( 'span',   { class: 'toolbar' } ),
         iframe : new Element( 'iframe', { frameborder: 0, src: 'about:blank' })
      };

      this.loader = function( self, editor ) {
         return function() {
            editor.iframe.removeEvent( 'load', this.loader );
            editor.doc = editor.iframe.contentWindow.document;
            this.initialiseBody( editor, editor.element.value );
            editor.doc.designMode = 'on';
            return this.toggleView( editor );
         }.bind( self );
      }( this, editor );

      editor.iframe.addEvent( 'load', this.loader );

      new Element( 'div', {
         class: opt.defaultClass
      } ).inject( el, 'before' ).adopt( editor.toolbar, editor.iframe, el );

      this.initialiseToolbar( editor );

      window.addEvent( 'submit', function() {
         if (editor.open) this.toTextarea( editor );
      }.bind( this ) );

      el.editor = editor;
   },

   addButton: function( editor, b ) {
      var but = this.options.buttons[ b ]; if (! but) return false;
      var el  = Browser.ie
              ? new Element( 'a', { class: b, href: '//' + b, title: but[ 1 ] })
              : new Element( 'span', { class: b, title: but[ 1 ] } );

      if (b != 'toggle') this.setIcon( el, but[ 0 ] );

      var handler = function( self, editor, b ) {
         return function( ev ) {
            new Event( ev ).stop();

            return b == 'toggle' ? this.toggleView( editor, true )
                                 : this.exec( editor, b );
         }.bind( self );
      }( this, editor, b );

      el.addEvent( 'click', handler ).inject( editor.toolbar );
      return true;
   },

   clean: function( html ) {
      return html
         .replace( /<[^> ]*/g, function( s ) { return s.toLowerCase() } )
         .replace( /<[^>]*>/g, function( s ) {
               s = s.replace( / [^=]+=/g, function( a ) {
                     return a.toLowerCase() } ); return s } )
         .replace( /<[^>]*>/g, function( s ) {
               s = s.replace( /( [^=]+=)([^\"][^ >]*)/g, '$1\"$2\"' );
               return s } )
         .replace( /(<[^>]+) array="[^\"]*"([^>]*>)/g, '$1$2' )
         .replace( /<span style="font-weight: normal;">(.+?)<\/span>/gm, '$1' )
         .replace( /<span style="font-weight: bold;">(.+?)<\/span>/gm,
                   '<strong>$1</strong>' )
         .replace( /<span style="font-style: italic;">(.+?)<\/span>/gm,
                   '<em>$1</em>' )
         .replace( /<span style="(font-weight: bold; ?|font-style: italic; ?){2}">(.+?)<\/span>/gm,
                   '<strong><em>$2</em></strong>' )
         .replace( /<b(\s+|>)/g, '<strong$1' )
         .replace( /<\/b(\s+|>)/g, '</strong$1' )
         .replace( /<i(\s+|>)/g, '<em$1' )
         .replace( /<\/i(\s+|>)/g, '</em$1' )
         .replace( /<u>(.+?)<\/u>/gm,
                   '<span style="text-decoration: underline;">$1</span>' )
         .replace( /<img src="([^\">]*)">/g, '<img alt="Image" src="$1" />' )
         .replace( /(<img [^>]+[^\/])>/g, '$1 />' )
         .replace( /(<[^>]+)\s+>/g, '$1>' )
         .replace( /<br>\s*<\//g, '</' )
         .replace( /^&nbsp\;/g, ' ' )
         .replace( /&nbsp\;$/g, ' ' )
         .replace( /^\s+|\s+$/g, '' );
      /*
         .replace( /<(br|hr)>/g, '<$1 />' )
         .replace(/\s{2,}/g,' ')
         .replace(/<[^>]*>/g,function(s){s=s.replace(/ ([^=]+)="[^\"]*"/g,function(a,b){if(b=='alt'||b=='class'||b=='href'||b=='id'||b=='name'||b=='src'||b=='style'||b=='title'){return a}return''});return s})
         .replace(/<font[^>]*?>(.+?)<\/font>/gm,'$1')
         .replace(/<font>|<\/font>/gm,'')
         .replace(/<(table|tbody|tr|td|th)[^>]*>/g,'<$1>')
         .replace(/<\?xml[^>]*>/g,'')
         .replace(/<[^ >]+:[^>]*>/g,'')
         .replace(/<\/[^ >]+:[^>]*>/g,'')
         .replace(/(<br(\s+\/)?>)([^\n]|[^\r])/g,"$1\r\n$3")
         .replace(/<br(\s+\/)?>$/g, '')
         .replace(/(<[^\/]>|<[^\/][^>]*[^\/]>)\s*<\/[^>]*>/g,'')
      */
   },

   exec: function( editor, b, v ) {
      if (! editor.open) return;

      editor.iframe.contentWindow.focus();

      var but = this.options.buttons[ b ],
          doc = editor.doc,
          val = v || but[ 3 ];

      if (! v && ( but[ 4 ] != undefined)
          && ! (val = prompt( but[ 3 ], but[ 4 ] ))) return;

      switch (b) {
      case 'anchor':
         var html = '<a id="' + val + '" title="Bookmark: ' + val + '"> </a>';

         return doc.execCommand( 'inserthtml', false, html );
      case 'fullscreen':
         return this.fullscreen( editor );
      case 'nbsp':
         return doc.execCommand( 'inserthtml', false, '\u00a0' );
      case 'nexttoolbar':
         return this.nextToolBar( editor );
      default:
         var cmds = but[ 2 ].split( '+' );

         for (var i = 0, l = cmds.length; i < l; i++) {
            doc.execCommand( cmds[ i ], false, val );
         }
      }

      if (b == 'clear') this.initialiseBody( editor );

      return false;
   },

   fullscreen: function( editor ) {
      var height, width, iframe = editor.iframe,
          toolbar = editor.toolbar, opt = this.options;

      if (editor.height == -1) {
         var container = $( opt.container );

         editor.width  = iframe.getWidth();
         editor.height = iframe.getHeight();
         width         = container.getWidth()  - opt.iframeMargin;
         height        = container.getHeight() - opt.iframeMargin
                         - toolbar.getHeight();
      }
      else { width = editor.width; height = editor.height; editor.height = -1; }

      toolbar.setStyle( 'width',  width  + 'px' );
      iframe.setStyle(  'width',  width  + 'px' );
      iframe.setStyle(  'height', height + 'px' );
   },

   initialiseBody: function( editor, html ) {
      html = html && html.length > 0
           ? html.replace( /&nbsp;/g, '\u00a0' ) : this.options.defaultBody;
//      $( editor.doc.body ).set( 'html', html );
       editor.doc.body.innerHTML = html;
   },

   initialiseToolbar: function( editor ) {
      var opt      = this.options,
          panels   = opt.toolbars[ editor.barNum ],
          barWidth = 0,
          rowWidth = 8;

      editor.toolbar.empty();

      panels.each( function( p, index ) {
         if (! p) {
            new Element( 'br' ).inject( editor.toolbar ); rowWidth = 8; return;
         }

         var found = false;

         opt.panels[ p ].each( function( b ) {
            var added = this.addButton( editor, b );

            if (added) rowWidth += opt.buttonWidth;

            found = found || added;
         }, this );

         if (found && ( panels[ index + 1 ] != undefined)) {
            new Element( 'span', { class: 'spacer' } ).inject( editor.toolbar );

            rowWidth += opt.spacerWidth;
         }

         barWidth = Math.max( barWidth, rowWidth );
      }, this );

      barWidth = Math.max( opt.minWidth, barWidth );
      editor.toolbar.setStyle( 'width', barWidth + 'px' );
      editor.iframe.setStyle( 'width', barWidth + 'px' );
   },

   nextToolBar: function( editor ) {
      editor.barNum += 1;

      if (editor.barNum > this.options.toolbars.length - 1) editor.barNum = 0;

      this.initialiseToolbar( editor );
   },

   setIcon: function( el, butNum ) {
      var opt = this.options,
          x   = 0 - opt.iconGridSize * (butNum % opt.iconsPerRow),
          y   = 0 - opt.iconGridSize * Math.floor( butNum / opt.iconsPerRow );

      el.setStyle( 'background-position', x + 'px ' + y + 'px' );
   },

   toEditor: function( editor, view ) {
      var html = editor.element.value.trim() || '';

      this.initialiseBody( editor, html );

      if (view) {
         editor.element.addClass( 'hidden' );
         editor.iframe.removeClass( 'hidden' );
         editor.toolbar.removeClass( 'disabled' );
      }
   },

   toggleView: function( editor, focus ) {
      if (editor.doc.body) {
         editor.open = ! editor.open;

         if (editor.open) this.toEditor( editor, true );
         else this.toTextarea( editor, true );

              if (focus &&   editor.open) editor.iframe.contentWindow.focus();
         else if (focus && ! editor.open) editor.element.focus();
      }

      return false;
   },

   toTextarea: function( editor, view ) {
      var doc; if (! (doc = editor.doc)) return;

      editor.element.value = this.clean( doc.body.innerHTML.unescapeHTML() );

      if (view) {
         editor.element.removeClass( 'hidden' );
         editor.iframe.addClass( 'hidden' );
         editor.toolbar.addClass( 'disabled' );
      }
   }
} );

function Expand_Collapse() {}

/* Local Variables:
 * mode: javascript
 * tab-width: 3
 * End: */
