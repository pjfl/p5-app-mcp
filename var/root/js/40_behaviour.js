var StateDiagram = new Class( {
   Implements: [ Options ],

   options        : {
      height      : 600,
      selector    : '.state-diagram',
      updatePeriod: 3,
      width       : 800
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build(); this.start();
   },

   attach: function( el ) {
      var opt = this.options;

      if (!this.paper) this.paper = Raphael( el.id, opt.width, opt.height );

   },

   start: function() {
      var opt = this.options;

      if (!this.timer)
         this.timer = this.updater.periodical( opt.updatePeriod, this );
   },

   stop: function() {
      if (this.timer) { clearInterval( this.timer ); this.timer = null; }
   },

   updater: function() {
   }
} );

var Behaviour = new Class( {
   Implements: [ Events, Options ],

   config            : {
      anchors        : {},
      calendars      : {},
      inputs         : {},
      lists          : {},
      scrollPins     : {},
      server         : {},
      sidebars       : {},
      sliders        : {},
      spinners       : {},
      tables         : {},
      tabSwappers    : {}
   },

   options           : {
      baseURI        : null,
      cookieDomain   : '',
      cookiePath     : '/',
      cookiePrefix   : 'behaviour',
      formName       : null,
      iconClasses    : [ 'down_point_icon', 'up_point_icon' ],
      popup          : false,
      statusUpdPeriod: 4320,
      target         : null
   },

   initialize: function( options ) {
      this.setOptions( options ); this.collection = [];

      window.addEvent( 'load',   function() {
         this.load( options.firstField ) }.bind( this ) );
      window.addEvent( 'resize', function() { this.resize() }.bind( this ) );
   },

   collect: function( object ) {
      this.collection.include( object ); return object;
   },

   load: function( first_field ) {
      var opt = this.options;

      this.cookies     = new Cookies( {
         domain        : opt.cookieDomain,
         path          : opt.cookiePath,
         prefix        : opt.cookiePrefix } );
      this.stylesheet  = new PersistantStyleSheet( { cookies: this.cookies } );

      this._restoreStateFromCookie();

      this.window      = new WindowUtils( {
         context       : this,
         target        : opt.target,
         url           : opt.baseURI } );
      this.submit      = new SubmitUtils( {
         context       : this,
         formName      : opt.formName } );

      this.liveGrids   = new LiveGrids( {
         context       : this,
         iconClasses   : opt.iconClasses,
         url           : opt.baseURI } );
      this.diagram     = new StateDiagram( { context: this } );
      this.replacement = new Replacements( { context: this } );
      this.server      = new ServerUtils( {
         context       : this,
         url           : opt.baseURI } );
      this.sliders     = new Sliders( { context: this } );
      this.togglers    = new Togglers( { context: this } );

      this.resize();

      this.tips        = new Tips( {
         context       : this,
         onHide        : function() { this.fx.start( 0 ) },
         onInitialize  : function() {
            this.fx    = new Fx.Tween( this.tip, {
               duration: 500, property: 'opacity' } ).set( 0 ); },
         onShow        : function() { this.fx.start( 1 ) },
         showDelay     : 666 } );

      if (opt.statusUpdPeriod && !opt.popup)
         this.statusUpdater.periodical( opt.statusUpdPeriod, this );

      var el; if (first_field && (el = $( first_field ))) el.focus();
   },

   rebuild: function() {
      this.collection.each( function( object ) { object.build() } );
   },

   resize: function() {
      var opt = this.options, h = window.getHeight(), w = window.getWidth();

      if (! opt.popup) {
         this.cookies.set( 'height', h ); this.cookies.set( 'width',  w );
      }
   },

   _restoreStateFromCookie: function() {
      /* Use state cookie to restore the visual state of the page */
      var cookie_str; if (! (cookie_str = this.cookies.get())) return;

      var cookies = cookie_str.split( '+' ), el;

      for (var i = 0, cl = cookies.length; i < cl; i++) {
         if (! cookies[ i ]) continue;

         var pair = cookies[ i ].split( '~' );
         var p0   = unescape( pair[ 0 ] ), p1 = unescape( pair[ 1 ] );

         /* Restore the state of any elements whose ids end in Disp */
         if (el = $( p0 + 'Disp' )) { p1 != 'false' ? el.show() : el.hide(); }
         /* Restore the className for elements whose ids end in Icon */
         if (el = $( p0 + 'Icon' )) { if (p1) el.className = p1; }
         /* Restore the source URL for elements whose ids end in Img */
         if (el = $( p0 + 'Img'  )) { if (p1) el.src = p1; }
      }
   },

   statusUpdater: function() {
      var h = window.getHeight(), w = window.getWidth();

      var swatch_time = Date.swatchTime();

      window.defaultStatus = 'w: ' + w + ' h: ' + h + ' @' + swatch_time;
   }
} );

/* Local Variables:
 * mode: javascript
 * tab-width: 3
 * End: */
