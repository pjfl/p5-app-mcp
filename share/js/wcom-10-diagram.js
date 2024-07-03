// -*- coding: utf-8; -*-
// Package WCom.StateDiagram
WCom.StateDiagram = (function() {
   const dsName       = 'stateConfig';
   const triggerClass = 'state-container';
   const Utils        = WCom.Util;
   class Job {
      constructor(diagram, result, index) {
         this.diagram   = diagram;
         this.index     = index;
         this.jobName   = result['job-name'];
         this.jobURI    = result['job-uri'];
         this.nodes     = result['nodes'] || [];
         this.stateName = result['state-name'];
         this.type      = result['type'];
      }
      render(container) {
         const link = this.h.a({ href: this.jobURI }, this.jobName);
         const content = [this.h.div({ className: 'title' }, link)];
         let tileClass = 'job-tile';
         if (this.type == 'box') {
            tileClass = 'box-tile';
            const body = this.h.div({ className: 'box' });
            content.push(body);
            let index = 0;
            for (const result of this.nodes) {
               const job = new Job(this.diagram, result, index++);
               job.render(body);
            }
         }
         tileClass += ' ' + this.stateName;
         const attr = { className: tileClass, id: this.jobName };
         this.display(container, 'jobTile', this.h.div(attr, content));
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
   class Diagram {
      constructor(container, config) {
         this.container = container;
         this.resultSet = new ResultSet(config['data-uri']);
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
         while (job = await this.nextJob(index++)) { this.jobs.push(job) }
      }
      async render() {
         await this.renderJobs();
      }
      async renderJobs() {
         await this.readJobs();
         if (!this.jobs.length) return this.renderNoData();
         for (const job of this.jobs) job.render(this.container);
         if (this.pageManager) this.pageManager.onContentLoad();
      }
      renderNoData() {
      }
   }
   class Manager {
      constructor() {
         this.diagrams = {};
         Utils.Event.onReady(function() { this.scan() }.bind(this));
         Utils.Event.register(function(content, options) {
            this.scan(content, options)
         }.bind(this));
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
   const manager = new Manager();
   return {
      manager
   };
})();

