// -*- coding: utf-8; -*-
// Package WCom.StateDiagram
WCom.StateDiagram = (function() {
   const dsName       = 'stateConfig';
   const triggerClass = 'state-container';
   const Utils        = WCom.Util;
   const Modal        = WCom.Modal;
   class Job {
      constructor(diagram, result, index) {
         this.diagram   = diagram;
         this.dependsOn = result['depends-on'];
         this.id        = result['id'];
         this.jobName   = result['job-name'];
         this.jobURI    = result['job-uri'];
         this.nodes     = result['nodes'] || [];
         this.parentId  = result['parent-id'];
         this.stateName = result['state-name'];
         this.type      = result['type'];
         this.index     = index;
         this.diagram.depGraph.jobs.push(this);
      }
      render(container) {
         const title = [this._renderLink()];
         if (this.type == 'box') title.push(this._renderToggleIcon());
         const content = [this.h.div({ className: 'title' }, title)];
         if (this.type == 'box') {
            this.boxTable = this.h.div({ className: 'box-table' });
            if (this.nodes[0]) {
               this._renderNodes(this.boxTable);
               this.boxTable.classList.add('open');
            }
            content.push(this.boxTable);
         }
         const id = this.type + this.id;
         const className = (this.type == 'box') ? 'box-tile' : 'job-tile';
         const jobTile = this.h.div({ className, id }, content);
         jobTile.classList.add(this.stateName);
         this.jobTile = this.display(container, 'jobTile', jobTile);
      }
      _maxRowIndex(job2row, job) {
         let rowIndex = 0;
         if (job.dependsOn.length) {
            for (const id of job.dependsOn) {
               if (job2row[id] > rowIndex) rowIndex = job2row[id];
            }
         }
         return rowIndex;
      }
      _renderLink() {
         const onclick = function(event) {
            event.preventDefault();
            let modal = this.diagram.modal;
            const prefs = this.diagram.prefs;
            const positionAbsolute = prefs.positionAbsolute;
            if (modal && modal.open) modal.close();
            modal = Modal.create({
               backdrop: { noMask: true },
               dropCallback: function() {
                  const { left, top } = modal.position();
                  positionAbsolute.x = Math.trunc(left);
                  positionAbsolute.y = Math.trunc(top);
                  prefs.set({ positionAbsolute });
               }.bind(modal),
               icons: this.diagram.icons,
               id: 'job_state_modal',
               initValue: null,
               noButtons: true,
               positionAbsolute,
               title: this.type == 'box' ? 'Box State' : 'Job State',
               url: this.jobURI
            });
            this.diagram.modal = modal;
         }.bind(this);
         const link = this.h.a({ onclick }, this.jobName);
         link.setAttribute('clicklistener', true);
         return link;
      }
      _renderNodes(container) {
         const job2row = {};
         const rows = [];
         let jobIndex = this.index + 1;
         for (const result of this.nodes) {
            const job = new Job(this.diagram, result, jobIndex++);
            const rowIndex = this._maxRowIndex(job2row, job) + 1;
            job2row[job.id] = rowIndex;
            if (!rows[rowIndex]) {
               rows[rowIndex] = this.h.div({ className: 'box-row' });
               container.appendChild(rows[rowIndex]);
            }
            job.render(rows[rowIndex]);
         }
      }
      _renderToggleIcon() {
         const attr = {
            className: 'button-icon box-toggle',
            onclick: function(event) {
               event.preventDefault();
               this.boxTable.classList.toggle('open');
               this.toggleIcon.classList.toggle('reversed');
               this.diagram.depGraph.render();
            }.bind(this)
         };
         const icons = this.diagram.icons;
         if (icons) {
            const icon = this.h.icon({
               className: 'toggle-icon', icons, name: 'chevron-down'
            });
            this.toggleIcon = this.h.span(attr, icon);
         }
         else { this.toggleIcon = this.h.span(attr, 'V') }
         if (!this.nodes[0]) this.toggleIcon.classList.add('reversed');
         return this.toggleIcon;
      }
   }
   Object.assign(Job.prototype, Utils.Markup);
   class ResultSet {
      constructor(uri) {
         this.dataURI = uri;
         this.index = 0;
         this.jobCount = 0;
         this.jobs = [];
      }
      async next() {
         if (this.index > 0) return this.jobs[this.index++];
         const { object } = await this.bitch.sucks(this.dataURI);
         if (object) this.jobCount = parseInt(object['job-count'], 10);
         else this.jobCount = 0;
         if (this.jobCount > 0) {
            this.jobs = object['jobs'];
            return this.jobs[this.index++];
         }
         this.jobs = [];
         return this.jobs[0];
      }
   }
   Object.assign(ResultSet.prototype, Utils.Bitch);
   class DependencyGraph {
      constructor(diagram) {
         this.diagram = diagram;
         this.index = [];
         this.jobs = [];
         this.container = this.diagram.container;
         this.canvas = this.h.canvas({ className: 'dependencies' });
         this.container.insertBefore(this.canvas, this.container.firstChild);
      }
      render() {
         if (!(this.canvas.getContext && this.jobs[0])) return;
         this.canvas.height = this.container.offsetHeight;
         this.canvas.width = this.container.offsetWidth;
         const { left, top } = this.h.getOffset(this.container);
         const containerLeft = left;
         const containerTop = top;
         for (const job of this.jobs) {
            this.index[job.id] = job;
            const { bottom, left, right, top } = this.h.getOffset(job.jobTile);
            // Make relative to container
            job.bottom = bottom - containerTop;
            job.left = left - containerLeft;
            job.right = right - containerLeft;
            job.top = top - containerTop;
         }
         const context = this.canvas.getContext('2d');
         for (const job of this.jobs) {
            if (!job.dependsOn[0]) continue;
            const parent = this.index[job.parentId];
            // Parent box is closed so no lines to draw
            if (parent && parent.toggleIcon.classList.contains('reversed'))
               continue;
            context.beginPath();
            for (const depends of job.dependsOn) {
               const fj = this.index[depends];
               const from = {
                  x: fj.left + Math.round((fj.right - fj.left) / 2),
                  y: fj.bottom,
               };
               const to = {
                  x: job.left + Math.round((job.right - job.left) / 2),
                  y: job.top,
               };
               context.moveTo(from.x, from.y);
               context.lineTo(to.x, to.y);
            }
            context.closePath();
            context.stroke();
         }
      }
   }
   Object.assign(DependencyGraph.prototype, Utils.Markup);
   class Preferences {
      constructor(diagram, uri) {
         this.diagram = diagram;
         if (uri) this.prefsURI = uri;
         this.get();
      }
      async get() {
         if (!this.prefsURI) return;
         const { object } = await this.bitch.sucks(this.prefsURI);
         if (object['position-absolute'])
            this.positionAbsolute = object['position-absolute'];
      }
      set(values) {
         this.positionAbsolute = values.positionAbsolute;
         if (!this.prefsURI) return;
         const data = { 'position-absolute': this.positionAbsolute };
         const json = JSON.stringify({ data, '_verify': this.diagram.token });
         this.bitch.blows(this.prefsURI, { json: json });
      }
   }
   Object.assign(Preferences.prototype, Utils.Bitch);
   class Diagram {
      constructor(container, config) {
         this.domWait   = config['dom-wait'] || 500;
         this.icons     = config['icons'];
         this.maxJobs   = config['max-jobs'];
         this.name      = config['name'];
         this.onload    = config['onload'];
         this.token     = config['verify-token'];
         this.container = this.h.div({ className: 'diagram-container' });
         container.appendChild(this.container);
         this.resultSet = new ResultSet(config['data-uri']);
         this.depGraph  = new DependencyGraph(this);
         this.prefs     = new Preferences(this, config['prefs-uri']);
      }
      async nextJob(index) {
         const result = await this.resultSet.next();
         if (result) return new Job(this, result, index);
         return undefined;
      }
      async readJobs() {
         this.jobs = [];
         let index = 0;
         let job;
         while (job = await this.nextJob(++index)) this.jobs.push(job);
      }
      async render() {
         await this.readJobs();
         if (this.jobs.length) {
            for (const job of this.jobs) job.render(this.container);
            setTimeout(
               function() { this.depGraph.render() }.bind(this), this.domWait
            );
         }
         else { this.renderNoData(this.container) }
         if (this.onload) eval(this.onload);
      }
      renderNoData(container) {
      }
   }
   Object.assign(Diagram.prototype, Utils.Markup);
   class Manager {
      constructor() {
         this.diagrams = {};
         Utils.Event.registerOnload(this.scan.bind(this));
      }
      isConstructing() {
         return new Promise(function(resolve) {
            setTimeout(() => {
               if (!this._isConstructing) resolve(false);
            }, 250);
         }.bind(this));
      }
      async scan(content = document, options = {}) {
         this._isConstructing = true;
         const promises = [];
         for (const el of content.getElementsByClassName(triggerClass)) {
            const diagram = new Diagram(el, JSON.parse(el.dataset[dsName]));
            this.diagrams[diagram.name] = diagram;
            promises.push(diagram.render());
         }
         await Promise.all(promises);
         this._isConstructing = false;
      }
   }
   return {
      manager: new Manager()
   };
})();

