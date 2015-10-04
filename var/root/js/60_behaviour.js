var StateDiagram = new Class( {
// TODO: Its a tree display it like tree does
   Implements: [ Events, Options ],

   Binds: [ '_updater' ],

   options            : {
      colour_map      : { active:   '#fff',    hold:       '#00f',
                          failed:   '#b21818', finished:   '#99f',
                          inactive: '#cc9',    running:    '#0f0',
                          starting: '#fbd12a', terminated: '#f00' },
      height          : 600,
      selector        : '.state-diagram',
      style           : {
         border_colour: '#000',
         border_width : 1,
         border_radius: 3,
         col_width    : 500,
         font_size    : 16,
         font_family  : 'Verdana',
         leading      : 16,
         line_height  : 24,
         margin       : 12,
         padding      : 12 },
      update_period   : 10000,
      url             : null,
      width           : 800
   },

   initialize: function( options ) {
      this.aroundSetOptions( options ); this.build();

      if (this.paper) this.start();
   },

   attach: function( el ) {
      var opt = this.options;

      if (!this.paper) this.paper = SVG( el.id ).size( opt.width, opt.height );

   },

   start: function() {
      if (this.is_running) return;

      this.unload_handler = function() { this.stop() }.bind( this );
      window.addEvent( 'unload', this.unload_handler );
      this.is_running = true;
      this._updater();
   },

   stop: function() {
      this.is_running = false;
      window.removeEvent( 'unload', this.unload_handler );
   },

   _updater: function() {
      var level      = 1;
      var url        = this.options.url + 'api/state?level=' + level;
      var headers    = { 'Accept': 'application/json' };
      var on_success = this._response.bind( this );

      new Request( {
         'headers': headers, 'onSuccess': on_success, 'url': url } ).get();
   },

   _render_frame: function( frame, i, paper, x, y ) {
      var opts       = this.options;
      var style      = opts.style;
      var text_style = { 'family'      : style.font_family,
                         'leading'     : style.leading,
                         'size'        : style.font_size };
      var rect_style = { 'stroke'      : style.border_colour,
                         'stroke-width': style.border_width };

      for (var max = frame.jobs.length; i < max; i++) {
         var job         = frame.jobs[ i ];
         var name        = job.name;
         var label       = paper.text( name ).font( text_style ).center( x, y );
         var label_width = label.bbox().width;
         var left        = x - style.padding - label_width / 2;
         var box_width   = label_width + 2 * style.padding;

         rect_style.fill = opts.colour_map[ job.state ];
         paper.rect( box_width, style.line_height )
              .style( rect_style )
              .radius( style.border_radius )
              .move( left, y - style.padding );
         paper.use( label );

         if (job.type == 'box') {
            var content = paper.rect( box_width, style.line_height )
                               .style( rect_style )
                               .radius( style.border_radius )
                               .move( left, y + style.padding );

            y += content.bbox().height;
         }

         y += style.margin + 2 * style.padding + style.line_height;
      }

      return { i: i, x: x, y: y };
   },

   _response: function( resp ) {
      if (!resp) return; Browser.exec( 'var current_frame = ' + resp );

      if (this.last_frame_id && this.last_frame_id == current_frame.id) return;

      this.last_frame_id = current_frame.id;

      var paper      = this.paper;
      var opts       = this.options;
      var style      = opts.style;
      var caption    = 'Last updated: ' + current_frame.minted;
      var text_style = { 'family' : style.font_family,
                         'leading': style.leading,
                         'size'   : style.font_size };
      var x          = style.padding;
      var y          = style.padding;

      paper.clear(); paper.text( caption ).font( text_style ).move( x, y );
      x = style.col_width / 2;
      y = style.margin + 2 * style.padding + style.line_height;

      this._render_frame( current_frame, 0, this.paper, x, y );

      if (this.is_running) this._updater.delay( opts.update_period );
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
      this.setOptions( options ); this.collection = []; this.attach();
   },

   attach: function() {
      var opt = this.options;

      window.addEvent( 'load',   function() {
         this.load( opt.firstField ) }.bind( this ) );
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
