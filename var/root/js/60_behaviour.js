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
      this.setOptions( options ); this.collection = []; this.attach();
   },

   attach: function() {
      window.addEvent( 'load',   function() { this.load()   }.bind( this ) );
      window.addEvent( 'resize', function() { this.resize() }.bind( this ) );
   },

   collect: function( object ) {
      this.collection.include( object ); return object;
   },

   load: function() {
      var opt = this.options;

      this.cookies     = new Cookies( {
         domain        : opt.cookieDomain,
         path          : opt.cookiePath,
         prefix        : opt.cookiePrefix } );
      this.stylesheet  = new PersistantStyleSheet( { cookies: this.cookies } );

      this.restoreStateFromCookie(); this.resize();

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
      this.replacement = new Replacements( { context: this } );
      this.server      = new ServerUtils( {
         context       : this,
         url           : opt.baseURI } );
      this.sliders     = new Sliders( { context: this } );
      this.togglers    = new Togglers( { context: this } );
      this.trees       = new Trees( {
         context       : this,
         cookieDomain  : opt.cookieDomain,
         cookiePath    : opt.cookiePath,
         cookiePrefix  : opt.cookiePrefix } );
      this.linkFade    = new LinkFader( { context: this } );
      this.tips        = new Tips( {
         context       : this,
         onHide        : function() { this.fx.start( 0 ) },
         onInitialize  : function() {
            this.fx    = new Fx.Tween( this.tip, {
               duration: 500, property: 'opacity' } ).set( 0 ); },
         onShow        : function() { this.fx.start( 1 ) },
         showDelay     : 666 } );

      if (window.Chosens != undefined)
         this.chosens  = new Chosens( { context: this } );

      if (opt.statusUpdPeriod && !opt.popup)
         this.statusUpdater.periodical( opt.statusUpdPeriod, this );

      var el; if (opt.firstField && (el = $( opt.firstField ))) el.focus();
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

   restoreStateFromCookie: function() {
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

      if (el = $( 'page-status' ) )
         el.set( 'html', 'w: ' + w + ' h: ' + h + ' @' + swatch_time );
   }
} );

/* Local Variables:
 * mode: javascript
 * tab-width: 3
 * End: */
