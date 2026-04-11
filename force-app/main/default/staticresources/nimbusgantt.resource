window.NimbusGantt=(function(ne){"use strict";function Oe(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(u);d||(d=[],n.set(u,d)),d.push(l)}const s=[];function o(l,u){const d=l.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return d!==h?d-h:l.name.localeCompare(u.name)}function i(l,u,d){const h=n.get(l);return h?(h.sort(o),h.map(p=>{const c=n.has(p.id)&&t.has(p.id),g=d,y={task:p,children:[],depth:u,expanded:c,visible:g,rowIndex:-1};return g&&(y.rowIndex=s.length,s.push(p.id)),y.children=i(p.id,u+1,g&&c),y})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function ut(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class Vn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Qo(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Qo(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Oe(n,e.expandedIds),a=ut(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Oe(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=ut(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}class Kn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const nn=864e5,ei=nn*7,ti={day:40,week:120,month:180,quarter:200},jn=["January","February","March","April","May","June","July","August","September","October","November","December"],qn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class Zn{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=ti[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/nn)}countWeeks(){return Math.ceil(this.totalMs/ei)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=Jn(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=sn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${jn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=Jn(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${qn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=sn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),d=this.dateToX(l);t.push({label:`${jn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:d-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:qn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=sn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=ni(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(l)}),i=a}return[t,n]}}function Jn(e,t){return new Date(e.getTime()+t*nn)}function ni(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function sn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class Qn{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const d=gt(u.startDate),h=gt(u.endDate),p=s.dateToX(d),r=s.dateToX(h)-p,c=Math.max(r,o.minBarWidth),g=a*o.rowHeight,y=g+(o.rowHeight-o.barHeight)/2,T=c*(u.progress||0),f=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:g,width:c,barY:y,barHeight:o.barHeight,progressWidth:T,color:f,textColor:o.theme.barTextColor,label:u.name,isMilestone:u.isMilestone||!1})}return i}}function gt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const on=864e5,es=1,si=2,oi=.5,ii=2,ts=8,ai=6,ns=2;class ri{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:d}=u,h=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=u.headerHeight,g=a-c;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,g),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,c,g,d),this.renderGridLines(s,c,g,d,h),this.renderAltRows(t,n,c,d,h,p);const y=this.getTodayX(t,u,s);u.showToday&&y!==null&&this.renderTodayBackground(y,s,c,g,d),this.renderTaskBars(t,n,u,d,h,p,c,g),u.showToday&&y!==null&&this.renderTodayLine(y,c,g,d),o.restore(),this.renderHeader(s,u,d,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const d=l.getTime();for(;u.getTime()<=d;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+on),g=n.dateToX(r)-p;this.fillRect(p,s,g,o,i.timelineWeekendBg)}u.setTime(u.getTime()+on)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=oi;for(const u of l){const d=this.snapToPixel(u);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,d=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+on),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:d}=this,h=o.barBorderRadius;for(const p of n){const r=p.x,c=p.barY-a+l,g=p.width,y=p.barHeight;if(!(c+y<l||c>l+u)){if(p.isMilestone){this.renderMilestone(r,c,y,p.color,o,t.selectedIds.has(p.taskId));continue}if(this.fillRoundedRect(r,c,g,y,h,p.color),s.showProgress&&p.progressWidth>0){const T=this.darkenColor(p.color,.2);d.save(),d.beginPath(),this.roundedRectPath(r,c,g,y,h),d.clip(),d.fillStyle=T,d.fillRect(r,c,p.progressWidth,y),d.restore()}t.selectedIds.has(p.taskId)&&this.strokeRoundedRect(r,c,g,y,h,o.barSelectedBorder,ns),this.renderBarLabel(p,r,c,g,y,o)}}}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-ii*2)/2,d=n+s/2;l.save(),l.beginPath(),l.moveTo(t,d-u),l.lineTo(t+u,d),l.lineTo(t,d+u),l.lineTo(t-u,d),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=ns,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const d=l.measureText(t.label).width,h=s+i/2;d+ts*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+ts,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+ai,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=si,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const d=u.length||2,h=l/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<u.length;c++){const g=u[c],y=c*h;for(const T of g){const f=T.x-o,b=T.width;if(f+b<0||f>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=es;const v=this.snapToPixelRaw(f+b);i.moveTo(v,y),i.lineTo(v,y+h),i.stroke(),i.save(),i.beginPath(),i.rect(f,y,b,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(T.label,f+b/2,y+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=es,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const ss="ng-tree-grid-styles";function li(e,t){const n=e.querySelector(`#${ss}`);n&&n.remove();const s=document.createElement("style");s.id=ss,s.textContent=`
    .ng-grid {
      height: 100%;
      overflow: hidden;
      border-right: 1px solid ${t.gridBorderColor};
      background: ${t.gridBg};
      font-family: ${t.fontFamily};
      font-size: ${t.fontSize}px;
      color: ${t.gridTextColor};
      display: flex;
      flex-direction: column;
      user-select: none;
      -webkit-user-select: none;
      box-sizing: border-box;
    }

    .ng-grid *, .ng-grid *::before, .ng-grid *::after {
      box-sizing: border-box;
    }

    .ng-grid table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
    }

    /* ── Header ──────────────────────────────────────────────────────────── */

    .ng-grid-header {
      flex-shrink: 0;
      overflow: hidden;
      background: ${t.gridHeaderBg};
      color: ${t.gridHeaderText};
      border-bottom: 1px solid ${t.gridBorderColor};
      z-index: 2;
    }

    .ng-grid-th {
      position: relative;
      padding: 0 8px;
      text-align: left;
      font-weight: 600;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      border-right: 1px solid ${t.gridBorderColor};
      vertical-align: middle;
    }

    .ng-grid-th:last-child {
      border-right: none;
    }

    /* ── Resize Handle ───────────────────────────────────────────────────── */

    .ng-resize-handle {
      position: absolute;
      top: 0;
      right: 0;
      width: 5px;
      height: 100%;
      cursor: col-resize;
      z-index: 3;
    }

    .ng-resize-handle:hover {
      background: ${t.selectionColor};
    }

    /* ── Body ────────────────────────────────────────────────────────────── */

    .ng-grid-body {
      flex: 1;
      overflow: hidden;
      position: relative;
    }

    .ng-grid-body-inner {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
    }

    /* ── Rows ────────────────────────────────────────────────────────────── */

    .ng-grid-row {
      cursor: pointer;
      border-bottom: 1px solid ${t.gridBorderColor};
    }

    .ng-grid-row:hover {
      background: ${t.gridHoverBg};
    }

    .ng-row-alt {
      background: ${t.gridAltRowBg};
    }

    .ng-row-alt:hover {
      background: ${t.gridHoverBg};
    }

    .ng-row-selected {
      background: ${t.selectionColor} !important;
    }

    /* ── Cells ───────────────────────────────────────────────────────────── */

    .ng-grid-cell {
      padding: 0 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      vertical-align: middle;
      border-right: 1px solid ${t.gridBorderColor};
      line-height: 1;
    }

    .ng-grid-cell:last-child {
      border-right: none;
    }

    /* ── Tree Cell ───────────────────────────────────────────────────────── */

    .ng-tree-cell {
      display: flex;
      align-items: center;
      overflow: hidden;
    }

    .ng-tree-cell > .ng-grid-cell-text {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      flex: 1;
      min-width: 0;
    }

    /* ── Expand Icon ─────────────────────────────────────────────────────── */

    .ng-expand-icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 16px;
      height: 16px;
      flex-shrink: 0;
      cursor: pointer;
      font-size: 10px;
      opacity: 0.65;
      transition: transform 0.15s ease;
      margin-right: 4px;
    }

    .ng-expand-icon:hover {
      opacity: 1;
    }

    .ng-expand-icon.ng-expanded {
      transform: rotate(90deg);
    }

    .ng-expand-spacer {
      display: inline-block;
      width: 16px;
      flex-shrink: 0;
      margin-right: 4px;
    }
  `,e.prepend(s)}function ci(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Ct(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class di{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;li(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=ci(n),u=l.map(d=>d.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,u.appendChild(d);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=d=>{const h=d.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),c[n]&&(c[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const d of t)l.set(d.task.id,d);for(const[d,h]of this.rows)a.has(d)||(h.remove(),this.rows.delete(d));let u=null;for(let d=0;d<t.length;d++){const h=t[d],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,d,s):(r=this.createRow(h,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const d=this.createCell(t,u,s);l.appendChild(d)}return l}createCell(t,n,s){const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const i=t.depth*20+8;if(o.style.paddingLeft=`${i}px`,t.children.length>0){const l=document.createElement("span");l.className="ng-expand-icon",t.expanded&&l.classList.add("ng-expanded"),l.innerHTML="&#9654;",l.setAttribute("data-expand",t.task.id),o.appendChild(l)}else{const l=document.createElement("span");l.className="ng-expand-spacer",o.appendChild(l)}const a=document.createElement("span");a.className="ng-grid-cell-text",a.textContent=Ct(t.task,n),o.appendChild(a)}else o.textContent=Ct(t.task,n);return o}updateRowContent(t,n,s,o){const{config:i}=o,{columns:a}=i;s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt"),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let u=0;u<a.length;u++){const d=a[u],h=l[u];if(!h){const p=this.createCell(n,d,o);t.appendChild(p);continue}if(d.tree){const p=n.depth*20+8;h.style.paddingLeft=`${p}px`;const r=h.querySelector(".ng-expand-icon"),c=h.querySelector(".ng-expand-spacer");if(n.children.length>0)if(r)n.expanded?r.classList.add("ng-expanded"):r.classList.remove("ng-expanded");else{c&&c.remove();const y=document.createElement("span");y.className="ng-expand-icon",n.expanded&&y.classList.add("ng-expanded"),y.innerHTML="&#9654;",y.setAttribute("data-expand",n.task.id),h.insertBefore(y,h.firstChild)}else if(r){r.remove();const y=document.createElement("span");y.className="ng-expand-spacer",h.insertBefore(y,h.firstChild)}const g=h.querySelector(".ng-grid-cell-text");if(g){const y=Ct(n.task,d);g.textContent!==y&&(g.textContent=y)}}else{const p=Ct(n.task,d);h.textContent!==p&&(h.textContent=p)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class ui{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class os{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const is=864e5;function an(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/is)}function ht(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function st(e,t){const n=ht(e),s=new Date(n.getTime()+t*is),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function gi(e,t,n){return Math.max(t,Math.min(n,e))}const hi=3,fi=300;class pi{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=t,this.options=n,this.hitTest=new os,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none")return;t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l&&(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(t.pointerId),this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly)){const u=mi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s})}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<hi?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<fi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var l,u,d,h,p,r,c,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale();n.config;const i=this.dragHit.type,a=t.clientX-this.dragStartX;switch(i){case"bar":{const y=an(a,o),T=st(this.dragOriginalStartDate,y),f=st(this.dragOriginalEndDate,y);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:T,endDate:f}),(u=(l=this.options).onTaskMove)==null||u.call(l,s,T,f);break}case"bar-left-edge":{const y=an(a,o),T=st(this.dragOriginalStartDate,y),f=ht(this.dragOriginalEndDate),v=ht(T).getTime()>=f.getTime()?st(this.dragOriginalEndDate,-1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:v,endDate:this.dragOriginalEndDate}),(h=(d=this.options).onTaskResize)==null||h.call(d,s,v,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=an(a,o),T=st(this.dragOriginalEndDate,y),f=ht(this.dragOriginalStartDate),v=ht(T).getTime()<=f.getTime()?st(this.dragOriginalStartDate,1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:v}),(r=(p=this.options).onTaskResize)==null||r.call(p,s,this.dragOriginalStartDate,v);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:T}=this.toCanvasCoords(t),f=T-y.x,b=gi(f/y.width,0,1),v=Math.round(b*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:v}}),(g=(c=this.options).onTaskProgressChange)==null||g.call(c,s,v);break}}this.options.dispatch({type:"DRAG_END"})}}function mi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const ot=12,It=6,Mt=4,Ti=3;class as{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const c=d.get(r.source),g=d.get(r.target);if(!c||!g)continue;const y=r.type||"FS",{sourceX:T,sourceY:f,targetX:b,targetY:v}=this.getConnectionPoints(y,c,g,a,l);this.drawRoutedPath(t,y,T,f,b,v,o),this.drawArrowhead(t,y,b,v,o),this.drawConnectionDot(t,T,f,o),this.drawConnectionDot(t,b,v,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",d=n==="FS"||n==="SS",h=u?s+ot:s-ot,p=d?i-ot:i+ot;if(u?d?p>=h:i+ot>=h:d?i-ot<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(h,o),t.lineTo(h,c),t.lineTo(p,c),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-It,o-Mt),t.lineTo(s-It,o+Mt)):(t.moveTo(s,o),t.lineTo(s+It,o-Mt),t.lineTo(s+It,o+Mt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Ti,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const At=12,yi=100,bi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],vi=`
.ng-tooltip {
  position: absolute;
  z-index: 1000;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 0;
  pointer-events: none;
  font-size: 12px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  min-width: 180px;
  max-width: 280px;
  opacity: 0;
  transform: translateY(4px);
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.ng-tooltip.ng-tooltip-visible {
  opacity: 1;
  transform: translateY(0);
}
.ng-tooltip-header {
  padding: 8px 10px;
  border-bottom: 1px solid #f3f4f6;
  font-weight: 600;
  color: #111827;
}
.ng-tooltip-body {
  padding: 6px 10px;
}
.ng-tooltip-row {
  display: flex;
  justify-content: space-between;
  padding: 2px 0;
}
.ng-tooltip-label {
  color: #6b7280;
}
.ng-tooltip-value {
  color: #111827;
  font-weight: 500;
}
`;function it(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function rs(e){const t=e.split("-");if(t.length!==3)return it(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?it(e):`${bi[n]} ${s}`}function ft(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${it(e)}</span><span class="ng-tooltip-value">${it(t)}</span></div>`}function Si(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=ft("Status",e.status||"None"),i+=ft("Assignee",e.assignee||"Unassigned"),i+=ft("Dates",`${rs(e.startDate)} → ${rs(e.endDate)}`),n>0&&(i+=ft("Progress",`${n}%`)),s!=null&&(i+=ft("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${it(t)}"><span class="ng-tooltip-name">${it(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class ls{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=vi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const d=this.customRenderer(t);typeof d=="string"?this.tooltipEl.innerHTML=d:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(d))}else this.tooltipEl.innerHTML=Si(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+At,u=s+At;l+i.width>a.width&&(l=n-At-i.width),u+i.height>a.height&&(u=s-At-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},yi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const rn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},cs={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},wi=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function ds(e){const t=Ei(e.theme);return{columns:e.columns??wi,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function Ei(e){return!e||e==="light"?{...rn}:e==="dark"?{...cs}:{...rn,...e}}const us="nimbus-gantt-root-styles";function Di(){if(typeof document>"u"||document.getElementById(us))return;const e=document.createElement("style");e.id=us,e.textContent=`
    .nimbus-gantt {
      display: flex;
      width: 100%;
      height: 100%;
      overflow: hidden;
      position: relative;
      font-family: var(--ng-font-family);
    }
    .ng-grid-panel {
      flex-shrink: 0;
      overflow: hidden;
      border-right: 1px solid var(--ng-border-color);
    }
    .ng-timeline-panel {
      flex: 1;
      overflow: hidden;
      position: relative;
    }
  `,document.head.appendChild(e)}class ki{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.renderScheduled=!1,this.destroyed=!1,this.container=t,this.config=ds(n),Di(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=Oe(s,i),u=ut(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new Kn,this.store=new Vn(d),this.layoutEngine=new Qn,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new ri(this.timelinePanel),this.treeGrid=new di(this.gridPanel),this.scrollManager=new ui(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new as,this.tooltipManager=new ls(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new pi(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,c,g)=>{p?this.tooltipManager.show(p,r,c,g):this.tooltipManager.hide()},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight}))}this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container),this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const d=u.getContext("2d");d&&l.renderCanvas(d,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){this.destroyed=!0,this.resizeObserver.disconnect(),this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new Zn(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const t=this.store.getState(),{tree:n,flatIds:s}=Oe(t.tasks,t.expandedIds);t.tree=n,t.flatVisibleIds.length=0;for(const o of s)t.flatVisibleIds.push(o)}}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new Vn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}const Ci=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ln(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Ii(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function d(c){s.push(c),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const c=ln(n.getState()),g=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const c=ln(n.getState()),g=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),p()):(c.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(c){n=c,u=c.on("render",()=>{if(l)return;const g=document.querySelector(".nimbus-gantt");g&&(l=g.parentElement??g,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,g){if(i){g(c);return}if(Ci.has(c.type)&&n){const y=ln(n.getState());d(y),o=[]}g(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const pt=["day","week","month","quarter"];function Mi(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function cn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Ai(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=Mi(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d>0&&e.dispatch({type:"SELECT_TASK",taskId:l[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[d+1]})}break}case"ArrowRight":{if(u)if(cn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(u)if(cn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!u)return;i.preventDefault();const d=a.tasks.get(u);if(d&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const d=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=pt.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:pt[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=pt.indexOf(a.zoomLevel);d<pt.length-1&&e.dispatch({type:"SET_ZOOM",level:pt[d+1]});break}case" ":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;cn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const gs="#D4A017",Li="rgba(212, 160, 23, 0.25)",Ri=[6,4],Pi=1,$i=2,_i=4,hs=8,fs=10,ps=16,Ni=6;function Oi(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const c=r.x,g=r.barY-a,y=r.barHeight,T=g+y/2,f=r.color===l.barDefaultColor?gs:r.color||gs;t.save(),t.beginPath(),t.strokeStyle=Li,t.lineWidth=Pi,t.setLineDash(Ri),t.moveTo(c,h),t.lineTo(c,h+p),t.stroke(),t.setLineDash([]),t.restore();const b=(y-$i*2)/2;t.save(),t.beginPath(),t.moveTo(c,T-b),t.lineTo(c+b,T),t.lineTo(c,T+b),t.lineTo(c-b,T),t.closePath(),t.fillStyle=f,t.fill(),t.strokeStyle=ms(f,.25),t.lineWidth=1,t.stroke(),t.restore();const v=c+b+_i,m=T-ps/2;if(t.save(),t.beginPath(),t.strokeStyle=ms(f,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+ps),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+hs,m+fs/2),t.lineTo(v,m+fs),t.closePath(),t.fillStyle=f,t.fill(),t.restore(),r.label){const w=v+hs+Ni,k=T;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,w,k),t.restore()}}t.restore()},destroy(){e=null}}}function ms(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Hi="rgba(100, 116, 139, 0.12)",xi="rgba(100, 116, 139, 0.25)",Ts="#334155",Bi="rgba(100, 116, 139, 0.2)",Fi="#475569",Yi=8,Ui=6,Wi=2,Xe=5,Xi=12,zi=28,Gi=8;function Vi(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(h){const p=new Map,r=[];for(const c of h.flatVisibleIds){const g=h.tasks.get(c);if(g)if(g.groupId){let y=p.get(g.groupId);y||(y={groupId:g.groupId,groupName:g.groupName||g.groupId,taskIds:[],collapsed:t.has(g.groupId)},p.set(g.groupId,y)),y.taskIds.push(c)}else r.push(c)}n=Array.from(p.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const g=o.length,y=`__group_header__${c.groupId}`;if(o.push(y),s.set(g,c),!c.collapsed)for(const T of c.taskIds)o.push(T)}}function d(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const c=e.getState(),g=p.querySelector(".ng-timeline-panel");if(!g)return;const y=g.getBoundingClientRect(),T=r.clientY-y.top,f=c.config.headerHeight;if(T<f)return;const b=T-f+c.scrollY,v=Math.floor(b/c.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),d(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let c=!1;for(const g of r.tasks.values())if(g.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const g=new Set;for(const y of n)if(y.collapsed)for(const T of y.taskIds)g.add(T);if(g.size>0){const y=r.flatVisibleIds.filter(T=>!g.has(T));if(y.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const T of y)r.flatVisibleIds.push(T)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:c,scrollX:g,scrollY:y}=p,{theme:T}=c,f=c.headerHeight,b=c.rowHeight,v=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-f;h.save(),h.beginPath(),h.rect(0,f,v,m),h.clip();let w=0;const k=[];for(const S of p.flatVisibleIds){const D=p.tasks.get(S);D&&!D.groupId&&k.push(S)}w=k.length;for(const S of n){const D=f+w*b-y;if(D+b>=f&&D<f+m){h.fillStyle=Hi,h.fillRect(0,D,v,b),h.beginPath(),h.strokeStyle=xi,h.lineWidth=1,h.moveTo(0,Math.round(D+b)+.5),h.lineTo(v,Math.round(D+b)+.5),h.stroke();const E=Xi,I=D+b/2;h.save(),h.beginPath(),h.fillStyle=Ts,S.collapsed?(h.moveTo(E,I-Xe),h.lineTo(E+Xe,I),h.lineTo(E,I+Xe)):(h.moveTo(E-Xe/2,I-Xe/2),h.lineTo(E+Xe/2,I-Xe/2),h.lineTo(E,I+Xe/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${T.fontSize}px ${T.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=Ts;const M=zi,R=D+b/2;h.fillText(S.groupName,M,R);const _=h.measureText(S.groupName).width;h.restore();const x=`${S.taskIds.length}`;h.save(),h.font=`${T.fontSize-1}px ${T.fontFamily}`;const N=h.measureText(x).width+Ui*2,Y=T.fontSize+Wi*2,W=M+_+Gi,K=R-Y/2;h.beginPath();const q=Yi;h.moveTo(W+q,K),h.lineTo(W+N-q,K),h.arcTo(W+N,K,W+N,K+q,q),h.lineTo(W+N,K+Y-q),h.arcTo(W+N,K+Y,W+N-q,K+Y,q),h.lineTo(W+q,K+Y),h.arcTo(W,K+Y,W,K+Y-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=Bi,h.fill(),h.fillStyle=Fi,h.textBaseline="middle",h.textAlign="center",h.fillText(x,W+N/2,R),h.restore()}w+=1,S.collapsed||(w+=S.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const at="__bucket_header__";function ys(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Ki(e){return e.groupId??null}function ji(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function qi(e){const t=[...e.buckets].sort((r,c)=>r.order-c.order),n=new Map;t.forEach((r,c)=>n.set(r.id,c));const s=e.getBucket??Ki,o=e.getBucketProgress??ji,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function d(r,c){l=t.map(g=>({config:g,taskIds:[],allTaskIds:[],collapsed:i.has(g.id),progress:0,startDate:null,endDate:null,totalHours:0}));for(const g of c){const y=r.tasks.get(g);if(!y)continue;const T=s(y);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].taskIds.push(g)}for(const[g,y]of r.tasks){if(g.startsWith(at))continue;const T=s(y);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].allTaskIds.push(g)}for(const g of l){if(g.allTaskIds.length===0){g.progress=0,g.startDate=null,g.endDate=null,g.totalHours=0;continue}const y=[];let T=1/0,f=-1/0,b=0;for(const v of g.allTaskIds){const m=r.tasks.get(v);if(!m)continue;if(y.push(m),m.startDate){const k=gt(m.startDate).getTime();!isNaN(k)&&k<T&&(T=k)}if(m.endDate){const k=gt(m.endDate).getTime();!isNaN(k)&&k>f&&(f=k)}const w=m.metadata;typeof(w==null?void 0:w.hoursHigh)=="number"&&(b+=w.hoursHigh)}g.startDate=isFinite(T)?new Date(T):null,g.endDate=isFinite(f)?new Date(f):null,g.totalHours=b,g.progress=Math.max(0,Math.min(1,o(y)))}}function h(r){if(!r.startDate||!r.endDate)return null;const c=Math.round(r.progress*100),g=r.totalHours>0?`${r.totalHours}h (${c}%)`:`${r.allTaskIds.length} items`;return{id:`${at}${r.config.id}`,name:g,startDate:ys(r.startDate),endDate:ys(r.endDate),progress:r.progress,color:r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const c=a.getState();a.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...c)=>{const g=c[0];let y=null;typeof g=="string"?y=g:g&&typeof g=="object"&&"id"in g&&(y=String(g.id)),y&&y.startsWith(at)&&p(y.substring(at.length))}))},middleware(r,c){if(c(r),!a)return;const g=a.getState(),y=[];for(const b of g.tasks.keys())b.startsWith(at)&&y.push(b);for(const b of y)g.tasks.delete(b);const T=g.flatVisibleIds.filter(b=>!b.startsWith(at));let f=!1;for(const b of g.tasks.values())if(s(b)!=null){f=!0;break}if(!f){if(l=[],T.length!==g.flatVisibleIds.length){g.flatVisibleIds.length=0;for(const b of T)g.flatVisibleIds.push(b)}return}d(g,T);for(const b of l){if(b.allTaskIds.length===0)continue;const v=h(b);if(v){g.tasks.set(v.id,v);for(const m of b.allTaskIds){const w=g.tasks.get(m);w&&(w.parentId=v.id)}b.collapsed?g.expandedIds.delete(v.id):g.expandedIds.add(v.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const Zi=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function Ji(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const bs=864e5,Qi=6,ea=2,ta=2,na=.18,sa=.4;function vs(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function dn(e,t){return Math.round((t.getTime()-e.getTime())/bs)}function rt(e,t){return new Date(e.getTime()+t*bs)}function un(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const M=E.lag||0;s.get(E.source).push({target:E.target,lag:M,depId:E.id}),o.get(E.target).push({source:E.source,lag:M,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[E,I]of e){const M=vs(I.startDate),R=vs(I.endDate);l.set(E,M),u.set(E,R),a.set(E,Math.max(dn(M,R),0))}const d=new Map,h=new Map,p=[],r=[],c=new Map(i);for(const E of n)c.get(E)===0&&(r.push(E),d.set(E,l.get(E)),h.set(E,u.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),d.get(E);const I=h.get(E);for(const M of s.get(E)){const{target:R,lag:_}=M,x=rt(I,_),O=d.get(R);(!O||x.getTime()>O.getTime())&&(d.set(R,x),h.set(R,rt(x,a.get(R))));const N=c.get(R)-1;c.set(R,N),N===0&&r.push(R)}}for(const E of n)d.has(E)||(d.set(E,l.get(E)),h.set(E,u.get(E)),p.push(E));let g=-1/0;for(const E of h.values())E.getTime()>g&&(g=E.getTime());const y=new Date(g);let T=1/0;for(const E of d.values())E.getTime()<T&&(T=E.getTime());const f=new Date(T),b=dn(f,y),v=new Map,m=new Map;for(const E of n)s.get(E).length===0&&(m.set(E,y),v.set(E,rt(y,-a.get(E))));for(let E=p.length-1;E>=0;E--){const I=p[E];if(!m.has(I)){let M=1/0;for(const R of s.get(I)){const _=v.get(R.target);if(_){const x=rt(_,-R.lag);x.getTime()<M&&(M=x.getTime())}}M===1/0?m.set(I,y):m.set(I,new Date(M)),v.set(I,rt(m.get(I),-a.get(I)))}}for(const E of n)m.has(E)||(m.set(E,y),v.set(E,rt(y,-a.get(E))));const w=.5,k=new Set,S=new Map;for(const E of n){const I=d.get(E),M=h.get(E),R=v.get(E),_=m.get(E),x=dn(I,R),O=Math.abs(x)<w;O&&k.add(E),S.set(E,{earlyStart:I,earlyFinish:M,lateStart:R,lateFinish:_,totalFloat:x,isCritical:O})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&k.has(E.source)&&k.has(E.target)&&D.add(E.id);return{criticalTaskIds:k,criticalDependencyIds:D,taskAnalysis:S,projectDuration:b}}function oa(){let e,t=null,n=[];function s(){const o=e.getState();t=un(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:d,barHeight:h}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,g=u,y=e.getTimeScale(),T=new Map;for(const m of a)T.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,g,o.canvas.width,o.canvas.height-g),o.clip(),o.translate(-r,0);for(const m of a){const w=t.taskAnalysis.get(m.taskId);if(!w||w.isCritical||w.totalFloat<=0)continue;const k=m.barY-c,S=h*sa,D=m.x+m.width,I=y.dateToX(w.lateFinish)-D;I>1&&(o.fillStyle=m.color,o.globalAlpha=na,o.fillRect(D,k+h-S,I,S),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const w=m.x,k=m.barY-c,S=m.width,D=m.barHeight;if(!(k+D<g||k>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Qi;for(let E=0;E<ea;E++){o.strokeStyle=p,o.lineWidth=ta,o.beginPath();const I=l.barBorderRadius,M=Math.min(I,S/2,D/2);o.moveTo(w+M,k),o.lineTo(w+S-M,k),o.arcTo(w+S,k,w+S,k+M,M),o.lineTo(w+S,k+D-M),o.arcTo(w+S,k+D,w+S-M,k+D,M),o.lineTo(w+M,k+D),o.arcTo(w,k+D,w,k+D-M,M),o.lineTo(w,k+M),o.arcTo(w,k,w+M,k,M),o.closePath(),o.stroke()}o.restore()}}const f=6,b=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const w=T.get(m.source),k=T.get(m.target);if(!w||!k)continue;const S=w.x+w.width,D=w.barY+w.barHeight/2-c,E=k.x,I=k.barY+k.barHeight/2-c;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=S+v,R=E-v;if(o.moveTo(S,D),R>=M)o.lineTo(M,D),o.lineTo(M,I),o.lineTo(E,I);else{const _=(D+I)/2;o.lineTo(M,D),o.lineTo(M,_),o.lineTo(R,_),o.lineTo(R,I),o.lineTo(E,I)}o.stroke(),o.beginPath(),o.moveTo(E,I),o.lineTo(E-f,I-b),o.lineTo(E-f,I+b),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const ia=864e5,aa=.6,Ss=.25,ra="#38A169",la="#E53E3E",ca="#A0AEC0",da=10,ua=4,ze=16,ga=3;function Lt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ha(e,t){return Math.round((t.getTime()-e.getTime())/ia)}function fa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:Lt(s.startDate),end:Lt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var y,T;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,d=o.scrollX,h=o.scrollY,p=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const g=u*aa;for(const f of i){if(f.isMilestone)continue;const b=t.get(f.taskId);if(!b)continue;const v=f.barY-h;if(v+u+g<p||v>s.canvas.height)continue;const m=r.dateToX(b.start),w=r.dateToX(b.end),k=Math.max(w-m,2),S=v+u+1;Lt(((y=o.tasks.get(f.taskId))==null?void 0:y.startDate)||"");const D=Lt(((T=o.tasks.get(f.taskId))==null?void 0:T.endDate)||""),E=ha(b.end,D);let I;E<0?I=ra:E>0?I=la:I=ca,s.save(),s.globalAlpha=Ss,s.fillStyle=I;const M=Math.min(c,k/2,g/2);if(s.beginPath(),s.moveTo(m+M,S),s.lineTo(m+k-M,S),s.arcTo(m+k,S,m+k,S+M,M),s.lineTo(m+k,S+g-M),s.arcTo(m+k,S+g,m+k-M,S+g,M),s.lineTo(m+M,S+g),s.arcTo(m,S+g,m,S+g-M,M),s.lineTo(m,S+M),s.arcTo(m,S,m+M,S,M),s.closePath(),s.fill(),s.globalAlpha=Ss*2,s.strokeStyle=I,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const R=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${da}px ${a.fontFamily}`;const O=s.measureText(R).width+ua*2,N=f.x+f.width+4,Y=S+(g-ze)/2;s.globalAlpha=.85,s.fillStyle=I;const W=ga;s.beginPath(),s.moveTo(N+W,Y),s.lineTo(N+O-W,Y),s.arcTo(N+O,Y,N+O,Y+W,W),s.lineTo(N+O,Y+ze-W),s.arcTo(N+O,Y+ze,N+O-W,Y+ze,W),s.lineTo(N+W,Y+ze),s.arcTo(N,Y+ze,N,Y+ze-W,W),s.lineTo(N,Y+W),s.arcTo(N,Y,N+W,Y,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(R,N+O/2,Y+ze/2),s.restore()}}s.restore()},destroy(){}}}const ws=5,pa=5,ma=.3,Ta=15;function ya(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:h,headerHeight:p}=d.config,r=d.scrollY,c=d.flatVisibleIds.length,g=a(d),y=Math.floor(r/h),T=Math.ceil((r+g)/h);let f=Math.max(0,y-ws),b=Math.min(c,T+ws);if(Math.abs(s)>0){const m=Math.min(Ta,Math.ceil(Math.abs(s*ma)/h));s>0?b=Math.min(c,b+m):f=Math.max(0,f-m)}const v=new Set;for(let m=f;m<b&&m<d.flatVisibleIds.length;m++)v.add(d.flatVisibleIds[m]);return{startRow:f,endRow:b,totalRows:c,visibleTaskIds:v}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function l(d){const h=performance.now();for(o.push({y:d,time:h});o.length>pa;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],c=(r.time-p.time)/1e3;c>0&&(s=(r.y-p.y)/c)}n=d}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(l(d.scrollY),t=i(d)),t},filterLayouts(d){const h=u.getVisibleRange();return h.totalRows===0?[]:d.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(d){return u.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,h){if(h(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const He=864e5,gn=1,Es=2,Ds=.5,ks=2,Rt=8,Cs=6,Is=2,Pt=1e4;function hn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Ms(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Qe(e){return Math.round(e)+.5}function As(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Ls(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const c=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,c,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const c=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let g=0;e.fillStyle=i.gridTextColor;for(const y of a){const T=y.width??120,f=As(r,y.field);e.save(),e.beginPath(),e.rect(g,c,T,l),e.clip(),e.textBaseline="middle";const b=y.tree?8:0;e.textAlign=y.align==="right"?"right":y.align==="center"?"center":"left";const v=y.align==="right"?g+T-8:y.align==="center"?g+T/2:g+8+b;e.fillText(f,v,c+l/2),e.restore(),g+=T}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Rs(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,d=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:g,end:y}=t.dateRange,T=new Date(g);T.setUTCHours(0,0,0,0);const f=y.getTime();for(;T.getTime()<=f;){const b=T.getUTCDay();if(b===0||b===6){const v=o+s.dateToX(T),m=new Date(T.getTime()+He),w=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,l,w-v,h)}T.setTime(T.getTime()+He)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Ds;for(const g of r){const y=Qe(o+g);e.moveTo(y,l),e.lineTo(y,p)}e.stroke();for(let g=0;g<t.flatVisibleIds.length;g++)g%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+g*u,d,u));if(i.showToday){const g=new Date;g.setHours(0,0,0,0);const{start:y,end:T}=t.dateRange;if(g.getTime()>=y.getTime()&&g.getTime()<=T.getTime()){const f=o+s.dateToX(g),b=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(f,l,b,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Es,e.moveTo(Qe(f),l),e.lineTo(Qe(f),p),e.stroke()}}const c=a.barBorderRadius;for(const g of n){const y=o+g.x,T=g.barY,f=g.width,b=g.barHeight;if(g.isMilestone){const v=(b-ks*2)/2,m=T+b/2;e.beginPath(),e.moveTo(y,m-v),e.lineTo(y+v,m),e.lineTo(y,m+v),e.lineTo(y-v,m),e.closePath(),e.fillStyle=g.color,e.fill();continue}if(fn(e,y,T,f,b,c),e.fillStyle=g.color,e.fill(),i.showProgress&&g.progressWidth>0){const v=Ms(g.color,.2);e.save(),e.beginPath(),fn(e,y,T,f,b,c),e.clip(),e.fillStyle=v,e.fillRect(y,T,g.progressWidth,b),e.restore()}if(t.selectedIds.has(g.taskId)&&(e.beginPath(),fn(e,y,T,f,b,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Is,e.stroke()),g.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(g.label).width,m=T+b/2;v+Rt*2<=f?(e.beginPath(),e.rect(y,T,f,b),e.clip(),e.fillStyle=g.textColor,e.textAlign="left",e.fillText(g.label,y+Rt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(g.label,y+f+Cs,m)),e.restore()}}ba(e,t,n,a,o),va(e,s,i,a,o)}function ba(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,l=6,u=4;e.save();for(const d of t.dependencies.values()){const h=i.get(d.source),p=i.get(d.target);if(!h||!p)continue;const r=d.type||"FS",c=h.barY+h.barHeight/2,g=p.barY+p.barHeight/2;let y,T;const f=r==="FS"||r==="FF",b=r==="FS"||r==="SS";switch(r){case"FS":y=o+h.x+h.width,T=o+p.x;break;case"SS":y=o+h.x,T=o+p.x;break;case"FF":y=o+h.x+h.width,T=o+p.x+p.width;break;case"SF":y=o+h.x,T=o+p.x+p.width;break}const v=f?y+a:y-a,m=b?T-a:T+a,w=f?b?m>=v:T+a>=v:b?T-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(y,c),w)e.lineTo(v,c),e.lineTo(v,g),e.lineTo(T,g);else{const k=(c+g)/2;e.lineTo(v,c),e.lineTo(v,k),e.lineTo(m,k),e.lineTo(m,g),e.lineTo(T,g)}e.stroke(),e.beginPath(),b?(e.moveTo(T,g),e.lineTo(T-l,g-u),e.lineTo(T-l,g+u)):(e.moveTo(T,g),e.lineTo(T+l,g-u),e.lineTo(T+l,g+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function va(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let d=0;d<a.length;d++){const h=a[d],p=d*u;for(const r of h){const c=o+r.x,g=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=gn,e.moveTo(Qe(c+g),p),e.lineTo(Qe(c+g),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(c,p,g,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+g/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=gn,e.moveTo(o,Qe(i)),e.lineTo(o+t.getTotalWidth(),Qe(i)),e.stroke()}function fn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function mt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Sa(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),d=s+u,h=e.flatVisibleIds.length*l,p=a+h,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),c.push(`<style>text { font-family: ${mt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let g=0;for(const m of o.columns){const w=m.width??120;c.push(`<text x="${g+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${mt(m.header)}</text>`),c.push(`<line x1="${g+w}" y1="0" x2="${g+w}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),g+=w}for(let m=0;m<e.flatVisibleIds.length;m++){const w=e.tasks.get(e.flatVisibleIds[m]);if(!w)continue;const k=a+m*l;m%2===1&&c.push(`<rect x="0" y="${k}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let S=0;for(const D of o.columns){const E=D.width??120,I=As(w,D.field),M=D.tree?8:0;c.push(`<text x="${S+8+M}" y="${k+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${I}]]></text>`),S+=E}c.push(`<line x1="0" y1="${k+l}" x2="${s}" y2="${k+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const y=n.getHeaderRows(),T=y.length||2,f=a/T;for(let m=0;m<y.length;m++){const w=y[m],k=m*f;for(const S of w){const D=s+S.x+S.width/2,E=k+f/2,I=m===0?' font-weight="600"':"";c.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${I} fill="${i.timelineHeaderText}">${mt(S.label)}</text>`),c.push(`<line x1="${s+S.x+S.width}" y1="${k}" x2="${s+S.x+S.width}" y2="${k+f}" stroke="${i.timelineGridColor}" stroke-width="${gn}" />`)}}const b=n.getGridLines();for(const m of b)c.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Ds}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&c.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:w}=e.dateRange,k=new Date(m);for(k.setUTCHours(0,0,0,0);k.getTime()<=w.getTime();){if(k.getUTCDay()===0||k.getUTCDay()===6){const S=s+n.dateToX(k),D=new Date(k.getTime()+He),E=s+n.dateToX(D);c.push(`<rect x="${S}" y="${a}" width="${E-S}" height="${h}" fill="${i.timelineWeekendBg}" />`)}k.setTime(k.getTime()+He)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:w,end:k}=e.dateRange;if(m.getTime()>=w.getTime()&&m.getTime()<=k.getTime()){const S=s+n.dateToX(m),D=n.getColumnWidth();c.push(`<rect x="${S}" y="${a}" width="${D}" height="${h}" fill="${i.todayBg}" />`),c.push(`<line x1="${S}" y1="${a}" x2="${S}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${Es}" />`)}}for(const m of t){const w=s+m.x,k=m.barY,S=m.width,D=m.barHeight;if(m.isMilestone){const E=(D-ks*2)/2,I=k+D/2;c.push(`<polygon points="${w},${I-E} ${w+E},${I} ${w},${I+E} ${w-E},${I}" fill="${m.color}" />`);continue}if(c.push(`<rect x="${w}" y="${k}" width="${S}" height="${D}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const E=Ms(m.color,.2);c.push(`<clipPath id="clip-${m.taskId}"><rect x="${w}" y="${k}" width="${S}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${w}" y="${k}" width="${m.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&c.push(`<rect x="${w}" y="${k}" width="${S}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Is}" />`),m.label){const E=k+D/2;i.fontSize*.6*m.label.length+Rt*2<=S?c.push(`<text x="${w+Rt}" y="${E}" dominant-baseline="central" fill="${m.textColor}">${mt(m.label)}</text>`):c.push(`<text x="${w+S+Cs}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${mt(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const w=v.get(m.source),k=v.get(m.target);if(!w||!k)continue;const S=m.type||"FS",D=w.barY+w.barHeight/2,E=k.barY+k.barHeight/2;let I,M;const R=S==="FS"||S==="FF",_=S==="FS"||S==="SS";switch(S){case"FS":I=s+w.x+w.width,M=s+k.x;break;case"SS":I=s+w.x,M=s+k.x;break;case"FF":I=s+w.x+w.width,M=s+k.x+k.width;break;case"SF":I=s+w.x,M=s+k.x+k.width;break}const x=12,O=6,N=4,Y=R?I+x:I-x,W=_?M-x:M+x,K=R?_?W>=Y:M+x>=Y:_?M-x<=Y:W<=Y;let q;if(K)q=`M${I},${D} L${Y},${D} L${Y},${E} L${M},${E}`;else{const U=(D+E)/2;q=`M${I},${D} L${Y},${D} L${Y},${U} L${W},${U} L${W},${E} L${M},${E}`}c.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),_?c.push(`<polygon points="${M},${E} ${M-O},${E-N} ${M-O},${E+N}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${M},${E} ${M+O},${E-N} ${M+O},${E+N}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function wa(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:d,end:h}=l.dateRange,p=h.getTime()-d.getTime(),r=u.getColumnWidth(),c=l.zoomLevel;let g;switch(c){case"day":g=Math.round(p/He);break;case"week":g=Math.ceil(p/(He*7));break;case"month":{const T=d.getUTCFullYear(),f=d.getUTCMonth(),b=h.getUTCFullYear(),v=h.getUTCMonth();g=(b-T)*12+(v-f);break}case"quarter":{const T=d.getUTCFullYear(),f=Math.floor(d.getUTCMonth()/3),b=h.getUTCFullYear(),v=Math.floor(h.getUTCMonth()/3);g=(b-T)*4+(v-f);break}}const y=g*r;return{dateToX(T){return(T.getTime()-d.getTime())/p*y},getColumnWidth(){return r},getTotalWidth(){return y},getHeaderRows(){return ka(c,d,h,r,y)},getGridLines(){return this.getHeaderRows()[1].map(f=>f.x).filter(f=>f>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,c=l.flatVisibleIds.length*l.config.rowHeight,g=l.config.headerHeight+c,y=a??"gantt-export.png";if(r>Pt||g>Pt){o(l,d,u,h,r,g,y);return}const T=document.createElement("canvas");T.width=r,T.height=g;const f=T.getContext("2d");f&&(h>0&&Ls(f,l,h,g),Rs(f,l,d,u,h),T.toBlob(b=>{b&&hn(b,y)},"image/png"))}function o(a,l,u,d,h,p,r){const c=Math.min(1,Pt/h,Pt/p),g=Math.ceil(h*c),y=Math.ceil(p*c),T=document.createElement("canvas");T.width=g,T.height=y;const f=T.getContext("2d");f&&(f.scale(c,c),d>0&&Ls(f,a,d,p),Rs(f,a,l,u,d),T.toBlob(b=>{b&&hn(b,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=Sa(l,d,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});hn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const Ps=["January","February","March","April","May","June","July","August","September","October","November","December"],$s=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function _s(e,t){return new Date(e.getTime()+t*He)}function pn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Ea(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Da(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function ka(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Da(l,t,i,o);switch(e){case"day":{const l=[],u=[],d=Math.round(i/He);let h=new Date(t);for(let r=0;r<d;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=_s(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=pn(p),c=a(p),g=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${Ps[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:c,width:g-c,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],d=Math.ceil(i/(He*7));for(let p=0;p<d;p++){const r=_s(t,p*7);u.push({label:`${$s[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=pn(h),r=h.getTime()<t.getTime()?t:h,c=p.getTime()>n.getTime()?n:p;l.push({label:`${Ps[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),h=p}return[l,u]}case"month":{const l=[],u=[],d=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),c=(p-d)*12+(r-h);let g=new Date(Date.UTC(d,h,1));for(let T=0;T<c;T++)u.push({label:$s[g.getUTCMonth()],x:T*s,width:s,date:new Date(g)}),g=pn(g);let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const T=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),f=y.getTime()<t.getTime()?t:y,b=T.getTime()>n.getTime()?n:T;l.push({label:String(y.getUTCFullYear()),x:a(f),width:a(b)-a(f),date:new Date(f)}),y=T}return[l,u]}case"quarter":{const l=[],u=[],d=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(p-d)*4+(r-h);let g=new Date(Date.UTC(d,h*3,1));for(let T=0;T<c;T++){const f=Math.floor(g.getUTCMonth()/3)+1;u.push({label:`Q${f}`,x:T*s,width:s,date:new Date(g)}),g=Ea(g,3)}let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const T=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),f=y.getTime()<t.getTime()?t:y,b=T.getTime()>n.getTime()?n:T;l.push({label:String(y.getUTCFullYear()),x:a(f),width:a(b)-a(f),date:new Date(f)}),y=T}return[l,u]}default:return[[],[]]}}const Ca={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},mn="nimbus-gantt-dark-theme-transition";function Ia(){if(typeof document>"u"||document.getElementById(mn))return;const e=document.createElement("style");e.id=mn,e.textContent=`
    .nimbus-gantt,
    .nimbus-gantt .ng-grid-panel,
    .nimbus-gantt .ng-timeline-panel {
      transition: background-color 300ms ease, color 300ms ease, border-color 300ms ease;
    }
    .ng-grid,
    .ng-grid-header,
    .ng-grid-body,
    .ng-grid-row,
    .ng-grid-cell {
      transition: background-color 300ms ease, color 300ms ease, border-color 300ms ease;
    }
  `,document.head.appendChild(e)}function Ma(){if(typeof document>"u")return;const e=document.getElementById(mn);e&&e.remove()}function Aa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const g={...c.config.theme,...Ca};Object.assign(c.config.theme,g),s=!0,p()}function d(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,p()}function h(){s?d():u()}function p(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?u():d()}return{name:"DarkThemePlugin",install(c){n=c,Ia(),c.on("theme:toggle",()=>{h()}),c.on("theme:dark",()=>{u()}),c.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}Ma(),n=null,o=null,i=null,a=null,s=!1}}}const Ae=864e5,La=[1,2,3,4,5],Ra="rgba(128, 128, 128, 0.06)",Pa="rgba(128, 128, 128, 0.04)",$a="#f87171",Tt=4;function yt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function $e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function _a(e){const t=new Set((e==null?void 0:e.workDays)??La),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=$e(r);return t.has(c.getUTCDay())}function i(r){const c=yt(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=$e(r);for(c=new Date(c.getTime()+Ae);!i(c);)c=new Date(c.getTime()+Ae);return yt(c)}function l(r,c){if(c===0)return r;let g=$e(r);const y=c>0?1:-1;let T=Math.abs(c);if(!i(g))for(g=new Date(g.getTime()+y*Ae);!i(g);)g=new Date(g.getTime()+y*Ae);for(;T>0;)g=new Date(g.getTime()+y*Ae),i(g)&&T--;return yt(g)}function u(r,c){const g=$e(r),y=$e(c);if(g.getTime()>y.getTime())return-u(c,r);let T=0,f=new Date(g.getTime());for(;f.getTime()<y.getTime();)i(f)&&T++,f=new Date(f.getTime()+Ae);return T}function d(r,c="forward"){if(o(r))return r;let g=$e(r);const y=c==="forward"?Ae:-Ae;for(let T=0;T<30;T++)if(g=new Date(g.getTime()+y),i(g))return yt(g);return r}function h(r,c){if(r.type==="TASK_MOVE"){const g=d(r.startDate,"forward"),y=d(r.endDate,"backward"),T=$e(y).getTime()<$e(g).getTime()?g:y;c({...r,startDate:g,endDate:T});return}if(r.type==="TASK_RESIZE"){const g=d(r.startDate,"forward"),y=d(r.endDate,"backward"),T=$e(y).getTime()<$e(g).getTime()?g:y;c({...r,startDate:g,endDate:T});return}c(r)}function p(r,c,g){const{config:y}=c,T=y.headerHeight,f=c.flatVisibleIds.length*y.rowHeight,b=s==null?void 0:s.getTimeScale();if(!b||f===0)return;const{start:v,end:m}=c.dateRange,w=c.scrollX,k=c.scrollY;r.save();const S=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(S,0,0,S,0,0),r.beginPath(),r.rect(0,T,r.canvas.width/S,f),r.clip(),r.translate(-w,0);const D=new Date(v);D.setUTCHours(0,0,0,0);const E=m.getTime();for(b.getColumnWidth();D.getTime()<=E;){const I=yt(D),M=n.has(I),R=!t.has(D.getUTCDay());if(M||R){const _=b.dateToX(D),x=new Date(D.getTime()+Ae),N=b.dateToX(x)-_;if(r.fillStyle=Ra,r.fillRect(_,T-k,N,f+k),R&&!M){r.save(),r.beginPath(),r.rect(_,T,N,f),r.clip(),r.strokeStyle=Pa,r.lineWidth=1;const Y=8,W=f;for(let K=-W;K<N+W;K+=Y)r.beginPath(),r.moveTo(_+K,T),r.lineTo(_+K+W,T+W),r.stroke();r.restore()}}if(M){const _=b.dateToX(D),x=new Date(D.getTime()+Ae),O=b.dateToX(x),N=(_+O)/2;r.save(),r.setTransform(S,0,0,S,0,0),r.translate(-w,0);const Y=T-Tt-3;r.beginPath(),r.moveTo(N,Y-Tt),r.lineTo(N+Tt,Y),r.lineTo(N,Y+Tt),r.lineTo(N-Tt,Y),r.closePath(),r.fillStyle=$a,r.fill(),r.restore()}D.setTime(D.getTime()+Ae)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const g=c[0],y=c[1],T=c[2],f=l(g,y);T&&T(f)}),r.on("calendar:workDaysBetween",(...c)=>{const g=c[0],y=c[1],T=c[2],f=u(g,y);T&&T(f)}),r.on("calendar:isWorkDay",(...c)=>{const g=c[0],y=c[1],T=o(g);y&&y(T)}),r.on("calendar:nextWorkDay",(...c)=>{const g=c[0],y=c[1],T=a(g);y&&y(T)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function Na(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Oa(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function Ha(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=Na(),a=[],l=Date.now();let u=null,d=null,h=!1,p=[];const r=[];function c(m,w){if(h)return;const k={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:w};a.push(k),o&&o(k)}function g(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function y(){d===null&&(d=setInterval(()=>{g()},s))}function T(){d!==null&&(clearInterval(d),d=null)}const f=Oa(()=>{if(!u)return;const m=u.getState();c("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let b=0;function v(m,w){switch(m.type){case"SET_ZOOM":{const k=u?u.getState().zoomLevel:"unknown";w(m),c("gantt.zoom",{oldLevel:k,newLevel:m.level});return}case"TASK_MOVE":{const k=b>0?Date.now()-b:0;w(m),c("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:k}),b=0;return}case"TASK_RESIZE":{w(m),c("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{b=Date.now(),w(m);return}case"SELECT_TASK":{w(m),c("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{w(m),f();return}case"TOGGLE_EXPAND":{const k=u?u.getState().expandedIds.has(m.taskId):!1;w(m),c(k?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{w(m),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{w(m),c("gantt.collapse",{all:!0});return}default:w(m);return}}return{name:"TelemetryPlugin",install(m){u=m,y();const w=m.getState();c("gantt.init",{taskCount:w.tasks.size,dependencyCount:w.dependencies.size,zoomLevel:w.zoomLevel}),setTimeout(()=>{h||c("gantt.feature.used",{plugins:p})},0);const k=m.on("taskClick",(...S)=>{const D=S[0];D&&c("gantt.task.click",{taskId:D.id})});r.push(k)},middleware:v,destroy(){h=!0;const m=Date.now()-l;c("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),g(),T();for(const w of r)w();r.length=0,u=null}}}const Ns=5,Tn=.15,yn=.85,xa=2,Os=30,xe=["day","week","month","quarter"];function Hs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function Ba(e,t,n){return Math.max(t,Math.min(n,e))}function Fa(e){const t=Ba((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,d=0,h=0,p=0,r=null,c=null,g=null,y=null,T=null,f=null,b=0,v=0,m=0,w=!1;function k(O,N,Y){m=O,b=N,v=Y,w=!0,r===null&&(r=O)}function S(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(y=O=>{u||O.alpha==null||O.beta==null||O.gamma==null||k(O.alpha,O.beta,O.gamma)},window.addEventListener("deviceorientation",y),!0)}function D(){y&&(window.removeEventListener("deviceorientation",y),y=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function I(O){try{const N=JSON.parse(O);N.type==="orientation"?k(N.alpha,N.beta,N.gamma):N.type==="gesture"&&M(N.gesture)}catch{}}function M(O){if(!l)return;const N=l.getState();switch(O){case"tap":{N.selectedIds.size===0&&N.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:N.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const Y=xe.indexOf(N.zoomLevel);Y<xe.length-1&&l.dispatch({type:"SET_ZOOM",level:xe[Y+1]});break}case"swipe-right":{const Y=xe.indexOf(N.zoomLevel);Y>0&&l.dispatch({type:"SET_ZOOM",level:xe[Y-1]});break}}}function R(){if(u||typeof WebSocket>"u")return;const O=E();try{T=new WebSocket(O),T.onmessage=N=>{typeof N.data=="string"&&I(N.data)},T.onclose=()=>{T=null,u||(f=setTimeout(R,3e3))},T.onerror=()=>{T&&T.close()}}catch{u||(f=setTimeout(R,3e3))}}function _(){f!==null&&(clearTimeout(f),f=null),T&&(T.onmessage=null,T.onclose=null,T.onerror=null,T.close(),T=null)}function x(){if(!(u||!l)){if(w){d=d*yn+b*Tn,h=h*yn+v*Tn,p=p*yn+m*Tn;const O=l.getState(),N=xa*a;if(n){const Y=Hs(h,Ns);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const Y=Hs(d,Ns);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=xe.indexOf(O.zoomLevel);if(W>Os&&K>0){const q=xe[K-1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}else if(W<-Os&&K<xe.length-1){const q=xe[K+1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}}}g=requestAnimationFrame(x)}}return{name:"MotionControlPlugin",install(O){l=O,c=O.getState().zoomLevel,(!S()||i)&&R(),g=requestAnimationFrame(x)},destroy(){u=!0,g!==null&&(cancelAnimationFrame(g),g=null),D(),_(),l=null}}}const bt="http://schemas.microsoft.com/project",Ya=8,xs=4800,Ua={0:"FF",1:"FS",2:"SF",3:"SS"},Wa={FF:0,FS:1,SF:2,SS:3};function Bs(e){return e?e.substring(0,10):""}function Fs(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(bt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function Xa(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function za(e){return`PT${e*Ya}H0M0S`}function vt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function bn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(bt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let f=0;f<l.length;f++){const b=l[f],v=Ee(b,"UID"),m=Ee(b,"Name");v&&m&&i.set(v,m)}const u=new Map,d=o.getElementsByTagNameNS(bt,"Assignment"),h=d.length>0?d:o.getElementsByTagName("Assignment");for(let f=0;f<h.length;f++){const b=h[f],v=Ee(b,"TaskUID"),m=Ee(b,"ResourceUID");if(v&&m){const w=i.get(m);w&&u.set(v,w)}}const p=[],r=[],c=o.getElementsByTagNameNS(bt,"Task"),g=c.length>0?c:o.getElementsByTagName("Task"),y=[];let T=1;for(let f=0;f<g.length;f++){const b=g[f],v=Ee(b,"UID"),m=Ee(b,"Name"),w=Ee(b,"Start"),k=Ee(b,"Finish"),S=Ee(b,"PercentComplete"),D=Ee(b,"Summary")==="1",E=Ee(b,"Milestone")==="1",I=parseInt(Ee(b,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const M=`msp-${v}`,R=Bs(w),_=Bs(k);if(!R&&!E)continue;let x;I>0&&y[I-1]&&(x=y[I-1]),y[I]=M,y.length=I+1;const O={id:M,name:m||`Task ${v}`,startDate:R||_,endDate:_||R,progress:S?parseInt(S,10)/100:0,isMilestone:E,parentId:x,sortOrder:f},N=u.get(v);N&&(O.assignee=N),D&&(O.metadata={...O.metadata,isSummary:!0}),p.push(O);const Y=b.getElementsByTagNameNS(bt,"PredecessorLink"),W=Y.length>0?Y:b.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],U=Ee(q,"PredecessorUID"),C=parseInt(Ee(q,"Type")||"1",10),P=Ee(q,"LinkLag"),A=P?parseInt(P,10):0;if(!U||U==="0")continue;const $={id:`msp-dep-${T++}`,source:`msp-${U}`,target:M,type:Ua[C]??"FS",lag:A!==0?A/xs:void 0};r.push($)}}return{tasks:p,dependencies:r}}function vn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(v){let m=1,w=v;for(;w!=null&&w.parentId;)m++,w=e.tasks.get(w.parentId);return m}const d=new Map,h=new Map;for(const v of a){const m=v.parentId??"__root__",w=(d.get(m)??0)+1;if(d.set(m,w),!v.parentId)h.set(v.id,String(w));else{const k=h.get(v.parentId)??"0";h.set(v.id,`${k}.${w}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const c=new Map;for(const v of l){const m=c.get(v.target)??[];m.push(v),c.set(v.target,m)}const g=new Set;for(const v of a)v.assignee&&g.add(v.assignee);const y=Array.from(g),T=new Map;y.forEach((v,m)=>{T.set(v,m+1)});const f=[];f.push('<?xml version="1.0" encoding="UTF-8"?>'),f.push('<Project xmlns="http://schemas.microsoft.com/project">'),f.push(`  <Name>${vt(n)}</Name>`),f.push(`  <Author>${vt(s)}</Author>`),f.push(`  <CreationDate>${o}</CreationDate>`),f.push("  <CalendarUID>1</CalendarUID>"),f.push("  <Calendars>"),f.push("    <Calendar>"),f.push("      <UID>1</UID>"),f.push(`      <Name>${vt(i)}</Name>`),f.push("      <IsBaseCalendar>1</IsBaseCalendar>"),f.push("    </Calendar>"),f.push("  </Calendars>"),f.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,w=u(v),k=h.get(v.id)??"1",S=p.has(v.id),D=v.isMilestone??!1,E=Fs(v.startDate),I=Fs(v.endDate),M=Xa(E,I),R=za(M),_=Math.round((v.progress??0)*100);f.push("    <Task>"),f.push(`      <UID>${m}</UID>`),f.push(`      <ID>${m}</ID>`),f.push(`      <Name>${vt(v.name)}</Name>`),f.push(`      <Start>${v.startDate}T08:00:00</Start>`),f.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),f.push(`      <Duration>${R}</Duration>`),f.push(`      <PercentComplete>${_}</PercentComplete>`),f.push(`      <Summary>${S?"1":"0"}</Summary>`),f.push(`      <Milestone>${D?"1":"0"}</Milestone>`),f.push(`      <OutlineLevel>${w}</OutlineLevel>`),f.push(`      <OutlineNumber>${k}</OutlineNumber>`);const x=c.get(v.id);if(x)for(const O of x){const N=r.get(O.source)??0;if(N===0)continue;const Y=Wa[O.type??"FS"]??1,W=Math.round((O.lag??0)*xs);f.push("      <PredecessorLink>"),f.push(`        <PredecessorUID>${N}</PredecessorUID>`),f.push(`        <Type>${Y}</Type>`),f.push(`        <LinkLag>${W}</LinkLag>`),f.push("      </PredecessorLink>")}f.push("    </Task>")}f.push("  </Tasks>"),f.push("  <Resources>");for(const v of y){const m=T.get(v)??0;f.push("    <Resource>"),f.push(`      <UID>${m}</UID>`),f.push(`      <Name>${vt(v)}</Name>`),f.push("    </Resource>")}f.push("  </Resources>"),f.push("  <Assignments>");let b=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,w=T.get(v.assignee)??0;m===0||w===0||(f.push("    <Assignment>"),f.push(`      <UID>${b++}</UID>`),f.push(`      <TaskUID>${m}</TaskUID>`),f.push(`      <ResourceUID>${w}</ResourceUID>`),f.push("    </Assignment>"))}return f.push("  </Assignments>"),f.push("</Project>"),f.join(`
`)}function Ga(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var d;const u=(d=l.target)==null?void 0:d.result;if(!(!u||!e))try{const h=bn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=bn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),d=vn(u,a);l&&l(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),d=vn(u,a),h=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const Va=[4,3],Ka=1.5,ja=.5,qa=.06,Za=4,Ja=8,Qa=.35,er=1,Ys=.2,St=6,Us=864e5;function _e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ws(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Sn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function wn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function tr(e){let t=0;for(const n of e){const s=_e(n.startDate).getTime(),o=_e(n.endDate).getTime();t+=Math.max(o-s,Us)}return t}function nr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=_e(l.startDate).getTime(),h=_e(s.startDate).getTime()-u,p=i.segments.map(r=>{const c=new Date(_e(r.startDate).getTime()+h),g=new Date(_e(r.endDate).getTime()+h);return{startDate:Ws(c),endDate:Ws(g)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,d=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:d,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),c=d.barBorderRadius,g=h;s.save(),s.beginPath(),s.rect(0,g,s.canvas.width,s.canvas.height-g),s.clip(),s.translate(-l,0);for(const y of i){if(y.isMilestone)continue;const T=t.get(y.taskId);if(!T||T.segments.length===0)continue;const f=y.barY-u,b=y.barHeight,v=f+b/2;if(f+b<g||f>s.canvas.height)continue;const m=[];for(const I of T.segments){const M=r.dateToX(_e(I.startDate)),R=r.dateToX(_e(I.endDate)),_=Math.max(R-M,4);m.push({startX:M,endX:M+_,width:_})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(y.x-1,f-1,y.width+2,b+2),s.restore();for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX,_=R-M;if(!(_<=0)){s.save(),s.globalAlpha=qa,s.strokeStyle=y.color,s.lineWidth=Za,s.beginPath(),s.rect(M,f,_,b),s.clip();for(let x=M-b;x<R+b;x+=Ja)s.beginPath(),s.moveTo(x,f+b),s.lineTo(x+b,f),s.stroke();s.restore()}}for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX;s.save(),s.globalAlpha=ja,s.strokeStyle=Sn(y.color,Ys),s.lineWidth=Ka,s.setLineDash(Va),s.beginPath(),s.moveTo(M,v),s.lineTo(R,v),s.stroke(),s.setLineDash([]),s.restore()}const w=o.tasks.get(y.taskId),k=(w==null?void 0:w.progress)??0,S=tr(T.segments);let E=k*S;for(let I=0;I<m.length;I++){const M=m[I],R=Math.max(_e(T.segments[I].endDate).getTime()-_e(T.segments[I].startDate).getTime(),Us);if(s.save(),wn(s,M.startX,f,M.width,b,c),s.fillStyle=y.color,s.fill(),s.strokeStyle=Sn(y.color,Ys),s.lineWidth=er,s.stroke(),s.restore(),E>0&&a.showProgress){const _=Math.min(E,R),x=_/R,O=M.width*x;s.save(),wn(s,M.startX,f,M.width,b,c),s.clip(),s.globalAlpha=Qa,s.fillStyle=Sn(y.color,.3),s.fillRect(M.startX,f,O,b),s.restore(),E-=_}}if(y.label){const I=m[0],M=m[m.length-1],R=M.endX-I.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const x=s.measureText(y.label).width;s.textBaseline="middle",s.textAlign="left",x+St*2<=I.width?(s.fillStyle=y.textColor,wn(s,I.startX,f,I.width,b,c),s.clip(),s.fillText(y.label,I.startX+St,v)):x+St<=R?(s.fillStyle=y.textColor,s.fillText(y.label,I.startX+St,v)):(s.fillStyle=d.gridTextColor,s.fillText(y.label,M.endX+St,v)),s.restore()}}s.restore()},destroy(){n=null}}}const En=864e5,Xs=1e3,$t=4,sr=.6,or="#E53E3E",ir="#48BB78",ar="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function lt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function _t(e,t){return Math.round((t.getTime()-e.getTime())/En)}function zs(e,t){return new Date(e.getTime()+t*En)}function Ge(e,t){return lt(zs(he(e),t))}function Be(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(lt(n)),o;for(;i.getTime()<s.getTime();)o.push(lt(i)),i.setTime(i.getTime()+En);return o}class Dn{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(l=a.get(d))==null||l.delete(n),((u=a.get(d))==null?void 0:u.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const d of s){let h=(a==null?void 0:a.get(d))??0;if((u=l==null?void 0:l.get(d))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Nt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function rr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const d=parseInt(l,10);isNaN(d)||(u=d)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Gs(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function lr(e,t,n,s,o){const i=new Map;for(const f of s)e.has(f.taskId)&&n.has(f.resourceId)&&(i.has(f.taskId)||i.set(f.taskId,[]),i.get(f.taskId).push({resourceId:f.resourceId,units:f.units||1}));const a=new Map,l=new Map;for(const f of e.keys())a.set(f,[]),l.set(f,[]);for(const f of t.values()){if((f.type||"FS")!=="FS"||!e.has(f.source)||!e.has(f.target))continue;const v=f.lag||0;a.get(f.source).push({target:f.target,lag:v}),l.get(f.target).push({source:f.source,lag:v})}const u=new Map;for(const[f,b]of e){const v=he(b.startDate),m=he(b.endDate);u.set(f,{taskId:f,startDate:b.startDate,endDate:b.endDate,duration:Math.max(_t(v,m),0)})}const d=new Dn;function h(){d.clear();for(const[f,b]of u){const v=i.get(f);if(!v)continue;const m=Be(b.startDate,b.endDate);for(const w of v)d.allocate(w.resourceId,f,m,w.units)}}function p(f,b){const v=u.get(f);if(!v)return new Set;const m=new Set,w=v.startDate;if(b===w||he(b).getTime()<he(w).getTime())return m;const k=i.get(f);if(k){const S=Be(v.startDate,v.endDate);for(const D of k)d.deallocate(D.resourceId,f,S,D.units)}if(v.startDate=b,v.endDate=Ge(b,v.duration),m.add(f),k){const S=Be(v.startDate,v.endDate);for(const D of k)d.allocate(D.resourceId,f,S,D.units)}return m}function r(f){const b=new Set,v=u.get(f);if(!v)return b;const m=a.get(f)??[];for(const{target:w,lag:k}of m){const S=u.get(w);if(!S)continue;const D=Ge(v.endDate,k);if(he(S.startDate).getTime()<he(D).getTime()){const E=p(w,D);for(const I of E){b.add(I);const M=r(I);for(const R of M)b.add(R)}}}return b}function c(f){const b=l.get(f)??[];let v=u.get(f).startDate;v=e.get(f).startDate;for(const{source:w,lag:k}of b){const S=u.get(w);if(!S)continue;const D=Ge(S.endDate,k);he(D).getTime()>he(v).getTime()&&(v=D)}return v}h();for(let f=0;f<Xs;f++){const b=Nt(d,n);if(b.length===0)break;let v=!1;const m=b[0],w=m.taskIds.map(k=>o.get(k)).filter(k=>k!==void 0).sort(Gs);if(!(w.length<2))for(let k=1;k<w.length;k++){const S=w[k],D=u.get(S.taskId);if(!D)continue;const E=u.get(w[0].taskId);if(!E)continue;const I=E.endDate,M=c(S.taskId),R=he(I).getTime()>he(M).getTime()?I:M;he(R).getTime()>he(D.startDate).getTime()&&(p(S.taskId,R),r(S.taskId),v=!0);const _=d.getLoad(m.resourceId,m.date),x=n.get(m.resourceId).maxUnits;if(_<=x)break}}const g=new Map;let y=0;for(const[f,b]of u){const v=e.get(f),m=_t(he(v.startDate),he(b.startDate));m!==0&&(g.set(f,{startDate:b.startDate,endDate:b.endDate,delayDays:m}),y+=m)}const T=Nt(d,n);return{adjustedTasks:g,totalDelay:y,conflicts:T,resolved:T.length===0}}function cr(e,t,n,s,o){const i=new Map;for(const b of s)e.has(b.taskId)&&n.has(b.resourceId)&&(i.has(b.taskId)||i.set(b.taskId,[]),i.get(b.taskId).push({resourceId:b.resourceId,units:b.units||1}));const a=new Map;for(const b of e.keys())a.set(b,[]);for(const b of t.values())(b.type||"FS")==="FS"&&(!e.has(b.source)||!e.has(b.target)||a.get(b.target).push({source:b.source,lag:b.lag||0}));const l=Array.from(e.keys()).map(b=>o.get(b)).filter(b=>b!==void 0).sort(Gs),u=new Map,d=new Dn,h=new Set,p=new Map;for(const[b,v]of e)p.set(b,Math.max(_t(he(v.startDate),he(v.endDate)),0));function r(b){let m=e.get(b).startDate;const w=a.get(b)??[];for(const{source:k,lag:S}of w){const D=u.get(k);if(!D)continue;const E=Ge(D.endDate,S);he(E).getTime()>he(m).getTime()&&(m=E)}return m}function c(b,v,m){const w=i.get(b);if(!w||w.length===0)return v;let k=v;const S=365*5;for(let D=0;D<S;D++){const E=Ge(k,m),I=Be(k,E);let M=!0;for(const R of w){const _=n.get(R.resourceId);if(!_||_.maxUnits===0)continue;const x=_.calendar?new Set(_.calendar):null;if(x&&I.some(N=>x.has(N))){M=!1;break}if(!d.canFit(R.resourceId,b,I,R.units,_.maxUnits)){M=!1;break}}if(M)return k;k=Ge(k,1)}return v}const g=new Set(l.map(b=>b.taskId));for(let b=0;b<Xs&&g.size>0;b++){let v=!1;for(const m of l){if(!g.has(m.taskId)||!(a.get(m.taskId)??[]).every(_=>h.has(_.source)))continue;const S=m.taskId,D=p.get(S)??0,E=r(S),I=c(S,E,D),M=Ge(I,D);u.set(S,{taskId:S,startDate:I,endDate:M,duration:D});const R=i.get(S);if(R){const _=Be(I,M);for(const x of R)d.allocate(x.resourceId,S,_,x.units)}h.add(S),g.delete(S),v=!0}if(!v){for(const m of g){const w=e.get(m),k=p.get(m)??0;u.set(m,{taskId:m,startDate:w.startDate,endDate:w.endDate,duration:k});const S=i.get(m);if(S){const D=Be(w.startDate,w.endDate);for(const E of S)d.allocate(E.resourceId,m,D,E.units)}h.add(m)}g.clear()}}const y=new Map;let T=0;for(const[b,v]of u){const m=e.get(b),w=_t(he(m.startDate),he(v.startDate));w!==0&&(y.set(b,{startDate:v.startDate,endDate:v.endDate,delayDays:w}),T+=w)}const f=Nt(d,n);return{adjustedTasks:y,totalDelay:T,conflicts:f,resolved:f.length===0}}function dr(e,t,n,s){const o=[],i=Be(n,Ge(s,1)),a=i.length;for(const[l,u]of t){const d=new Map;let h=0,p=0;for(const g of i){const y=e.getLoad(l,g);d.set(g,y),h+=y,y>p&&(p=y)}const r=u.maxUnits===0?1:u.maxUnits,c=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:d,overallUtilization:Math.min(c,1),peakUtilization:p})}return o}function Vs(e,t,n,s){const o=new Dn,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const d=s.get(a),h=(d==null?void 0:d.startDate)??l.startDate,p=(d==null?void 0:d.endDate)??l.endDate,r=Be(h,p);for(const c of u)o.allocate(c.resourceId,a,r,c.units)}return o}function ur(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:g}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const y=u(),T=rr(c,y,n);s==="parallel"?i=cr(c,g,t,e.assignments,T):i=lr(c,g,t,e.assignments,T);const f=h(c,i.adjustedTasks),b=Vs(c,t,e.assignments,i.adjustedTasks);return a=dr(b,t,f.start,f.end),i}function h(r,c){let g=1/0,y=-1/0;for(const[T,f]of r){const b=c.get(T),v=he((b==null?void 0:b.startDate)??f.startDate).getTime(),m=he((b==null?void 0:b.endDate)??f.endDate).getTime();v<g&&(g=v),m>y&&(y=m)}if(g===1/0){const T=lt(new Date);return{start:T,end:T}}return{start:lt(new Date(g)),end:lt(new Date(y))}}function p(r){const c=[];for(const g of e.assignments)g.taskId===r&&c.push(g.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),l.push(r.on("resourceLeveling:run",(...c)=>{const g=c[0],y=d();g&&g(y)})),l.push(r.on("resourceLeveling:result",(...c)=>{const g=c[0];g&&g(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const g=c[0];g&&g(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const g=c[0];if(!g)return;const y=r.getState(),T=Vs(y.tasks,t,e.assignments,new Map);g(Nt(T,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,c,g){if(!i||a.length===0)return;const{config:y}=c,{headerHeight:T,rowHeight:f}=y,b=c.scrollX,v=c.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,T,r.canvas.width,r.canvas.height-T),r.clip(),r.translate(-b,0);const w=new Map;for(const k of a)w.set(k.resourceId,k);for(const k of g){const S=p(k.taskId);if(S.length===0)continue;const D=w.get(S[0]);if(!D)continue;const E=t.get(S[0]);if(!E)continue;const I=E.maxUnits===0?1:E.maxUnits,R=k.barY+k.barHeight-v+1;if(R+$t<T||R>r.canvas.height)continue;const _=c.tasks.get(k.taskId);if(!_)continue;const x=i.adjustedTasks.get(k.taskId),O=(x==null?void 0:x.startDate)??_.startDate,N=(x==null?void 0:x.endDate)??_.endDate,Y=m.dateToX(he(O)),K=m.dateToX(he(N))-Y;if(K<2)continue;r.fillStyle=ar,r.fillRect(Y,R,K,$t);const q=Be(O,N);for(const U of q){const C=D.dailyLoad.get(U)??0;if(C===0)continue;const P=m.dateToX(he(U)),$=m.dateToX(zs(he(U),1))-P,Q=Math.min(C/I,2)/2*$t,Z=C>I;r.globalAlpha=sr,r.fillStyle=Z?or:ir,r.fillRect(P,R+$t-Q,$,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const gr=864e5,hr=75,fr=50,Ks=25,Ot=.3,Ht=.25,js=.2,kn=.15,xt=.1,pr=.3,qs=.5,mr=20,Zs=40,Tr=3,yr=5,br=30,Js=.25,Qs=4,vr=2,Sr=5,Cn=5,eo=4,to=.4,wr=.003,Ve=260,ct=260,no=16,Fe=14,Er="rgba(30, 30, 46, 0.92)",In="#e0e0e0",Dr=10,Bt=32,kr=6,Ft="#EF4444",Yt="#F97316",Ut="#EAB308",Wt="#22C55E";function ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ke(e,t){return Math.round((t.getTime()-e.getTime())/gr)}function De(e,t,n){return Math.max(t,Math.min(n,e))}function Cr(e){return e>=hr?"critical":e>=fr?"high":e>=Ks?"medium":"low"}function Ir(e){switch(e){case"critical":return Ft;case"high":return Yt;case"medium":return Ut;case"low":return Wt}}function Xt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Mr(e,t){const n=new Map,s=new Map;for(const f of e.keys())n.set(f,[]),s.set(f,[]);for(const f of t.values())!e.has(f.source)||!e.has(f.target)||(n.get(f.source).push(f.target),s.get(f.target).push(f.source));const o=new Map,i=new Set;function a(f){if(o.has(f))return o.get(f);if(i.has(f))return 0;i.add(f);let b=0;for(const v of n.get(f)||[])b+=1+a(v);return o.set(f,b),b}for(const f of e.keys())a(f);const l=new Map;for(const[f,b]of e){const v=ve(b.startDate),m=ve(b.endDate);l.set(f,Math.max(ke(v,m),0))}const u=new Map,d=new Map,h=new Map;for(const f of e.keys())h.set(f,(s.get(f)||[]).length),u.set(f,l.get(f)||0),d.set(f,null);const p=[],r=new Map(h);for(const[f,b]of r)b===0&&p.push(f);for(;p.length>0;){const f=p.shift();for(const b of n.get(f)||[]){const v=u.get(f)+(l.get(b)||0);v>u.get(b)&&(u.set(b,v),d.set(b,f));const m=r.get(b)-1;r.set(b,m),m===0&&p.push(b)}}const c=new Set;let g=0,y=null;for(const[f,b]of u)b>g&&(g=b,y=f);let T=y;for(;T!==null;)c.add(T),T=d.get(T)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function Ar(e){const t=Xt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ve(o.startDate),a=ve(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function Lr(e,t,n){const s=[],o=Xt(),i=ve(e.startDate),a=ve(e.endDate),l=Math.max(ke(i,a),1),u=Math.max(ke(i,o),0),d=Math.max(ke(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=ke(a,o);p=De(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*Ot)})}else{const D=d/l;D<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*Ot)})):(p=De(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*Ot)}))}let c=0;const g=De(u/l,0,1),y=g-h;y>qs?(c=De(Math.round(y*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Ht)})):y>pr?(c=De(Math.round(y*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Ht)})):y>.1&&(c=De(Math.round(y*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(g*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(c*Ht)}));let T=0;const f=t.downstreamCount.get(e.id)||0,b=t.criticalPathIds.has(e.id);if(f>0){T=De(Math.round(Math.log2(f+1)*20),0,70),b&&(T=De(Math.round(T*1.5),0,100));const D=b?" (on critical path)":"";s.push({type:"dependency-chain",description:`${f} downstream dependent${f===1?"":"s"}${D}`,impact:Math.round(T*js)})}let v=0;l>Zs?(v=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(v*kn)})):l>mr&&(v=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(v*kn)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*xt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>yr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*xt)})):D.length>Tr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*xt)}))}const w=De(Math.round(p*Ot+c*Ht+T*js+v*kn+m*xt),0,100),k=Cr(w);let S;return r&&h===0?S="Task is overdue with no progress — escalate immediately":r?S="Task is past its deadline — review scope or extend timeline":y>qs?S="Task is significantly behind schedule — investigate blockers":l>Zs&&h<Js?S="Large task with little progress — consider splitting into smaller work items":(k==="high"||k==="critical")&&(S="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:k,riskScore:w,factors:s,suggestion:S}}function Rr(e,t,n,s,o){const i=Xt();let a=0,l=0,u=0;for(const[b,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;l++;const m=ve(v.startDate),w=ve(v.endDate),k=Math.max(ke(m,w),1),S=Math.max(ke(m,i),0),D=De(S/k,0,1);(v.progress??0)>=D-.1&&a++;const I=t.get(b);I&&(I.riskLevel==="high"||I.riskLevel==="critical")&&u++}const d=l>0?a/l:1;let h=0;for(const b of n.criticalPathIds){const v=e.get(b);if(!v||v.isCompleted)continue;const m=ve(v.endDate);i.getTime()>m.getTime()&&(h+=ke(m,i))}const p=[],r=[];for(const[b,v]of s.activeTasks)p.push(v.length),v.length>Qs&&r.push(b);let c=100;if(p.length>1){const b=p.reduce((v,m)=>v+m,0)/p.length;if(b>0){const v=p.reduce((w,k)=>w+(k-b)**2,0)/p.length,m=Math.sqrt(v)/b;c=De(Math.round(100-m*50),0,100)}}let g=100;if(l>0){let b=0,v=0,m=0;for(const w of e.values()){if(w.isCompleted)continue;const k=ve(w.startDate),S=ve(w.endDate),D=Math.max(ke(k,S),1),E=Math.max(ke(k,i),0),I=De(E/D,0,2);b+=w.progress??0,v+=I,m++}if(m>0){const w=b/m,k=v/m;if(k>0){const S=w/k;g=De(Math.round(S*100),0,100)}}}const y=d*100,T=De(100-h*10,0,100);return{overallScore:De(Math.round(y*.25+T*.25+c*.25+g*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function Pr(e,t,n,s){const o=[],i=Xt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.endDate),g=ke(c,i),y=r.progress??0;g>Sr&&y===0&&o.push({type:"escalate",description:`"${r.name}" is ${g} days overdue with zero progress — flag for management`,impact:`Prevents further ${g}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.startDate),g=ve(r.endDate),y=ke(c,g),T=r.progress??0;if(y>br&&T<Js){const f=Math.ceil(y/15);o.push({type:"split",description:`"${r.name}" spans ${y} days — split into ${f} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>Qs?l.push({assignee:p,taskIds:r}):r.length<vr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const c=r.filter(g=>!t.criticalPathIds.has(g));c.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const c=ve(r.endDate),g=ke(i,c);if(g>=0&&g<=5){const y=s.get(p);y&&y.riskScore>=Ks&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${g} day${g===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${g}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ve(p.startDate).getTime()-ve(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const c of r)h.add(`${c}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const c=d[p],g=d[r],y=ve(c.endDate),T=ve(g.startDate);if(y.getTime()<=T.getTime()&&!(h.has(`${c.id}->${g.id}`)||h.has(`${g.id}->${c.id}`))){const b=ke(y,T);b>0&&o.push({type:"parallel",description:`"${c.name}" and "${g.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${b} days on the critical path`,taskIds:[c.id,g.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function $r(e,t,n,s,o,i,a){if(e.save(),i){const l=to+(1-to)*(.5+.5*Math.sin(a*wr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function _r(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,d=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Wt:i>=50?Ut:i>=25?Yt:Ft;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=In,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function Nr(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Ft,label:"Critical"},{count:o.high,color:Yt,label:"High"},{count:o.medium,color:Ut,label:"Medium"},{count:o.low,color:Wt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const d=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+d),e.closePath(),e.fillStyle=u.color,e.fill(),l+=d}}function Or(e,t,n,s,o){const i=t-Ve-no,a=n+no;e.save(),e.beginPath();const l=Dr;e.moveTo(i+l,a),e.lineTo(i+Ve-l,a),e.arcTo(i+Ve,a,i+Ve,a+l,l),e.lineTo(i+Ve,a+ct-l),e.arcTo(i+Ve,a+ct,i+Ve-l,a+ct,l),e.lineTo(i+l,a+ct),e.arcTo(i,a+ct,i,a+ct-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Er,e.fill(),e.fillStyle=In,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Fe,a+Fe);const u=i+Fe+Bt+4,d=a+Fe+20+Bt+8;_r(e,u,d,Bt,kr,s.overallScore);const h=24,p=i+Ve-Fe-h-4,r=d;Nr(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const c=r+h+8,g=[{count:o.critical,color:Ft,label:"C"},{count:o.high,color:Yt,label:"H"},{count:o.medium,color:Ut,label:"M"},{count:o.low,color:Wt,label:"L"}],y=28,T=p-g.length*y/2+y/2;for(let m=0;m<g.length;m++){const w=g[m],k=T+m*y;e.fillStyle=w.color,e.fillText(`${w.label}:${w.count}`,k,c)}const f=d+Bt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Fe,f);const b=f+18;e.font="10px sans-serif",e.fillStyle=In,e.fillText("Recommendations:",i+Fe,b);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const w=v[m],k=b+14+m*16,S=w.type==="escalate"?"⚠":w.type==="split"?"✂":w.type==="reassign"?"⇄":w.type==="parallel"?"⇉":w.type==="add-buffer"?"⏱":"ℹ",D=34,E=w.description.length>D?w.description.substring(0,D-1)+"…":w.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${S} ${E}`,i+Fe,k)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Fe,b+14)),e.restore()}function Hr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:d,dependencies:h}=u;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=Mr(d,h),r=Ar(d),c=new Map;for(const[g,y]of d)c.set(g,Lr(y,p,r));n=c,o=Pr(d,p,r,n),s=Rr(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,d){d(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,d,h){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,c=d.scrollY,g=p,y=Date.now()-a;u.save(),u.beginPath(),u.rect(0,g,u.canvas.width,u.canvas.height-g),u.clip(),u.translate(-r,0);for(const T of h){const f=n.get(T.taskId);if(!f||f.riskLevel==="low")continue;const b=T.x,v=T.barY-c,m=T.width,w=T.barHeight;if(v+w<g||v>u.canvas.height||b+m<0)continue;const k=b+m-Cn-eo,S=v+Cn+eo,D=Ir(f.riskLevel),E=f.riskLevel==="critical";$r(u,k,S,Cn,D,E,y)}if(u.restore(),i){const T={critical:0,high:0,medium:0,low:0};for(const f of n.values())T[f.riskLevel]++;u.save(),Or(u,u.canvas.width,p,s,T),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Le=160,Ke=80,Mn=8,xr=240,Br=160,Fr=100,Yr=200,zt=8,so=.1,oo=3,Ur=.001,Wr=500,Xr=5,zr=864e5,Gr={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function io(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Vr(e,t){return Math.round((t.getTime()-e.getTime())/zr)}function ao(e,t,n){return e+(t-e)*n}function Gt(e,t,n){return Math.max(t,Math.min(n,e))}function An(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function Kr(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const d of s.get(l)){const h=n.get(d),p=u+1;(h===void 0||p>h)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function jr(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function qr(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<Xr;a++){for(let l=1;l<e.length;l++){const u=e[l],d=new Map;for(const h of u){const p=o.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let l=e.length-2;l>=0;l--){const u=e[l],d=new Map;for(const h of u){const p=s.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function Zr(e,t){const n=new Map;if(t==="radial")return Jr(e);const s=t==="lr",o=s?xr:Br,i=s?Fr:Yr;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],c=h+p*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function Jr(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function wt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Qr(e,t){return e.color?e.color:e.status&&(t[e.status]||Gr[e.status])||"#94A3B8"}function el(e){const t=io(e.startDate),n=io(e.endDate);return Math.max(Vr(t,n),0)}function tl(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,d=new Map,h=[],p=null,r=0,c=0,g=1,y=!1,T=0,f=0,b=0,v=0,m=null,w=0,k=0,S=null,D=null,E=new Set,I=!1,M=0,R=0,_=0,x=0;function O(X,L){return{x:(X-r)/g,y:(L-c)/g}}function N(X,L){const{x:H,y:z}=O(X,L);for(const G of d.values()){const V=G.x,te=G.y;if(H>=V&&H<=V+Le&&z>=te&&z<=te+Ke)return G}return null}function Y(){const X=e.getState(),{tasks:L,dependencies:H,config:z}=X;if(L.size===0){d=new Map,h=[];return}p=un(L,H);const G=Kr(L,H),V=jr(G);qr(V,H,L);const te=Zr(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:we}of te.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Le),le=Math.min(le,we),pe=Math.max(pe,we+Ke);const be=(oe+ae)/2,Ce=(le+pe)/2,Ie=d;d=new Map;for(const[ue,we]of L){const Me=te.get(ue);if(!Me)continue;const We=Me.x-be,Je=Me.y-Ce,Ne=Ie.get(ue);d.set(ue,{id:ue,task:we,layer:G.get(ue)??0,orderInLayer:0,x:Ne?Ne.x:We,y:Ne?Ne.y:Je,targetX:We,targetY:Je,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let we=0;we<ue.length;we++){const Me=d.get(ue[we]);Me&&(Me.orderInLayer=we)}h=[];for(const ue of H.values())!L.has(ue.source)||!L.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const L=e.getState(),H=new Set;H.add(X);const z=new Map,G=new Map;for(const oe of L.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of L.dependencies.values())!L.tasks.has(oe.source)||!L.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])H.has(ae)||(H.add(ae),V.push(ae))}const te=[X];for(;te.length>0;){const oe=te.shift();for(const ae of z.get(oe)||[])H.has(ae)||(H.add(ae),te.push(ae))}return H}function K(){I&&cancelAnimationFrame(R),I=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,L=Gt(X/Wr,0,1),H=1-Math.pow(1-L,3);let z=!1;for(const G of d.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),te=Math.abs(G.y-G.targetY);V>.5||te>.5?(G.x=ao(G.x,G.targetX,H),G.y=ao(G.y,G.targetY,H),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(U(),z&&L<1)R=requestAnimationFrame(q);else{I=!1;for(const G of d.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);U()}}function U(){if(!i||!o)return;const X=e.getState(),{config:L}=X,H=L.theme,z=L.colorMap,G=H.timelineBg==="#1A202C"||H.gridBg==="#1A202C"||H.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(H.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,_,x),i.save(),i.translate(r,c),i.scale(g,g);for(const V of h){const te=d.get(V.sourceId),oe=d.get(V.targetId);if(!te||!oe)continue;const ae=E.has(V.sourceId)&&E.has(V.targetId),le=S===V.sourceId||S===V.targetId,pe=S!==null&&!le||D!==null&&!ae,be=te.x+Le,Ce=te.y+Ke/2,Ie=oe.x,ue=oe.y+Ke/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=H.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const we=(be+Ie)/2;i.beginPath(),i.moveTo(be,Ce),i.quadraticCurveTo(we,Ce,(be+Ie)/2,(Ce+ue)/2),i.quadraticCurveTo(we,ue,Ie,ue),i.stroke();const Me=Math.atan2(ue-(Ce+ue)/2,Ie-we);i.beginPath(),i.moveTo(Ie,ue),i.lineTo(Ie-zt*Math.cos(Me-Math.PI/6),ue-zt*Math.sin(Me-Math.PI/6)),i.lineTo(Ie-zt*Math.cos(Me+Math.PI/6),ue-zt*Math.sin(Me+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const We=V.dep.type||"FS",Je=V.dep.lag||0,Ne=Je!==0?`${We} +${Je}d`:We!=="FS"?We:"";if(Ne&&!pe){const kt=(be+Ie)/2,Gn=(Ce+ue)/2-8;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ne,kt,Gn)}i.restore()}for(const V of d.values()){const te=S!==null&&S!==V.id&&!P(S,V.id)||D!==null&&!E.has(V.id),oe=S===V.id,ae=D===V.id,le=Qr(V.task,z),pe=V.x,be=V.y;i.save(),te&&(i.globalAlpha=.25),V.isCritical&&!te&&(i.save(),i.shadowColor=H.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,wt(i,pe,be,Le,Ke,Mn),i.fillStyle="transparent",i.fill(),i.restore()),wt(i,pe,be,Le,Ke,Mn),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=H.selectionColor||"#3182CE",i.lineWidth=2,wt(i,pe-2,be-2,Le+4,Ke+4,Mn+2),i.stroke()),i.font=`600 12px ${H.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ce=An(i,V.task.name,Le-20);i.fillText(Ce,pe+10,be+8);const Ie=be+26;i.beginPath(),i.arc(pe+16,Ie+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(An(i,ue,Le-40),pe+24,Ie);const we=el(V.task),Me=we===1?"1 day":`${we} days`;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Me,pe+10,be+42),V.task.assignee&&(i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(An(i,V.task.assignee,Le/2-10),pe+Le-10,be+42));const We=V.task.progress??0,Je=be+Ke-6,Ne=Le-20,kt=3;if(wt(i,pe+10,Je,Ne,kt,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),We>0){const Gn=Math.max(kt,Ne*Gt(We,0,1));wt(i,pe+10,Je,Gn,kt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),C(G,H.fontFamily)}function C(X,L){if(!i)return;const H={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${H[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(g*100)}%`,_-12,12),i.restore()}function P(X,L){for(const H of h)if(H.sourceId===X&&H.targetId===L||H.sourceId===L&&H.targetId===X)return!0;return!1}function A(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;u=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const H=o.getContext("2d");H&&(i=H,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",me),o.addEventListener("mouseup",F),o.addEventListener("mouseleave",ee),o.addEventListener("dblclick",j),o.addEventListener("wheel",J,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function $(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(_=X.clientWidth,x=X.clientHeight,o.width=Math.round(_*a),o.height=Math.round(x*a),o.style.width=`${_}px`,o.style.height=`${x}px`)}function B(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),$(),Z(),Y();for(const X of d.values())X.x=X.targetX,X.y=X.targetY;U()}}function Q(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),S=null,D=null,E=new Set)}function Z(){r=_/2,c=x/2,g=1}function re(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function ge(X){const{x:L,y:H}=re(X),z=N(L,H);z?(m=z,z.isDragging=!0,w=O(L,H).x-z.x,k=O(L,H).y-z.y,D=z.id,E=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),U()):(y=!0,T=L,f=H,b=r,v=c,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),U()))}function me(X){if(!o)return;const{x:L,y:H}=re(X);if(m){const V=O(L,H);m.x=V.x-w,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U();return}if(y){const V=L-T,te=H-f;r=b+V,c=v+te,U();return}const z=N(L,H),G=z?z.id:null;G!==S&&(S=G,o.style.cursor=S?"pointer":"default",U())}function F(X){m&&(m.isDragging=!1,m=null),y=!1}function ee(X){m&&(m.isDragging=!1,m=null),y=!1,S&&(S=null,U())}function j(X){const{x:L,y:H}=re(X),z=N(L,H);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function J(X){if(X.preventDefault(),!o)return;const{x:L,y:H}=re(X),z=O(L,H),G=-X.deltaY*Ur;g=Gt(g+G*g,so,oo);const V=O(L,H);r+=(V.x-z.x)*g,c+=(V.y-z.y)*g,U()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],H=o.getBoundingClientRect(),z=L.clientX-H.left,G=L.clientY-H.top,V=N(z,G);V?(m=V,V.isDragging=!0,w=O(z,G).x-V.x,k=O(z,G).y-V.y,D=V.id,E=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(y=!0,T=z,f=G,b=r,v=c),U()}else if(X.touches.length===2){y=!1,m&&(m.isDragging=!1,m=null);const L=X.touches[0],H=X.touches[1];se=Math.hypot(H.clientX-L.clientX,H.clientY-L.clientY),de=(L.clientX+H.clientX)/2,ie=(L.clientY+H.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const H=X.touches[0],z=H.clientX-L.left,G=H.clientY-L.top;if(m){const V=O(z,G);m.x=V.x-w,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U()}else if(y){const V=z-T,te=G-f;r=b+V,c=v+te,U()}}else if(X.touches.length===2){const H=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-H.clientX,z.clientY-H.clientY),V=(H.clientX+z.clientX)/2,te=(H.clientY+z.clientY)/2,oe=V-L.left,ae=te-L.top;if(se>0){const le=G/se,pe=O(oe,ae);g=Gt(g*le,so,oo);const be=O(oe,ae);r+=(be.x-pe.x)*g,c+=(be.y-pe.y)*g}r+=V-de,c+=te-ie,se=G,de=V,ie=te,U()}}function Te(X){m&&(m.isDragging=!1,m=null),y=!1,se=0}function ye(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",me),o.removeEventListener("mouseup",F),o.removeEventListener("mouseleave",ee),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",J),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),I&&(cancelAnimationFrame(R),I=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():B()})),t.push(e.on("networkGraph:layout",(...L)=>{const H=L[0];H!==s&&(s=H,n&&(Y(),K()))})),t.push(e.on("stateChange",()=>{n&&(Y(),K())}))},renderDOM(X,L){o||A(X),n&&($(),U())},destroy(){for(const X of t)X();t=[],ye(),d=new Map,h=[],p=null,n=!1}}}const ro=300,lo="nimbus-gantt-config-panel",Ln="nimbus-gantt-config-panel-styles",co=300,Rn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],nl=`
  .ng-config-gear {
    position: absolute;
    bottom: 16px;
    right: 16px;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: rgba(59, 130, 246, 0.9);
    color: #fff;
    border: none;
    cursor: pointer;
    font-size: 20px;
    line-height: 40px;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    z-index: 1000;
    transition: background 200ms ease, transform 200ms ease;
    user-select: none;
  }
  .ng-config-gear:hover {
    background: rgba(59, 130, 246, 1);
    transform: scale(1.08);
  }

  .ng-config-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 1001;
    opacity: 0;
    pointer-events: none;
    transition: opacity ${co}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${ro}px;
    width: ${ro}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${co}ms ease;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 13px;
  }
  .ng-config-panel.ng-open {
    right: 0;
  }

  .ng-config-panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid #333;
    font-size: 15px;
    font-weight: 600;
  }

  .ng-config-close {
    background: none;
    border: none;
    color: #999;
    font-size: 20px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .ng-config-close:hover {
    color: #fff;
  }

  .ng-config-section {
    border-bottom: 1px solid #2a2a3a;
    padding: 12px 16px;
  }
  .ng-config-section-title {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #888;
    margin-bottom: 10px;
    font-weight: 600;
  }

  .ng-config-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .ng-config-row:last-child {
    margin-bottom: 0;
  }
  .ng-config-label {
    font-size: 12px;
    color: #ccc;
    flex-shrink: 0;
  }

  .ng-config-slider {
    width: 110px;
    accent-color: #3b82f6;
    cursor: pointer;
  }
  .ng-config-slider-value {
    font-size: 11px;
    color: #888;
    width: 32px;
    text-align: right;
    flex-shrink: 0;
  }

  .ng-config-toggle {
    position: relative;
    width: 36px;
    height: 20px;
    background: #444;
    border-radius: 10px;
    cursor: pointer;
    transition: background 200ms ease;
    flex-shrink: 0;
  }
  .ng-config-toggle.ng-active {
    background: #3b82f6;
  }
  .ng-config-toggle-knob {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    background: #fff;
    border-radius: 50%;
    transition: left 200ms ease;
  }
  .ng-config-toggle.ng-active .ng-config-toggle-knob {
    left: 18px;
  }

  .ng-config-select {
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 12px;
    cursor: pointer;
    outline: none;
  }
  .ng-config-select:focus {
    border-color: #3b82f6;
  }

  .ng-config-color-input {
    width: 32px;
    height: 24px;
    padding: 0;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    background: transparent;
  }

  .ng-config-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 6px 12px;
    background: #2a2a3a;
    color: #ccc;
    border: 1px solid #444;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
    transition: background 150ms ease;
    margin-right: 6px;
    margin-bottom: 6px;
  }
  .ng-config-btn:hover {
    background: #3b3b4a;
    color: #fff;
  }
  .ng-config-btn.ng-primary {
    background: #3b82f6;
    border-color: #3b82f6;
    color: #fff;
  }
  .ng-config-btn.ng-primary:hover {
    background: #2563eb;
  }

  .ng-config-zoom-group {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .ng-config-zoom-btn {
    padding: 4px 10px;
    background: #2a2a3a;
    color: #ccc;
    border: 1px solid #444;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
    transition: background 150ms ease;
  }
  .ng-config-zoom-btn:hover {
    background: #3b3b4a;
  }
  .ng-config-zoom-btn.ng-active {
    background: #3b82f6;
    border-color: #3b82f6;
    color: #fff;
  }

  .ng-config-date-input {
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 3px 6px;
    font-size: 11px;
    width: 110px;
    outline: none;
  }
  .ng-config-date-input:focus {
    border-color: #3b82f6;
  }

  .ng-config-color-map-entry {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
  }
  .ng-config-color-map-status {
    flex: 1;
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 3px 6px;
    font-size: 11px;
    outline: none;
  }
  .ng-config-color-map-remove {
    background: none;
    border: none;
    color: #888;
    cursor: pointer;
    font-size: 14px;
    padding: 0 2px;
  }
  .ng-config-color-map-remove:hover {
    color: #ef4444;
  }
  .ng-config-color-map-add {
    font-size: 11px;
    color: #3b82f6;
    cursor: pointer;
    background: none;
    border: none;
    padding: 2px 0;
  }
  .ng-config-color-map-add:hover {
    text-decoration: underline;
  }

  .ng-config-plugin-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 4px 0;
  }
  .ng-config-plugin-name {
    font-size: 12px;
    color: #ccc;
  }
  .ng-config-plugin-status {
    font-size: 10px;
    color: #888;
    margin-left: 6px;
  }
  .ng-config-plugin-status.ng-active-status {
    color: #22c55e;
  }
`;function sl(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(lo);return e?JSON.parse(e):{}}catch{return{}}}function ol(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(lo,JSON.stringify(e))}catch{}}function uo(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Vt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function il(){if(typeof document>"u"||document.getElementById(Ln))return;const e=document.createElement("style");e.id=Ln,e.textContent=nl,document.head.appendChild(e)}function al(){if(typeof document>"u")return;const e=document.getElementById(Ln);e&&e.remove()}function Kt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);d.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(u),a.appendChild(d),a}function Et(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function jt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=go(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function go(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function rl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const S=e.getState();e.dispatch({type:"SET_SCROLL",x:S.scrollX,y:S.scrollY})}function d(S){Object.assign(t,S),ol(t)}function h(S,D,E){S[D]=E}function p(S,D){if(!e)return;const E=e.getState();h(E.config,S,D),d({[S]:D}),u()}function r(S,D){if(!e)return;const E=e.getState();h(E.config.theme,S,D),u()}function c(S){if(!e)return;const D=Rn.find(I=>I.name===S);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),d({themePreset:S}),u()}function g(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function y(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function T(S,D){var X;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?y():g()}),S.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",y),S.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",S.appendChild(o)),o.innerHTML="";const I=document.createElement("div");I.className="ng-config-panel-header",I.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",y),I.appendChild(M),o.appendChild(I);const R=f("Display Settings");R.appendChild(Kt("Row height",24,60,E.rowHeight,2,L=>p("rowHeight",L))),R.appendChild(Kt("Bar height",16,40,E.barHeight,2,L=>p("barHeight",L))),R.appendChild(Kt("Grid width",0,500,E.gridWidth,10,L=>p("gridWidth",L))),R.appendChild(Kt("Font size",10,16,E.theme.fontSize,1,L=>{h(D.config.theme,"fontSize",L),d({fontSize:L}),u()})),R.appendChild(Et("Today marker",E.showToday,L=>{h(D.config,"showToday",L),d({showToday:L}),u()})),R.appendChild(Et("Weekends",E.showWeekends,L=>{h(D.config,"showWeekends",L),d({showWeekends:L}),u()})),R.appendChild(Et("Progress bars",E.showProgress,L=>{h(D.config,"showProgress",L),d({showProgress:L}),u()})),R.appendChild(Et("Dependency arrows",a,L=>{a=L,d({showDependencies:L}),u()})),R.appendChild(Et("Labels on bars",t.showBarLabels!==!1,L=>{d({showBarLabels:L}),u()})),o.appendChild(R);const _=f("Color Theme"),x=document.createElement("div");x.className="ng-config-row";const O=document.createElement("span");O.className="ng-config-label",O.textContent="Preset";const N=document.createElement("select");N.className="ng-config-select";const Y=document.createElement("option");Y.value="",Y.textContent="Custom",N.appendChild(Y);for(const L of Rn){const H=document.createElement("option");H.value=L.name,H.textContent=L.name,t.themePreset===L.name&&(H.selected=!0),N.appendChild(H)}N.addEventListener("change",()=>{N.value&&c(N.value)}),x.appendChild(O),x.appendChild(N),_.appendChild(x),_.appendChild(jt("Bar default",E.theme.barDefaultColor,L=>{r("barDefaultColor",L),d({customColors:{...t.customColors,barDefault:L}})})),_.appendChild(jt("Today line",E.theme.todayLineColor,L=>{r("todayLineColor",L),d({customColors:{...t.customColors,todayLine:L}})})),_.appendChild(jt("Grid lines",E.theme.timelineGridColor,L=>{r("timelineGridColor",L),d({customColors:{...t.customColors,gridLines:L}})})),_.appendChild(jt("Background",E.theme.timelineBg,L=>{r("timelineBg",L),d({customColors:{...t.customColors,background:L}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",_.appendChild(W);const K={...E.colorMap,...t.statusColorMap},q=document.createElement("div");function U(){q.innerHTML="";const L=Object.entries(K);for(const[z,G]of L){const V=document.createElement("div");V.className="ng-config-color-map-entry";const te=document.createElement("input");te.className="ng-config-color-map-status",te.value=z,te.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=go(G),oe.addEventListener("input",()=>{K[z]=oe.value,E.colorMap[z]=oe.value,d({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete E.colorMap[z],d({statusColorMap:{...K}}),U(),u()}),V.appendChild(te),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const H=document.createElement("button");H.className="ng-config-color-map-add",H.textContent="+ Add status color",H.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",E.colorMap[z.trim()]="#3b82f6",d({statusColorMap:{...K}}),U(),u())}),q.appendChild(H)}U(),_.appendChild(q),o.appendChild(_);const C=f("Zoom & Time"),P=document.createElement("div");P.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const $=document.createElement("div");$.className="ng-config-zoom-group";const B=["day","week","month","quarter"];for(const L of B){const H=document.createElement("button");H.className="ng-config-zoom-btn"+(D.zoomLevel===L?" ng-active":""),H.textContent=L.charAt(0).toUpperCase()+L.slice(1),H.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),d({zoomLevel:L}),$.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===H)))}),$.appendChild(H)}P.appendChild(A),P.appendChild($),C.appendChild(P);const Q=document.createElement("div");Q.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=uo(D.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const L=Vt(re.value),H=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeStart:re.value})}),Q.appendChild(Z),Q.appendChild(re),C.appendChild(Q);const ge=document.createElement("div");ge.className="ng-config-row";const me=document.createElement("span");me.className="ng-config-label",me.textContent="End date";const F=document.createElement("input");F.type="date",F.className="ng-config-date-input",F.value=uo(D.dateRange.end),F.addEventListener("change",()=>{if(!e||!F.value)return;const L=e.getState().dateRange.start,H=Vt(F.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeEnd:F.value})}),ge.appendChild(me),ge.appendChild(F),C.appendChild(ge);const ee=document.createElement("div");ee.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),ee.appendChild(j),C.appendChild(ee),o.appendChild(C);const J=f("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),b("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>b("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&w(e.getState())}),se.appendChild(ce),J.appendChild(se),o.appendChild(J);const Te=f("Plugin Toggles"),ye=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of ye){const H=document.createElement("div");H.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=L.label;const G=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const te=document.createElement("div");te.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",te.appendChild(oe);let ae=G;te.addEventListener("click",()=>{ae=!ae,te.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[L.key]:ae};d({pluginToggles:pe}),b(L.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),H.appendChild(le),H.appendChild(te),Te.appendChild(H)}o.appendChild(Te)}function f(S){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=S,D.appendChild(E),D}function b(S){e&&v.forEach(D=>D(S))}const v=[];function m(S){const D=Array.from(S.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],I=D.map(O=>[O.id,`"${(O.name||"").replace(/"/g,'""')}"`,O.startDate,O.endDate,String(Math.round((O.progress??0)*100))+"%",O.status||"",O.assignee||"",O.priority||"",O.groupName||""]),M=[E.join(","),...I.map(O=>O.join(","))].join(`
`),R=new Blob([M],{type:"text/csv;charset=utf-8;"}),_=URL.createObjectURL(R),x=document.createElement("a");x.href=_,x.download="gantt-tasks.csv",document.body.appendChild(x),x.click(),document.body.removeChild(x),URL.revokeObjectURL(_)}function w(S){const D=Array.from(S.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],I=D.map(_=>[_.name,_.startDate,_.endDate,Math.round((_.progress??0)*100)+"%",_.status||"",_.assignee||""]),R=[E.join("	"),...I.map(_=>_.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(R).catch(()=>{})}function k(S){const D=t;if(D.rowHeight!==void 0&&h(S.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&h(S.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&h(S.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&h(S.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&h(S.config,"showToday",D.showToday),D.showWeekends!==void 0&&h(S.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&h(S.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=Rn.find(I=>I.name===D.themePreset);E&&Object.assign(S.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&h(S.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&h(S.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&h(S.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&h(S.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(S.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:Vt(D.dateRangeStart),end:Vt(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(S){e=S,il(),t=sl();const D=S.on("render",()=>{D(),k(S.getState()),u()});l.push(D);const E=S.on("config:open",()=>g()),I=S.on("config:close",()=>y()),M=S.on("config:toggle",()=>{i?y():g()});l.push(E,I,M)},renderDOM(S,D){T(S,D)},destroy(){l.forEach(S=>S()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),al(),e=null,i=!1}}}const ho=864e5,Pn="nimbus-gantt-heatmap-styles",Se=28,Re=2,je=48,Pe=160,ll=3,fo="#1e1e2e",po="#166534",mo="#a16207",To="#b91c1c",cl=`
  .ng-heatmap-container {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: #0f172a;
    z-index: 500;
    overflow: auto;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    display: none;
  }
  .ng-heatmap-container.ng-active {
    display: block;
  }

  .ng-heatmap-header-bar {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #0f172a;
    display: flex;
    align-items: center;
    padding: 10px 16px;
    border-bottom: 1px solid #1e293b;
    gap: 12px;
  }
  .ng-heatmap-title {
    font-size: 15px;
    font-weight: 600;
    color: #e2e8f0;
  }
  .ng-heatmap-close {
    margin-left: auto;
    background: #1e293b;
    border: 1px solid #334155;
    color: #94a3b8;
    border-radius: 4px;
    padding: 4px 12px;
    font-size: 12px;
    cursor: pointer;
  }
  .ng-heatmap-close:hover {
    background: #334155;
    color: #e2e8f0;
  }

  .ng-heatmap-legend {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 11px;
    color: #94a3b8;
    margin-left: 16px;
  }
  .ng-heatmap-legend-swatch {
    width: 14px;
    height: 14px;
    border-radius: 2px;
    display: inline-block;
    vertical-align: middle;
  }

  .ng-heatmap-grid-wrapper {
    position: relative;
    padding: 8px 16px 16px;
  }

  .ng-heatmap-tooltip {
    position: fixed;
    z-index: 10000;
    background: rgba(15, 23, 42, 0.95);
    color: #e2e8f0;
    border: 1px solid #334155;
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 12px;
    max-width: 240px;
    pointer-events: none;
    display: none;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    line-height: 1.5;
  }
  .ng-heatmap-tooltip.ng-visible {
    display: block;
  }
  .ng-heatmap-tooltip-date {
    font-weight: 600;
    margin-bottom: 4px;
    color: #cbd5e1;
  }
  .ng-heatmap-tooltip-task {
    color: #94a3b8;
    padding-left: 8px;
  }
`;function yo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function dl(e){return String(e.getUTCDate())}function ul(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function gl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function bo(e,t){return Math.round((t.getTime()-e.getTime())/ho)}function vo(e,t){return new Date(e.getTime()+t*ho)}function dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function hl(e,t){return e===0?fo:e===1?po:e===2?mo:To}function fl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function pl(){if(typeof document>"u"||document.getElementById(Pn))return;const e=document.createElement("style");e.id=Pn,e.textContent=cl,document.head.appendChild(e)}function ml(){if(typeof document>"u")return;const e=document.getElementById(Pn);e&&e.remove()}function Tl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=bo(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(vo(o,h));const u=new Map;let d=0;for(const h of s)for(const p of l){const r=`${h}|${dt(p)}`;u.set(r,{assignee:h,date:p,dateKey:dt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=yo(h.startDate),c=yo(h.endDate),g=bo(r,c)+1;for(let y=0;y<g;y++){const T=vo(r,y),f=`${p}|${dt(T)}`,b=u.get(f);b&&(b.tasks.push(h),b.count++,b.count>d&&(d=b.count))}}return{assignees:s,dates:l,cells:u,maxCount:d}}function yl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=Tl(p);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const g=document.createElement("canvas"),y=Pe+r.dates.length*(Se+Re),T=je+r.assignees.length*(Se+Re),f=window.devicePixelRatio||1;g.width=y*f,g.height=T*f,g.style.width=y+"px",g.style.height=T+"px",g.style.cursor="pointer";const b=g.getContext("2d");b.scale(f,f),b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle";let v="",m=Pe;for(let w=0;w<r.dates.length;w++){const k=r.dates[w],S=ul(k),D=Pe+w*(Se+Re);if(S!==v){if(v&&w>0){const E=(m+D)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(v,E,12)}m=D,v=S}}if(v){const w=Pe+r.dates.length*(Se+Re),k=(m+w)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(v,k,12)}b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let w=0;w<r.dates.length;w++){const k=r.dates[w],S=Pe+w*(Se+Re)+Se/2,D=k.getUTCDay()===0||k.getUTCDay()===6;b.fillStyle=D?"#475569":"#64748b",b.fillText(dl(k),S,32)}b.beginPath(),b.strokeStyle="#1e293b",b.lineWidth=1,b.moveTo(0,je-.5),b.lineTo(y,je-.5),b.stroke();for(let w=0;w<r.assignees.length;w++){const k=r.assignees[w],S=je+w*(Se+Re);b.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="left",b.textBaseline="middle",b.fillStyle="#cbd5e1",b.save(),b.beginPath(),b.rect(0,S,Pe-8,Se),b.clip(),b.fillText(k,8,S+Se/2),b.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],I=`${k}|${dt(E)}`,M=r.cells.get(I),R=(M==null?void 0:M.count)??0,_=Pe+D*(Se+Re),x=hl(R),O=fl(R,r.maxCount);b.globalAlpha=O,b.fillStyle=x,h(b,_,S,Se,Se,ll),b.fill(),R>=2&&(b.globalAlpha=1,b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle",b.fillStyle="#fff",b.fillText(String(R),_+Se/2,S+Se/2)),b.globalAlpha=1}}c.appendChild(g),g.addEventListener("mousemove",w=>{if(!n)return;const k=g.getBoundingClientRect(),S=w.clientX-k.left,D=w.clientY-k.top,E=Math.floor((S-Pe)/(Se+Re)),I=Math.floor((D-je)/(Se+Re));if(E<0||E>=r.dates.length||I<0||I>=r.assignees.length||S<Pe||D<je){n.classList.remove("ng-visible");return}const M=r.dates[E],R=r.assignees[I],_=`${R}|${dt(M)}`,x=r.cells.get(_);if(!x||x.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const O=document.createElement("div");O.className="ng-heatmap-tooltip-date",O.textContent=`${R} - ${gl(M)}`,n.appendChild(O);for(const W of x.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const N=w.clientX+12,Y=w.clientY+12;n.style.left=N+"px",n.style.top=Y+"px"}),g.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),g.addEventListener("click",w=>{if(!e)return;const k=g.getBoundingClientRect(),S=w.clientX-k.left,D=w.clientY-k.top,E=Math.floor((S-Pe)/(Se+Re)),I=Math.floor((D-je)/(Se+Re));if(E<0||E>=r.dates.length||I<0||I>=r.assignees.length||S<Pe||D<je)return;const M=r.dates[E],_=`${r.assignees[I]}|${dt(M)}`,x=r.cells.get(_);if(!(!x||x.count===0)){u();for(const O of x.tasks)e.dispatch({type:"SELECT_TASK",taskId:O.id,multi:!0})}})}function h(p,r,c,g,y,T){p.beginPath(),p.moveTo(r+T,c),p.lineTo(r+g-T,c),p.quadraticCurveTo(r+g,c,r+g,c+T),p.lineTo(r+g,c+y-T),p.quadraticCurveTo(r+g,c+y,r+g-T,c+y),p.lineTo(r+T,c+y),p.quadraticCurveTo(r,c+y,r,c+y-T),p.lineTo(r,c+T),p.quadraticCurveTo(r,c,r+T,c),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,pl();const r=p.on("heatmap:toggle",()=>a()),c=p.on("heatmap:show",()=>l()),g=p.on("heatmap:hide",()=>u());i.push(r,c,g)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const g=document.createElement("span");g.className="ng-heatmap-title",g.textContent="Resource Heatmap",c.appendChild(g);const y=document.createElement("div");y.className="ng-heatmap-legend";const T=[{color:fo,label:"None"},{color:po,label:"1 task"},{color:mo,label:"2 tasks"},{color:To,label:"3+ tasks"}];for(const b of T){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=b.color,y.appendChild(v);const m=document.createElement("span");m.textContent=b.label,y.appendChild(m)}c.appendChild(y);const f=document.createElement("button");f.className="ng-heatmap-close",f.textContent="Back to Gantt",f.addEventListener("click",u),c.appendChild(f),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),ml(),e=null,s=!1,o=null}}}const qe=200,Ze=80,So=12,wo=6,bl="rgba(255, 255, 255, 0.95)",vl="#cbd5e1",Sl="rgba(59, 130, 246, 0.3)",wl="rgba(59, 130, 246, 0.7)",El=1.5,Dl=2,kl=1,$n="nimbus-gantt-minimap-styles",Cl=864e5,Il=`
  .ng-minimap {
    position: absolute;
    bottom: ${So}px;
    right: ${So}px;
    width: ${qe}px;
    height: ${Ze}px;
    z-index: 900;
    border-radius: ${wo}px;
    border: 1px solid ${vl};
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
    overflow: hidden;
    cursor: pointer;
    user-select: none;
    transition: opacity 200ms ease, transform 200ms ease;
  }
  .ng-minimap.ng-hidden {
    opacity: 0;
    pointer-events: none;
    transform: scale(0.9);
  }
  .ng-minimap canvas {
    display: block;
    border-radius: ${wo}px;
  }
`;function Ml(){if(typeof document>"u"||document.getElementById($n))return;const e=document.createElement("style");e.id=$n,e.textContent=Il,document.head.appendChild(e)}function Al(){if(typeof document>"u")return;const e=document.getElementById($n);e&&e.remove()}function Ll(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,d=0,h=0,p=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function g(){o=!0,t&&t.classList.remove("ng-hidden")}function y(){o=!1,t&&t.classList.add("ng-hidden")}function T(w,k){const S=w/l-p/2,D=k/u-r/2;return{x:Math.max(0,Math.min(S,d-p)),y:Math.max(0,Math.min(D,h-r))}}function f(w){if(!e||!n)return;w.preventDefault(),i=!0;const k=n.getBoundingClientRect(),S=w.clientX-k.left,D=w.clientY-k.top,E=T(S,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function b(w){if(!i||!e||!n)return;w.preventDefault();const k=n.getBoundingClientRect(),S=Math.max(0,Math.min(w.clientX-k.left,qe)),D=Math.max(0,Math.min(w.clientY-k.top,Ze)),E=T(S,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function v(){i=!1}function m(w,k){if(!s||!n||!o)return;const S=window.devicePixelRatio||1;n.width=qe*S,n.height=Ze*S,n.style.width=qe+"px",n.style.height=Ze+"px",s.scale(S,S);const{config:D,scrollX:E,scrollY:I,dateRange:M}=w,R=e.getTimeScale(),_=Math.round((M.end.getTime()-M.start.getTime())/Cl),x=R.getColumnWidth();if(d=Math.max(_*x,1),h=Math.max(w.flatVisibleIds.length*D.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const A=t.parentElement;p=A.clientWidth-D.gridWidth,r=A.clientHeight-D.headerHeight}l=qe/Math.max(d,1),u=Ze/Math.max(h,1),s.fillStyle=bl,s.fillRect(0,0,qe,Ze);const O=new Map;for(const A of k)O.has(A.rowIndex)||O.set(A.rowIndex,[]),O.get(A.rowIndex).push(A);for(const A of k){const $=A.x*l,B=Math.max(A.width*l,1),Q=A.rowIndex*D.rowHeight*u;s.fillStyle=A.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect($,Q,B,Math.max(Dl,D.rowHeight*u-kl))}s.globalAlpha=1;const N=E*l,Y=I*u,W=p*l,K=r*u,q=Math.max(0,Math.min(N,qe-1)),U=Math.max(0,Math.min(Y,Ze-1)),C=Math.min(W,qe-q),P=Math.min(K,Ze-U);s.fillStyle=Sl,s.fillRect(q,U,C,P),s.strokeStyle=wl,s.lineWidth=El,s.strokeRect(q,U,C,P)}return{name:"MiniMapPlugin",install(w){e=w,Ml();const k=w.on("minimap:toggle",()=>c()),S=w.on("minimap:show",()=>g()),D=w.on("minimap:hide",()=>y());a.push(k,S,D),typeof document<"u"&&(document.addEventListener("mousemove",b),document.addEventListener("mouseup",v))},renderDOM(w,k){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",f),t.appendChild(n),w.appendChild(t));const S=(e==null?void 0:e.getLayouts())??[];m(k,S)},destroy(){a.forEach(w=>w()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",b),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,Al(),e=null,o=!0,i=!1}}}const Rl="#f59e0b",Pl=[6,4],$l=1,et=16,_l=4,Nl="rgba(15, 23, 42, 0.95)",Ol="#e2e8f0",Hl="#334155",xl=6,tt=10,Eo=220,Do=12,ko=13;function Bl(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Dt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Fl(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Dt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function Yl(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const d=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(h)*d,r=n+Math.sin(h)*d;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Dt(o,.25),e.lineWidth=.5,e.stroke()}function Ul(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Dt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function Wl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Dt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Xl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Dt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Co={flag:Fl,star:Yl,warning:Ul,info:Wl,deadline:Xl};function zl(e,t,n,s,o){e.save();const i=`${Do}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${ko}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let d=0;if(t.description){const T=t.description.split(" ");let f="";for(const b of T){const v=f?f+" "+b:b;e.measureText(v).width>Eo-tt*2&&f?(u.push(f),d=Math.max(d,e.measureText(f).width),f=b):f=v}f&&(u.push(f),d=Math.max(d,e.measureText(f).width))}const h=Math.min(Eo,Math.max(l,d)+tt*2),p=Do+4,r=ko+4,c=tt*2+r+(u.length>0?4+u.length*p:0);let g=n-h/2;const y=s-c-8;if(g<4&&(g=4),g+h>o-4&&(g=o-h-4),e.beginPath(),Gl(e,g,y,h,c,xl),e.fillStyle=Nl,e.fill(),e.strokeStyle=Hl,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Ol,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,g+tt,y+tt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let T=y+tt+r+4;for(const f of u)e.fillText(f,g+tt,T),T+=p}e.restore()}function Gl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Vl(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,d=null;function h(f){return n.find(b=>b.id===f)}function p(f){n.push(f),y()}function r(f){n=n.filter(b=>b.id!==f),y()}function c(f,b){const v=h(f);v&&(Object.assign(v,b),y())}function g(){return[...n]}function y(){if(!t)return;const f=t.getState();t.dispatch({type:"SET_SCROLL",x:f.scrollX,y:f.scrollY})}function T(f){const b=f.canvas;d!==b&&(d&&u&&d.removeEventListener("mousemove",u),d=b,u=v=>{const m=b.getBoundingClientRect();a=v.clientX-m.left,l=v.clientY-m.top;let w=null;for(const k of o){const S=a-k.x,D=l-k.y;if(Math.sqrt(S*S+D*D)<=k.size){w=k.note.id;break}}w!==s&&(s=w,b.style.cursor=s?"pointer":"",y())},b.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(f){t=f;const b=f.on("notes:add",(...k)=>{const S=k[0];S&&S.id&&S.date&&S.label&&p(S)}),v=f.on("notes:remove",(...k)=>{const S=k[0];S&&r(S)}),m=f.on("notes:update",(...k)=>{const S=k[0];if(S&&S.id){const{id:D,...E}=S;c(D,E)}}),w=f.on("notes:list",(...k)=>{const S=k[0];typeof S=="function"&&S(g())});i.push(b,v,m,w)},renderCanvas(f,b,v){if(!t||n.length===0)return;const{config:m,scrollX:w,scrollY:k,dateRange:S}=b,{theme:D}=m,E=m.headerHeight,I=t.getTimeScale();T(f);const M=f.canvas.width/(window.devicePixelRatio||1),R=f.canvas.height/(window.devicePixelRatio||1),_=E,x=R-_;o=[],f.save();for(const O of n){const N=Bl(O.date);if(N<S.start||N>S.end)continue;const Y=O.color||Rl,W=O.icon||"flag",K=I.dateToX(N)-w;if(K<-et||K>M+et)continue;f.save(),f.beginPath(),f.setLineDash(Pl),f.strokeStyle=Y,f.globalAlpha=.5,f.lineWidth=$l,f.moveTo(K,_),f.lineTo(K,_+x),f.stroke(),f.setLineDash([]),f.globalAlpha=1,f.restore();const q=K,U=_+_l+et/2,C=Co[W]||Co.flag;f.save(),f.beginPath(),f.arc(q,U,et/2+3,0,Math.PI*2),f.fillStyle="rgba(0, 0, 0, 0.4)",f.fill(),f.restore(),f.save(),C(f,q,U,et,Y),f.restore(),o.push({note:O,x:q,y:U,size:et/2+4}),s===O.id&&zl(f,O,q,U-et/2-4,M)}f.restore()},destroy(){i.forEach(f=>f()),i.length=0,d&&u&&d.removeEventListener("mousemove",u),t=null,d=null,u=null,s=null,o=[]}}}const Kl=500,jl=40,Io=7,Mo=3,Ao=5,ql=500,_n="nimbus-gantt-timetravel-styles",Lo={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Zl=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${jl}px;
    background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
    border-top: 1px solid #334155;
    display: flex;
    align-items: center;
    padding: 0 8px;
    gap: 6px;
    z-index: 950;
    user-select: none;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 11px;
    color: #94A3B8;
  }
  .ng-timetravel.ng-hidden {
    display: none;
  }
  .ng-timetravel-btn {
    background: #334155;
    border: 1px solid #475569;
    border-radius: 4px;
    color: #CBD5E1;
    cursor: pointer;
    padding: 2px 6px;
    font-size: 11px;
    line-height: 18px;
    transition: background 150ms ease, border-color 150ms ease;
    flex-shrink: 0;
  }
  .ng-timetravel-btn:hover {
    background: #475569;
    border-color: #64748B;
    color: #F1F5F9;
  }
  .ng-timetravel-btn.ng-active {
    background: #3B82F6;
    border-color: #60A5FA;
    color: #FFF;
  }
  .ng-timetravel-btn.ng-present {
    background: #065F46;
    border-color: #10B981;
    color: #A7F3D0;
  }
  .ng-timetravel-btn.ng-present:hover {
    background: #047857;
  }
  .ng-timetravel-track {
    flex: 1;
    height: 20px;
    position: relative;
    cursor: pointer;
    margin: 0 4px;
  }
  .ng-timetravel-rail {
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 2px;
    background: #475569;
    transform: translateY(-50%);
    border-radius: 1px;
  }
  .ng-timetravel-playhead {
    position: absolute;
    top: 50%;
    width: ${Io*2}px;
    height: ${Io*2}px;
    background: #3B82F6;
    border: 2px solid #93C5FD;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    cursor: grab;
    z-index: 2;
    transition: background 100ms ease;
    box-shadow: 0 0 6px rgba(59, 130, 246, 0.5);
  }
  .ng-timetravel-playhead:hover {
    background: #60A5FA;
  }
  .ng-timetravel-playhead.ng-dragging {
    cursor: grabbing;
    background: #93C5FD;
  }
  .ng-timetravel-dot {
    position: absolute;
    top: 50%;
    width: ${Mo*2}px;
    height: ${Mo*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${Ao*2}px;
    height: ${Ao*2}px;
  }
  .ng-timetravel-tooltip {
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    background: #1E293B;
    border: 1px solid #475569;
    border-radius: 6px;
    padding: 6px 10px;
    white-space: nowrap;
    font-size: 11px;
    color: #E2E8F0;
    pointer-events: none;
    opacity: 0;
    transition: opacity 150ms ease;
    z-index: 10;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    margin-bottom: 4px;
  }
  .ng-timetravel-dot:hover .ng-timetravel-tooltip {
    opacity: 1;
  }
  .ng-timetravel-counter {
    flex-shrink: 0;
    min-width: 60px;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }
  .ng-timetravel-speed {
    flex-shrink: 0;
    min-width: 28px;
    text-align: center;
  }
`;function Jl(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Ql(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function ec(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function tc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function nc(){if(typeof document>"u"||document.getElementById(_n))return;const e=document.createElement("style");e.id=_n,e.textContent=Zl,document.head.appendChild(e)}function sc(){if(typeof document>"u")return;const e=document.getElementById(_n);e&&e.remove()}const Ro=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),qt=[.5,1,2,4];function oc(e){const t=(e==null?void 0:e.maxSnapshots)??Kl,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,d=1;const h=[];let p=null,r=null,c=null,g=null,y=null,T=null,f=null,b=!1;function v(U){if(!s||a)return;const C=s.getState(),P=ec(C,U);i<o.length-1&&(o.length=i+1),o.push(P),o.length>t&&o.shift(),i=o.length-1}function m(U){if(!s||o.length===0)return;const C=Math.max(0,Math.min(U,o.length-1));i=C;const P=o[C];a=!0;const A=P.tasks.map(B=>({id:B.id,name:B.name,startDate:B.startDate,endDate:B.endDate,progress:B.progress,status:B.status})),$=P.dependencies.map(B=>({id:B.id,source:B.source,target:B.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:$}),a=!1,_()}function w(){o.length>0&&m(o.length-1),S()}function k(){if(l||o.length<=1)return;l=!0;const U=qt[d],C=ql/U;u=setInterval(()=>{if(i>=o.length-1){S();return}m(i+1)},C),_()}function S(){l=!1,u!==null&&(clearInterval(u),u=null),_()}function D(){l?S():k()}function E(){d=(d+1)%qt.length,l&&(S(),k()),_()}function I(){S(),i>0&&m(i-1)}function M(){S(),i<o.length-1&&m(i+1)}function R(){S(),o.length=0,i=-1,a=!1,_()}function _(){if(p){if(g){const U=o.length,C=U>0?i+1:0;g.textContent=`${C} / ${U}`}y&&(y.textContent=l?"⏸":"▶",y.classList.toggle("ng-active",l)),T&&(T.textContent=`${qt[d]}x`),x(),O()}}function x(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const U=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${U}%`}function O(){if(!f||!r||(f.innerHTML="",o.length===0))return;const U=200,C=o.length>U?Math.ceil(o.length/U):1;for(let P=0;P<o.length;P+=C){const A=o[P],$=o.length<=1?50:P/(o.length-1)*100,B=Jl(A.action.split(" ")[0]==="Loaded"?"SET_DATA":N(A.action)),Q=Lo[B]||Lo.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${$}%`,Z.style.background=Q;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${tc(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=P;Z.addEventListener("click",me=>{me.stopPropagation(),S(),m(ge)}),f.appendChild(Z)}}function N(U){return U.startsWith("Moved")?"TASK_MOVE":U.startsWith("Resized")?"TASK_RESIZE":U.startsWith("Added task")?"ADD_TASK":U.startsWith("Added dependency")?"ADD_DEPENDENCY":U.startsWith("Removed task")?"REMOVE_TASK":U.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":U.startsWith("Updated")?"UPDATE_TASK":(U.startsWith("Loaded"),"SET_DATA")}function Y(U){if(!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));S(),m(A)}function W(U){U.preventDefault(),U.stopPropagation(),b=!0,c&&c.classList.add("ng-dragging"),S()}function K(U){if(!b||!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));m(A)}function q(){b&&(b=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(U){s=U,nc(),h.push(U.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),U.on("timeTravel:scrub",(...C)=>{const P=C[0];S(),m(P)}),U.on("timeTravel:play",()=>k()),U.on("timeTravel:pause",()=>S()),U.on("timeTravel:present",()=>w()),U.on("timeTravel:clear",()=>R()),U.on("timeTravel:history",(...C)=>{const P=C[0];typeof P=="function"&&P([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(U,C){let P="";n&&Ro.has(U.type)&&s&&!a&&(P=Ql(U,s.getState())),C(U),n&&Ro.has(U.type)&&!a&&P&&v(P)},renderDOM(U,C){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const P=document.createElement("button");P.className="ng-timetravel-btn",P.textContent="◀",P.title="Step backward",P.addEventListener("click",()=>I()),p.appendChild(P),y=document.createElement("button"),y.className="ng-timetravel-btn",y.textContent="▶",y.title="Play / Pause",y.addEventListener("click",()=>D()),p.appendChild(y);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>M()),p.appendChild(A),T=document.createElement("span"),T.className="ng-timetravel-speed ng-timetravel-btn",T.textContent=`${qt[d]}x`,T.title="Click to cycle speed",T.addEventListener("click",()=>E()),p.appendChild(T),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",Y);const $=document.createElement("div");$.className="ng-timetravel-rail",r.appendChild($),f=document.createElement("div"),f.style.position="absolute",f.style.inset="0",r.appendChild(f),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",W),r.appendChild(c),p.appendChild(r),g=document.createElement("span"),g.className="ng-timetravel-counter",p.appendChild(g);const B=document.createElement("button");B.className="ng-timetravel-btn ng-present",B.textContent="Present",B.title="Return to latest state",B.addEventListener("click",()=>w()),p.appendChild(B),U.appendChild(p)}_()},destroy(){S();for(const U of h)U();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,c=null,g=null,y=null,T=null,f=null,sc(),o.length=0,i=-1,a=!1,l=!1,b=!1,s=null}}}const Po=864e5,ic=60,ac=2,$o=[6,4],Nn="nimbus-gantt-montecarlo-styles",_o={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},rc=.08,lc=`
  .ng-montecarlo-summary {
    position: absolute;
    top: 64px;
    right: 12px;
    width: 240px;
    background: linear-gradient(135deg, rgba(15, 23, 42, 0.95), rgba(30, 41, 59, 0.95));
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 12px;
    z-index: 900;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 12px;
    color: #CBD5E1;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
    backdrop-filter: blur(8px);
    transition: opacity 200ms ease, transform 200ms ease;
    user-select: none;
  }
  .ng-montecarlo-summary.ng-hidden {
    opacity: 0;
    pointer-events: none;
    transform: scale(0.95) translateY(-4px);
  }
  .ng-montecarlo-title {
    font-size: 13px;
    font-weight: 600;
    color: #F1F5F9;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ng-montecarlo-title::before {
    content: '';
    display: inline-block;
    width: 8px;
    height: 8px;
    background: #3B82F6;
    border-radius: 50%;
    animation: ng-mc-pulse 2s infinite;
  }
  @keyframes ng-mc-pulse {
    0%, 100% { opacity: 0.5; transform: scale(1); }
    50% { opacity: 1; transform: scale(1.2); }
  }
  .ng-montecarlo-row {
    display: flex;
    justify-content: space-between;
    padding: 3px 0;
    border-bottom: 1px solid rgba(51, 65, 85, 0.5);
  }
  .ng-montecarlo-row:last-child {
    border-bottom: none;
  }
  .ng-montecarlo-label {
    color: #94A3B8;
  }
  .ng-montecarlo-value {
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .ng-montecarlo-risk {
    margin-top: 8px;
    padding-top: 6px;
    border-top: 1px solid #334155;
    font-size: 11px;
    color: #F97316;
  }
  .ng-montecarlo-close {
    position: absolute;
    top: 8px;
    right: 8px;
    background: none;
    border: none;
    color: #64748B;
    cursor: pointer;
    font-size: 14px;
    line-height: 1;
    padding: 2px 4px;
  }
  .ng-montecarlo-close:hover {
    color: #CBD5E1;
  }
`;function On(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Zt(e,t){return Math.round((t.getTime()-e.getTime())/Po)}function nt(e,t){return new Date(e.getTime()+t*Po)}function No(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Oo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function cc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function dc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function uc(e,t){return e+Math.random()*(t-e)}function gc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const d=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(l),r=[];for(let y=0;y<u;y++)p[y]===0&&(r.push(y),d[y]=o[y],h[y]=o[y]+s[y]);let c=0;for(;c<r.length;){const y=r[c++],T=h[y],f=i[y];for(let b=0;b<f.length;b++){const v=f[b];T>d[v]&&(d[v]=T,h[v]=T+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let y=0;y<u;y++)h[y]===0&&s[y]>0&&(d[y]=o[y],h[y]=o[y]+s[y]);let g=0;for(let y=0;y<u;y++)h[y]>g&&(g=h[y]);return g}function hc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),d=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let T=0;T<e;T++)h[T]===0&&(r.push(T),a[T]=n[T],l[T]=n[T]+t[T]);let c=0;for(;c<r.length;){const T=r[c++];p.push(T);const f=l[T];for(const b of s[T])f>a[b]&&(a[b]=f,l[b]=f+t[b]),h[b]--,h[b]===0&&r.push(b)}for(let T=0;T<e;T++)l[T]===0&&t[T]>0&&(a[T]=n[T],l[T]=n[T]+t[T],p.push(T));let g=0;for(let T=0;T<e;T++)l[T]>g&&(g=l[T]);for(let T=0;T<e;T++)s[T].length===0?(d[T]=g,u[T]=g-t[T]):(d[T]=1/0,u[T]=1/0);for(let T=p.length-1;T>=0;T--){const f=p[T];if(d[f]===1/0){let b=1/0;for(const v of s[f])u[v]<b&&(b=u[v]);b===1/0?d[f]=g:d[f]=b,u[f]=d[f]-t[f]}}const y=new Set;for(let T=0;T<e;T++){const f=u[T]-a[T];Math.abs(f)<.5&&y.add(T)}return y}function fc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const $ of e.keys())u.set($,l.length),l.push($);const d=l.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const $ of e.values()){const B=On($.startDate).getTime();B<r&&(r=B)}const c=new Date(r);for(let $=0;$<d;$++){const B=e.get(l[$]),Q=On(B.startDate),Z=On(B.endDate);h[$]=Math.max(Zt(Q,Z),1),p[$]=Zt(c,Q)}const g=Array.from({length:d},()=>[]),y=Array.from({length:d},()=>[]),T=new Int32Array(d);for(const $ of t.values()){if(($.type||"FS")!=="FS")continue;const Q=u.get($.source),Z=u.get($.target);Q===void 0||Z===void 0||(g[Q].push(Z),y[Z].push(Q),T[Z]++)}const f=g.map($=>new Int32Array($)),b=y.map($=>new Int32Array($)),v=new Float64Array(s),m=new Float64Array(d),w=new Float64Array(d),k=new Float64Array(d),S=new Float64Array(d),D=new Float64Array(d),E=Math.max(1,Math.floor(s/100));for(let $=0;$<s;$++){for(let B=0;B<d;B++){const Q=h[B];let Z;switch(i){case"triangular":{const re=Q*(1-o),ge=Q,me=Q*(1+o*1.5);Z=cc(re,ge,me);break}case"normal":{Z=dc(Q,Q*o);break}case"uniform":{Z=uc(Q*(1-o),Q*(1+o));break}}m[B]=Math.max(.5,Z),w[B]+=m[B],k[B]+=m[B]*m[B],m[B]>h[B]&&S[B]++}if(v[$]=gc(l,u,h,m,p,f,b,T),$%E===0){const B=hc(d,m,p,f,b,T);for(const Q of B)D[Q]++}}const I=Array.from(v).sort(($,B)=>$-B),M=I.map($=>nt(c,$)),R=new Map;for(const $ of a){const B=Math.min(Math.floor($*I.length),I.length-1);R.set($,nt(c,I[B]))}let _=0;for(let $=0;$<s;$++)_+=I[$];const x=_/s,O=nt(c,x),N=Math.floor(s/2),Y=nt(c,I[N]);let W=0;for(let $=0;$<s;$++){const B=I[$]-x;W+=B*B}const K=Math.sqrt(W/s),q=nt(c,I[0]),U=nt(c,I[I.length-1]),C=new Map;for(let $=0;$<d;$++){const B=w[$]/s,Q=k[$]/s-B*B;C.set(l[$],{meanDuration:B,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:S[$]/s})}const P=Math.floor(s/E),A=new Map;for(let $=0;$<d;$++)D[$]>0&&A.set(l[$],D[$]/P);return{iterations:s,finishDates:M,percentiles:R,meanFinishDate:O,medianFinishDate:Y,earliestFinish:q,latestFinish:U,standardDeviation:K,taskRisk:C,criticalPathFrequency:A}}function pc(){if(typeof document>"u"||document.getElementById(Nn))return;const e=document.createElement("style");e.id=Nn,e.textContent=lc,document.head.appendChild(e)}function mc(){if(typeof document>"u")return;const e=document.getElementById(Nn);e&&e.remove()}function Tc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},g=n.getState();s=fc(g.tasks,g.dependencies,c),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",c=0;for(const[f,b]of s.criticalPathFrequency)b>c&&(c=b,r=f);let g=r;if(n){const f=n.getState().tasks.get(r);f&&(g=f.name)}let y=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const f of t.confidenceLevels){const b=s.percentiles.get(f);if(!b)continue;const v=Math.round(f*100),m=_o[f]||"#94A3B8";y+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${Oo(b)}</span>
        </div>
      `}if(y+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${Oo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const f=Math.round(c*100);y+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${g} (on critical path ${f}% of runs)
        </div>
      `}a.innerHTML=y;const T=a.querySelector(".ng-montecarlo-close");T&&T.addEventListener("click",()=>u())}function p(r,c){if(!s||!n||s.finishDates.length===0)return;const g=n.getTimeScale(),{headerHeight:y}=c.config,T=c.scrollX,f=r.canvas.width/(window.devicePixelRatio||1),b=r.canvas.height/(window.devicePixelRatio||1),v=y,m=b-v,w=s.earliestFinish,k=s.latestFinish,S=Math.max(Zt(w,k),1),D=g.getColumnWidth(),E=Math.max(D,ac),I=Math.max(Math.ceil(S),1),M=new Uint32Array(I);for(const N of s.finishDates){const Y=Zt(w,N),W=Math.min(Math.max(Math.floor(Y),0),I-1);M[W]++}let R=0;for(let N=0;N<I;N++)M[N]>R&&(R=M[N]);if(R===0)return;r.save(),r.beginPath(),r.rect(0,v,f,m),r.clip(),r.translate(-T,0);const _=s.finishDates[Math.floor(s.finishDates.length*.1)],x=s.finishDates[Math.floor(s.finishDates.length*.9)];if(_&&x){const N=g.dateToX(_),Y=g.dateToX(x),W=r.createLinearGradient(N,0,Y,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=rc*5,r.fillRect(N,v,Y-N,m),r.globalAlpha=1}const O=b-8;for(let N=0;N<I;N++){if(M[N]===0)continue;const Y=nt(w,N),W=g.dateToX(Y),K=M[N]/R*ic,q=I>1?N/(I-1):.5;let U,C,P;if(q<.5){const A=q*2;U=Math.round(34+200*A),C=Math.round(197+-18*A),P=Math.round(94+-86*A)}else{const A=(q-.5)*2;U=Math.round(234+5*A),C=Math.round(179+-111*A),P=Math.round(8+60*A)}r.fillStyle=`rgba(${U}, ${C}, ${P}, 0.6)`,r.fillRect(W,O-K,Math.max(E-1,1),K)}r.setLineDash($o),r.lineWidth=1.5;for(const[N,Y]of s.percentiles){const W=g.dateToX(Y),K=_o[N]||"#94A3B8",q=`P${Math.round(N*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,v),r.lineTo(W,b),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const U=r.measureText(`${q}: ${No(Y)}`).width,C=`${q}: ${No(Y)}`,P=U+8,A=16,$=W-P/2,B=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo($+3,B),r.lineTo($+P-3,B),r.arcTo($+P,B,$+P,B+3,3),r.lineTo($+P,B+A-3),r.arcTo($+P,B+A,$+P-3,B+A,3),r.lineTo($+3,B+A),r.arcTo($,B+A,$,B+A-3,3),r.lineTo($,B+3),r.arcTo($,B,$+3,B,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(C,W,B+3),r.setLineDash($o)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,pc(),i.push(r.on("montecarlo:run",(...c)=>{const g=c[0];l(g)}),r.on("montecarlo:result",(...c)=>{const g=c[0];typeof g=="function"&&g(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...c)=>{const g=c[0];g&&d(g)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,g){!o||!s||p(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),mc(),s=null,n=null}}}const Jt=864e5,Ho=400,Hn="nimbus-gantt-narrative-styles",xo=300;function Ye(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function xn(e,t){return Math.round((t.getTime()-e.getTime())/Jt)}function Bo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Fo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*Jt)}function Yo(e,t){return new Date(e.getTime()+t*Jt)}function yc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const I=Ye(E.startDate).getTime(),M=Ye(E.endDate).getTime();I<s&&(s=I),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=xn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const d=new Map,h=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(d.has(E.source)||d.set(E.source,[]),d.get(E.source).push(E.target),h.has(E.target)||h.set(E.target,[]),h.get(E.target).push(E.source));const p=wc(n,t),r=Fo(i),c=Fo(a),g=[];let y=r;for(;y.getTime()<=c.getTime();)g.push({start:new Date(y),end:Yo(y,6)}),y=Yo(y,7);const T=[];for(let E=0;E<g.length;E++){const I=g[E],M=I.start,R=I.end,_=[],x=[],O=[],N=[],Y=[],W=[],K=[];for(const A of n){const $=Ye(A.startDate),B=Ye(A.endDate);$>=M&&$<=R&&(_.push(A),A.isMilestone?(W.push(A),K.push(`Milestone: ${A.name}`)):K.push(`Started: ${A.name}`)),B>=M&&B<=R&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(x.push(A),K.push(`Completed: ${A.name}`)),$<=R&&B>=M&&(Y.push(A),$<M&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&O.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&N.push(A))}for(const A of n)if(A.isMilestone){const $=Ye(A.startDate);$>=M&&$<=R&&!W.includes(A)&&(W.push(A),K.push(`Milestone: ${A.name}`))}const q=Y.filter(A=>p.has(A.id)),U=bc(_,x,O,Y,q),C=vc(_,x,O,N,Y,q,W,d,e),P=`Week ${E+1} (${Bo(M)}–${Bo(R)})`;T.push({weekLabel:P,headline:U,body:C,metrics:{started:_.length,completed:x.length,delayed:O.length,onTrack:N.length},events:K})}const f=n.length,b=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,v=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,m=f-b-v,w=f>0?Math.round(b/f*100):0,k=w>=75?"strong":w>=50?"moderate":w>=25?"early-stage":"just getting started",S=`This project spans ${l} days across ${g.length} weeks with ${f} tasks. Progress is ${k} at ${w}% completion (${b} done, ${v} in progress, ${m} not started).`,D=Sc(n,p,d,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:S,chapters:T,insights:D}}function bc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function vc(e,t,n,s,o,i,a,l,u){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(g=>g.name).join(", ");d.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const g=l.get(c.id);if(g)for(const y of g){const T=u.get(y);T&&!r.includes(T.name)&&r.push(T.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,c)=>c[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function Sc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const T=e.filter(v=>t.has(v.id)),f=T.slice(0,4).map(v=>v.name).join(", "),b=T.length>4?` and ${T.length-4} more`:"";l.push(`The critical path runs through ${f}${b} — any delay here pushes the project finish.`)}const u=new Map;for(const T of e)T.assignee&&!T.isCompleted&&u.set(T.assignee,(u.get(T.assignee)||0)+1);const d=Array.from(u.entries()).sort((T,f)=>f[1]-T[1]);d.length>0&&d[0][1]>=2&&l.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const h=e.filter(T=>T.isCompleted?!1:Ye(T.startDate)<a&&(T.progress===void 0||T.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=xn(o,i),r=xn(o,a);if(r>0&&p>0){const T=Math.round(r/p*100),f=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,b=Math.round(f/e.length*100),v=b-T;Math.abs(v)>=5?v>0?l.push(`Project is running ahead: ${b}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is running behind: only ${b}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${b}% complete at ${T}% of elapsed time.`)}const c=e.filter(T=>{if(T.isCompleted||T.progress!==void 0&&T.progress>0)return!1;const f=s.get(T.id);return!f||f.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let g=0,y="";for(const T of e){const f=n.get(T.id);f&&f.length>g&&(g=f.length,y=T.name)}return g>=3&&l.push(`"${y}" is a bottleneck with ${g} downstream tasks depending on it.`),l}function wc(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const g=Ye(c.endDate).getTime();i.set(c.id,g)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),g=i.get(c);for(const y of s.get(c)){const T=n.get(y.target),f=Ye(T.endDate).getTime()-Ye(T.startDate).getTime(),b=g+y.lag*Jt+f;b>i.get(y.target)&&i.set(y.target,b);const v=l.get(y.target)-1;l.set(y.target,v),v===0&&a.push(y.target)}}let u=-1/0,d="";for(const[c,g]of i)g>u&&(u=g,d=c);if(!d)return new Set;const h=new Set,p=new Map;for(const c of e)p.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||p.get(c.target).push({source:c.source,lag:c.lag||0}));let r=d;for(;r;){h.add(r);const c=p.get(r);if(!c||c.length===0)break;let g="",y=-1/0;for(const T of c){const f=i.get(T.source)||0;f>y&&(y=f,g=T.source)}if(!g||h.has(g))break;r=g}return h}const Ec=`
  .ng-narrative-btn {
    position: absolute;
    bottom: 16px;
    right: 64px;
    height: 36px;
    padding: 0 14px;
    border-radius: 18px;
    background: rgba(99, 102, 241, 0.9);
    color: #fff;
    border: none;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    z-index: 1000;
    transition: background 200ms ease, transform 200ms ease;
    user-select: none;
    display: flex;
    align-items: center;
    gap: 6px;
    line-height: 1;
  }
  .ng-narrative-btn:hover {
    background: rgba(99, 102, 241, 1);
    transform: scale(1.04);
  }
  .ng-narrative-btn-icon {
    font-size: 16px;
  }

  .ng-narrative-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 1001;
    opacity: 0;
    pointer-events: none;
    transition: opacity ${xo}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Ho}px;
    width: ${Ho}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${xo}ms ease;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 13px;
  }
  .ng-narrative-panel.ng-open {
    right: 0;
  }

  .ng-narrative-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid #333;
    font-size: 15px;
    font-weight: 600;
    position: sticky;
    top: 0;
    background: #1e1e2e;
    z-index: 1;
  }
  .ng-narrative-header-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ng-narrative-close {
    background: none;
    border: none;
    color: #999;
    font-size: 20px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .ng-narrative-close:hover {
    color: #fff;
  }

  .ng-narrative-refresh {
    background: none;
    border: none;
    color: #888;
    font-size: 16px;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 4px;
    transition: color 150ms, background 150ms;
  }
  .ng-narrative-refresh:hover {
    color: #fff;
    background: rgba(255,255,255,0.08);
  }

  .ng-narrative-summary {
    padding: 16px;
    border-bottom: 1px solid #2a2a3a;
    font-size: 13px;
    line-height: 1.6;
    color: #cbd5e1;
  }

  .ng-narrative-chapter {
    border-bottom: 1px solid #2a2a3a;
  }

  .ng-narrative-chapter-header {
    padding: 12px 16px;
    font-weight: 600;
    font-size: 13px;
    border-left: 4px solid;
  }
  .ng-narrative-chapter-header.ng-good {
    border-left-color: #22c55e;
    background: rgba(34, 197, 94, 0.06);
  }
  .ng-narrative-chapter-header.ng-mixed {
    border-left-color: #f59e0b;
    background: rgba(245, 158, 11, 0.06);
  }
  .ng-narrative-chapter-header.ng-troubled {
    border-left-color: #ef4444;
    background: rgba(239, 68, 68, 0.06);
  }
  .ng-narrative-chapter-header.ng-quiet {
    border-left-color: #64748b;
    background: rgba(100, 116, 139, 0.06);
  }

  .ng-narrative-week-label {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #888;
    margin-bottom: 4px;
  }

  .ng-narrative-headline {
    font-size: 13px;
    color: #e2e8f0;
  }

  .ng-narrative-metrics {
    display: flex;
    gap: 6px;
    padding: 8px 16px;
    flex-wrap: wrap;
  }

  .ng-narrative-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
  }
  .ng-narrative-badge.ng-started {
    background: rgba(59, 130, 246, 0.15);
    color: #60a5fa;
  }
  .ng-narrative-badge.ng-completed {
    background: rgba(34, 197, 94, 0.15);
    color: #4ade80;
  }
  .ng-narrative-badge.ng-delayed {
    background: rgba(239, 68, 68, 0.15);
    color: #f87171;
  }
  .ng-narrative-badge.ng-ontrack {
    background: rgba(245, 158, 11, 0.15);
    color: #fbbf24;
  }

  .ng-narrative-body {
    padding: 8px 16px 16px;
    font-size: 12.5px;
    line-height: 1.65;
    color: #94a3b8;
  }

  .ng-narrative-insights {
    padding: 16px;
  }
  .ng-narrative-insights-title {
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 12px;
    color: #e2e8f0;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ng-narrative-insight {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin-bottom: 10px;
    font-size: 12.5px;
    line-height: 1.55;
    color: #94a3b8;
  }
  .ng-narrative-insight-icon {
    flex-shrink: 0;
    font-size: 14px;
    margin-top: 1px;
  }

  .ng-narrative-empty {
    padding: 40px 16px;
    text-align: center;
    color: #64748b;
    font-size: 13px;
  }

  .ng-narrative-timestamp {
    padding: 12px 16px;
    font-size: 10px;
    color: #475569;
    text-align: center;
    border-top: 1px solid #2a2a3a;
  }
`;function Dc(){if(typeof document>"u"||document.getElementById(Hn))return;const e=document.createElement("style");e.id=Hn,e.textContent=Ec,document.head.appendChild(e)}function kc(){if(typeof document>"u")return;const e=document.getElementById(Hn);e&&e.remove()}function Cc(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Ic(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=yc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const g=document.createElement("span");g.textContent="📖",c.appendChild(g);const y=document.createElement("span");y.textContent="Project Story",c.appendChild(y),r.appendChild(c);const T=document.createElement("div");T.style.display="flex",T.style.alignItems="center",T.style.gap="4px";const f=document.createElement("button");f.className="ng-narrative-refresh",f.innerHTML="↻",f.title="Regenerate",f.addEventListener("click",()=>{l(),h()}),T.appendChild(f);const b=document.createElement("button");b.className="ng-narrative-close",b.innerHTML="×",b.addEventListener("click",d),T.appendChild(b),r.appendChild(T),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const k=document.createElement("div");k.className="ng-narrative-empty",k.textContent="No weekly chapters to display.",a.appendChild(k)}else for(const k of t.chapters){const S=document.createElement("div");S.className="ng-narrative-chapter";const D=Cc(k),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const I=document.createElement("div");I.className="ng-narrative-week-label",I.textContent=k.weekLabel,E.appendChild(I);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=k.headline,E.appendChild(M),S.appendChild(E);const R=document.createElement("div");if(R.className="ng-narrative-metrics",k.metrics.started>0&&R.appendChild(p("started",`${k.metrics.started} started`)),k.metrics.completed>0&&R.appendChild(p("completed",`${k.metrics.completed} done`)),k.metrics.delayed>0&&R.appendChild(p("delayed",`${k.metrics.delayed} delayed`)),k.metrics.onTrack>0&&R.appendChild(p("ontrack",`${k.metrics.onTrack} on track`)),R.children.length>0&&S.appendChild(R),k.body){const _=document.createElement("div");_.className="ng-narrative-body",_.textContent=k.body,S.appendChild(_)}a.appendChild(S)}if(t.insights.length>0){const k=document.createElement("div");k.className="ng-narrative-insights";const S=document.createElement("div");S.className="ng-narrative-insights-title",S.innerHTML="<span>💡</span> Key Insights",k.appendChild(S);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const I=document.createElement("span");I.className="ng-narrative-insight-icon",I.textContent="•",E.appendChild(I);const M=document.createElement("span");M.textContent=D,E.appendChild(M),k.appendChild(E)}a.appendChild(k)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const w=new Date(t.generatedAt);m.textContent=`Generated ${w.toLocaleString()}`,a.appendChild(m)}function p(r,c){const g=document.createElement("span");return g.className=`ng-narrative-badge ng-${r}`,g.textContent=c,g}return{name:"NarrativePlugin",install(r){e=r,Dc(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),kc(),e=null,t=null,n=!1}}}const Mc=864e5,Ac=10,Bn="nimbus-gantt-whatif-styles",Uo=.25,Lc=.6,Qt=6,Wo="#38A169",Xo="#E53E3E",zo="#A0AEC0",Fn=36,Rc="#F6AD55",Go="#1a202c",Pc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Fn}px;
    background: ${Rc};
    color: ${Go};
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 12px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 13px;
    font-weight: 600;
    z-index: 1000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    user-select: none;
    transition: opacity 200ms ease;
  }
  .ng-whatif-banner.ng-hidden {
    opacity: 0;
    pointer-events: none;
    height: 0;
    overflow: hidden;
  }
  .ng-whatif-banner-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .ng-whatif-badge {
    background: rgba(0, 0, 0, 0.15);
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .ng-whatif-change-count {
    font-weight: 400;
    font-size: 12px;
    opacity: 0.8;
  }
  .ng-whatif-banner-right {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ng-whatif-btn {
    border: none;
    background: rgba(0, 0, 0, 0.1);
    color: ${Go};
    padding: 4px 10px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background 150ms ease;
  }
  .ng-whatif-btn:hover {
    background: rgba(0, 0, 0, 0.2);
  }
  .ng-whatif-btn--danger {
    background: rgba(229, 62, 62, 0.2);
    color: #9B2C2C;
  }
  .ng-whatif-btn--danger:hover {
    background: rgba(229, 62, 62, 0.35);
  }
  .ng-whatif-btn--primary {
    background: rgba(49, 130, 206, 0.2);
    color: #2B6CB0;
  }
  .ng-whatif-btn--primary:hover {
    background: rgba(49, 130, 206, 0.35);
  }

  .ng-whatif-save-input {
    display: none;
    align-items: center;
    gap: 4px;
  }
  .ng-whatif-save-input.ng-active {
    display: flex;
  }
  .ng-whatif-save-input input {
    width: 140px;
    padding: 3px 6px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: 3px;
    font-size: 12px;
    background: rgba(255, 255, 255, 0.9);
    color: #1a202c;
    outline: none;
  }
  .ng-whatif-save-input input:focus {
    border-color: #3182ce;
    box-shadow: 0 0 0 2px rgba(49, 130, 206, 0.3);
  }

  .ng-whatif-panel {
    position: absolute;
    top: ${Fn}px;
    left: 0;
    bottom: 0;
    width: 280px;
    background: rgba(26, 32, 44, 0.97);
    border-right: 1px solid #2d3748;
    z-index: 950;
    transform: translateX(-100%);
    transition: transform 250ms ease;
    overflow-y: auto;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    color: #e2e8f0;
    padding: 16px;
  }
  .ng-whatif-panel.ng-open {
    transform: translateX(0);
  }
  .ng-whatif-panel-title {
    font-size: 14px;
    font-weight: 700;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .ng-whatif-panel-close {
    border: none;
    background: none;
    color: #a0aec0;
    cursor: pointer;
    font-size: 16px;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .ng-whatif-panel-close:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
  }
  .ng-whatif-scenario-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid #2d3748;
    border-radius: 6px;
    padding: 10px 12px;
    margin-bottom: 8px;
    cursor: pointer;
    transition: border-color 150ms ease, background 150ms ease;
  }
  .ng-whatif-scenario-card:hover {
    border-color: #4a5568;
    background: rgba(255, 255, 255, 0.08);
  }
  .ng-whatif-scenario-name {
    font-weight: 600;
    font-size: 13px;
    margin-bottom: 4px;
  }
  .ng-whatif-scenario-meta {
    font-size: 11px;
    color: #a0aec0;
    display: flex;
    gap: 8px;
  }
  .ng-whatif-scenario-actions {
    display: flex;
    gap: 4px;
    margin-top: 6px;
  }
  .ng-whatif-scenario-btn {
    border: none;
    background: rgba(255, 255, 255, 0.08);
    color: #a0aec0;
    padding: 2px 8px;
    border-radius: 3px;
    font-size: 11px;
    cursor: pointer;
  }
  .ng-whatif-scenario-btn:hover {
    background: rgba(255, 255, 255, 0.15);
    color: #e2e8f0;
  }
  .ng-whatif-scenario-btn--delete:hover {
    background: rgba(229, 62, 62, 0.3);
    color: #fc8181;
  }
  .ng-whatif-empty {
    font-size: 12px;
    color: #718096;
    text-align: center;
    padding: 20px 0;
  }

  .ng-whatif-summary {
    position: absolute;
    top: ${Fn+8}px;
    right: 12px;
    background: rgba(26, 32, 44, 0.95);
    border: 1px solid #2d3748;
    border-radius: 8px;
    padding: 12px 16px;
    z-index: 960;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 12px;
    color: #e2e8f0;
    min-width: 240px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    transition: opacity 200ms ease, transform 200ms ease;
  }
  .ng-whatif-summary.ng-hidden {
    opacity: 0;
    pointer-events: none;
    transform: translateY(-8px);
  }
  .ng-whatif-summary-title {
    font-weight: 700;
    font-size: 13px;
    margin-bottom: 8px;
  }
  .ng-whatif-summary-row {
    display: flex;
    justify-content: space-between;
    padding: 3px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }
  .ng-whatif-summary-row:last-child {
    border-bottom: none;
  }
  .ng-whatif-summary-label {
    color: #a0aec0;
  }
  .ng-whatif-summary-value {
    font-weight: 600;
  }
  .ng-whatif-summary-value--improved {
    color: ${Wo};
  }
  .ng-whatif-summary-value--worsened {
    color: ${Xo};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${zo};
  }
`;function Ue(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Vo(e){const t=Ue(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function en(e,t){return Math.round((t.getTime()-e.getTime())/Mc)}function Ko(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function $c(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function _c(e){return{...e}}function Nc(){if(typeof document>"u"||document.getElementById(Bn))return;const e=document.createElement("style");e.id=Bn,e.textContent=Pc,document.head.appendChild(e)}function Oc(){if(typeof document>"u")return;const e=document.getElementById(Bn);e&&e.remove()}function Hc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,$c(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,_c(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function jo(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function xc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,d=null,h=null,p=null,r=null,c=null,g=null;function y(){t||!e||(o=Hc(e.getState()),i=[],t=!0,n=!1,D())}function T(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),M(),_())}function f(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),M())}function b(C){if(!t||!e||!o)return;a.length>=Ac&&a.shift();const P=e.getState(),A=jo(P.tasks),$=Ue(o.projectFinish),B=Ue(A),Q=en($,B);let Z=0;for(const[ge,me]of o.tasks){const F=P.tasks.get(ge);if(!F){Z++;continue}(F.startDate!==me.startDate||F.endDate!==me.endDate||F.assignee!==me.assignee)&&Z++}for(const ge of P.tasks.keys())o.tasks.has(ge)||Z++;const re={id:Ko(),name:C,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:Q,tasksAffected:Z}};a.push(re),Y()}function v(C){if(!e||!o)return;const P=a.find(A=>A.id===C);if(P){t||y(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of P.changes)w(A);i=[...P.changes],E()}}function m(C){a=a.filter(P=>P.id!==C),Y()}function w(C){if(e)switch(C.type){case"move":case"resize":C.taskId&&C.after&&C.after.startDate&&C.after.endDate&&e.dispatch({type:C.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:C.taskId,startDate:C.after.startDate,endDate:C.after.endDate});break;case"add":C.after&&e.dispatch({type:"ADD_TASK",task:C.after});break;case"remove":C.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:C.taskId});break;case"reassign":C.taskId&&C.after&&e.dispatch({type:"UPDATE_TASK",taskId:C.taskId,changes:C.after});break;case"add-dependency":C.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:C.dependencyId||Ko(),source:C.dependency.source,target:C.dependency.target,type:C.dependency.type||"FS"}});break;case"remove-dependency":C.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:C.dependencyId});break}}function k(){t&&(n=!n,n?I():M())}function S(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const C=e.getState(),P=jo(C.tasks),A=Ue(o.projectFinish),$=Ue(P),B=en(A,$);let Q=0;for(const[Z,re]of o.tasks){const ge=C.tasks.get(Z);if(!ge){Q++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&Q++}for(const Z of C.tasks.keys())o.tasks.has(Z)||Q++;return{baselineFinish:o.projectFinish,sandboxFinish:P,deltaDays:B,tasksAffected:Q}}function D(){u&&u.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function I(){if(!h)return;const C=S();let P="ng-whatif-summary-value--unchanged",A="No change";C.deltaDays<0?(P="ng-whatif-summary-value--improved",A=`${Math.abs(C.deltaDays)} day${Math.abs(C.deltaDays)!==1?"s":""} earlier`):C.deltaDays>0&&(P="ng-whatif-summary-value--worsened",A=`${C.deltaDays} day${C.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${Vo(C.baselineFinish)} &rarr; ${Vo(C.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${P}">${A}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${C.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function R(){s=!s,d&&d.classList.toggle("ng-open",s),s&&Y()}function _(){s=!1,d&&d.classList.remove("ng-open")}function x(){r&&(r.classList.add("ng-active"),c==null||c.focus())}function O(){r&&r.classList.remove("ng-active"),c&&(c.value="")}function N(){if(!c)return;const C=c.value.trim();C&&(b(C),O())}function Y(){if(g){if(a.length===0){g.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}g.innerHTML=a.map(C=>{var B;const P=new Date(C.createdAt).toLocaleDateString(),A=((B=C.result)==null?void 0:B.criticalPathDelta)??0;let $="No impact";return A<0?$=`${Math.abs(A)}d earlier`:A>0&&($=`${A}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${C.id}">
            <div class="ng-whatif-scenario-name">${W(C.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${P}</span>
              <span>${C.changes.length} changes</span>
              <span>${$}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${C.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${C.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${C.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(C){const P=document.createElement("div");return P.textContent=C,P.innerHTML}function K(C){const P=C.target,A=P.getAttribute("data-action"),$=P.getAttribute("data-id");if(!(!A||!$))switch(A){case"load":v($),_();break;case"compare":v($),n=!0,I(),_();break;case"delete":m($);break}}function q(C,P){switch(C.type){case"TASK_MOVE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"move",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"TASK_RESIZE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"resize",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:C.task.id,after:{...C.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:C.taskId,before:P.tasks.get(C.taskId)?{...P.tasks.get(C.taskId)}:void 0});break;case"UPDATE_TASK":{const A=P.tasks.get(C.taskId);A&&i.push({type:"reassign",taskId:C.taskId,before:{...A},after:C.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:C.dependency.id,dependency:{source:C.dependency.source,target:C.dependency.target,type:C.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:C.dependencyId});break}E()}function U(C,P,A,$,B,Q){const Z=Math.min(Q,$/2,B/2);C.beginPath(),C.moveTo(P+Z,A),C.lineTo(P+$-Z,A),C.arcTo(P+$,A,P+$,A+Z,Z),C.lineTo(P+$,A+B-Z),C.arcTo(P+$,A+B,P+$-Z,A+B,Z),C.lineTo(P+Z,A+B),C.arcTo(P,A+B,P,A+B-Z,Z),C.lineTo(P,A+Z),C.arcTo(P,A,P+Z,A,Z),C.closePath()}return{name:"WhatIfPlugin",install(C){e=C,Nc(),l.push(C.on("whatif:enter",()=>y())),l.push(C.on("whatif:exit",()=>T())),l.push(C.on("whatif:compare",()=>k())),l.push(C.on("whatif:discard",()=>f())),l.push(C.on("whatif:save",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?b(A):x()})),l.push(C.on("whatif:load",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?v(A):R()})),l.push(C.on("whatif:list-scenarios",(...P)=>{const A=typeof P[0]=="function"?P[0]:void 0;A?A([...a]):R()})),l.push(C.on("whatif:delete-scenario",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A&&m(A)}))},middleware(C,P){if(!t){P(C);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(C.type)&&e){const $=e.getState();q(C,$)}P(C)},renderCanvas(C,P,A){if(!t||!e)return;const{theme:$,headerHeight:B,barHeight:Q}=P.config,Z=P.scrollX,re=P.scrollY,ge=B,me=e.getTimeScale(),F=$.barBorderRadius;if(C.save(),C.beginPath(),C.rect(0,ge,C.canvas.width,C.canvas.height-ge),C.clip(),C.translate(-Z,0),o){const ee=new Set;for(const j of A){const J=o.tasks.get(j.taskId),se=P.tasks.get(j.taskId);(!J&&se||J&&se&&(J.startDate!==se.startDate||J.endDate!==se.endDate||J.assignee!==se.assignee))&&ee.add(j.taskId)}for(const j of A){if(!ee.has(j.taskId))continue;const J=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>C.canvas.height||(C.save(),C.setLineDash([4,3]),C.strokeStyle="#F6AD55",C.lineWidth=2,U(C,J,se,de,ie,F),C.stroke(),C.restore())}}if(n&&o){const ee=Q*Lc;for(const j of A){if(j.isMilestone)continue;const J=o.tasks.get(j.taskId);if(!J)continue;const se=P.tasks.get(j.taskId);if(!se)continue;const de=Ue(J.startDate),ie=Ue(J.endDate),fe=Ue(se.startDate),ce=Ue(se.endDate),Te=en(de,fe),ye=en(ie,ce);if(Te===0&&ye===0)continue;let X=zo;ye<0?X=Wo:ye>0&&(X=Xo);const L=me.dateToX(de),H=me.dateToX(ie),z=Math.max(H-L,2),G=j.barY-re,V=G+Q+2;C.save(),C.globalAlpha=Uo,C.fillStyle=X,U(C,L,V,z,ee,F),C.fill(),C.globalAlpha=Uo*2,C.strokeStyle=X,C.lineWidth=1,C.stroke(),C.restore();const te=L+z/2,oe=V+ee/2,ae=j.x+j.width/2,le=G+Q/2;C.save(),C.globalAlpha=.6,C.strokeStyle=X,C.lineWidth=1.5,C.setLineDash([3,2]),C.beginPath(),C.moveTo(te,oe),C.lineTo(ae,le),C.stroke();const pe=Math.atan2(le-oe,ae-te),be=ae,Ce=le;C.setLineDash([]),C.beginPath(),C.moveTo(be,Ce),C.lineTo(be-Qt*Math.cos(pe-Math.PI/6),Ce-Qt*Math.sin(pe-Math.PI/6)),C.lineTo(be-Qt*Math.cos(pe+Math.PI/6),Ce-Qt*Math.sin(pe+Math.PI/6)),C.closePath(),C.fillStyle=X,C.fill(),C.restore()}}C.restore()},renderDOM(C,P){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const $=document.createElement("span");$.className="ng-whatif-badge",$.textContent="What-If Mode",A.appendChild($);const B=document.createElement("span");B.textContent="Changes are hypothetical",B.style.fontSize="12px",B.style.opacity="0.7",A.appendChild(B);const Q=document.createElement("span");Q.textContent="·",Q.style.opacity="0.4",A.appendChild(Q),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",A.appendChild(p),u.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",c=document.createElement("input"),c.type="text",c.placeholder="Scenario name...",c.addEventListener("keydown",se=>{se.key==="Enter"&&N(),se.key==="Escape"&&O()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",N);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>O()),r.appendChild(c),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const me=document.createElement("button");me.className="ng-whatif-btn",me.textContent="Scenarios",me.addEventListener("click",()=>R()),Z.appendChild(me);const F=document.createElement("button");F.className="ng-whatif-btn ng-whatif-btn--primary",F.textContent="Compare with Baseline",F.addEventListener("click",()=>k()),Z.appendChild(F);const ee=document.createElement("button");ee.className="ng-whatif-btn",ee.textContent="Save Scenario",ee.addEventListener("click",()=>x()),Z.appendChild(ee);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>f()),Z.appendChild(j);const J=document.createElement("button");J.className="ng-whatif-btn ng-whatif-btn--danger",J.textContent="Exit",J.addEventListener("click",()=>T()),Z.appendChild(J),u.appendChild(Z),C.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",C.appendChild(h)),!d){d=document.createElement("div"),d.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const $=document.createElement("span");$.textContent="Saved Scenarios",A.appendChild($);const B=document.createElement("button");B.className="ng-whatif-panel-close",B.textContent="×",B.addEventListener("click",()=>_()),A.appendChild(B),d.appendChild(A),g=document.createElement("div"),g.addEventListener("click",K),d.appendChild(g),C.appendChild(d),Y()}D(),n&&I()},destroy(){for(const C of l)C();l.length=0,u&&(u.remove(),u=null),d&&(d.remove(),d=null),h&&(h.remove(),h=null),p=null,r=null,c=null,g=null,Oc(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Yn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},Bc=261.63;function Fc(e){return Bc*Math.pow(2,e/12)}function Yc(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return Fc(n?a+12:a)}const Un="nimbus-gantt-sonification-styles",Wn=64,tn=64,qo=.05,Uc=.1,Wc=.7,Zo=.2,Xn="#F6AD55",Xc=2,zc="rgba(246, 173, 85, 0.35)",Jo=12,Gc=`
  .ng-sonification-controls {
    position: absolute;
    bottom: 12px;
    left: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(26, 32, 44, 0.95);
    border: 1px solid #2d3748;
    border-radius: 8px;
    padding: 8px 12px;
    z-index: 900;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 12px;
    color: #e2e8f0;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    user-select: none;
    transition: opacity 200ms ease;
  }
  .ng-sonification-controls.ng-hidden {
    opacity: 0;
    pointer-events: none;
  }
  .ng-son-btn {
    border: none;
    background: rgba(255, 255, 255, 0.08);
    color: #e2e8f0;
    width: 32px;
    height: 32px;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    transition: background 150ms ease;
  }
  .ng-son-btn:hover {
    background: rgba(255, 255, 255, 0.15);
  }
  .ng-son-btn--active {
    background: rgba(246, 173, 85, 0.25);
    color: #F6AD55;
  }
  .ng-son-sep {
    width: 1px;
    height: 24px;
    background: #2d3748;
  }
  .ng-son-label {
    font-size: 10px;
    color: #a0aec0;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .ng-son-slider {
    width: 60px;
    height: 4px;
    -webkit-appearance: none;
    appearance: none;
    background: #2d3748;
    border-radius: 2px;
    outline: none;
    cursor: pointer;
  }
  .ng-son-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #e2e8f0;
    cursor: pointer;
  }
  .ng-son-slider::-moz-range-thumb {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #e2e8f0;
    border: none;
    cursor: pointer;
  }
  .ng-son-select {
    background: #2d3748;
    color: #e2e8f0;
    border: 1px solid #4a5568;
    border-radius: 4px;
    padding: 2px 4px;
    font-size: 11px;
    cursor: pointer;
    outline: none;
  }

  .ng-sonification-waveform {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Wn}px;
    z-index: 850;
    pointer-events: none;
    transition: opacity 300ms ease;
  }
  .ng-sonification-waveform.ng-hidden {
    opacity: 0;
  }
  .ng-sonification-waveform canvas {
    display: block;
    width: 100%;
    height: 100%;
  }
`;function zn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Vc(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=Gc,document.head.appendChild(e)}function Kc(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function jc(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,d=null,h=null;const p=new Map;let r="stopped",c=0,g=0,y=0,T=0,f=0,b=0,v=0,m=null,w=null,k=null,S=null,D=null,E=null;const I=[];let M=[],R=[];function _(){if(l)return;const F=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;F&&(l=new F,u=l.createGain(),u.gain.value=i,d=l.createAnalyser(),d.fftSize=256,h=new Uint8Array(d.frequencyBinCount),u.connect(d),d.connect(l.destination))}function x(){l&&l.state==="suspended"&&l.resume()}function O(){if(!a)return;const F=a.getState(),ee=Date.now();let j=1/0,J=-1/0;const se=[],de=new Set,ie=F.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of F.tasks){const ye=zn(Te.startDate).getTime(),X=zn(Te.endDate).getTime();ye<j&&(j=ye),X>J&&(J=X);const L=Te.groupId||"__default__";de.add(L);const H=fe.get(ce)??0,z=!Te.isCompleted&&X<ee&&(Te.progress??0)<1;se.push({id:ce,startMs:ye,endMs:X,rowIndex:H,progress:Te.progress??0,groupId:L,isCritical:!1,isOverdue:z})}M=se,R=Array.from(de),f=j===1/0?0:j,b=J===-1/0?0:J,v=Math.max(b-f,1)}function N(F){if(!l||!u||p.has(F.id))return;const ee=Yn[n]||Yn.major,j=Yc(F.rowIndex,ee,F.isCritical),J=l.createOscillator();J.type=s,J.frequency.value=j,F.isOverdue&&(J.detune.value=25);const se=.3+F.progress*.7,de=F.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+qo),fe.gain.linearRampToValueAtTime(ie*Wc,l.currentTime+qo+Uc);const ce=l.createStereoPanner();if(R.length<=1)ce.pan.value=0;else{const Te=R.indexOf(F.groupId);ce.pan.value=R.length>1?Te/(R.length-1)*2-1:0}J.connect(fe),fe.connect(ce),ce.connect(u),J.start(),p.set(F.id,{taskId:F.id,oscillator:J,gainNode:fe,panNode:ce})}function Y(F){const ee=p.get(F);if(!ee||!l)return;const j=l.currentTime;ee.gainNode.gain.cancelScheduledValues(j),ee.gainNode.gain.setValueAtTime(ee.gainNode.gain.value,j),ee.gainNode.gain.linearRampToValueAtTime(0,j+Zo),ee.oscillator.stop(j+Zo+.05),p.delete(F)}function W(){for(const F of Array.from(p.keys()))Y(F)}function K(){if(r!=="playing"||!l)return;const F=l.currentTime-c;if(g=Math.min(F/o,1),g>=1){C();return}const ee=f+g*v;for(const j of M){const J=ee>=j.startMs&&ee<j.endMs,se=p.has(j.id);J&&!se?N(j):!J&&se&&Y(j.id)}Z(),T=requestAnimationFrame(K)}function q(){_(),x(),l&&(O(),r==="paused"?c=l.currentTime-y*o:(c=l.currentTime,g=0),r="playing",$(),B(),T=requestAnimationFrame(K))}function U(){r==="playing"&&(r="paused",y=g,W(),cancelAnimationFrame(T),$())}function C(){r="stopped",g=0,y=0,W(),cancelAnimationFrame(T),$(),Q()}function P(){r==="playing"?U():q()}function A(F){const ee=zn(F).getTime(),j=Math.max(0,Math.min((ee-f)/v,1));r==="playing"&&l?c=l.currentTime-j*o:(y=j,g=j)}function $(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=re(),D.classList.remove("ng-son-btn--active")))}function B(){w&&w.classList.remove("ng-hidden")}function Q(){w&&w.classList.add("ng-hidden")}function Z(){if(!d||!h||!S||!k)return;d.getByteFrequencyData(h);const F=k.width,ee=k.height;S.clearRect(0,0,F,ee);const j=S.createLinearGradient(0,0,0,ee);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),S.fillStyle=j,S.fillRect(0,0,F,ee);const J=F/tn*.8,se=F/tn*.2,de=Math.floor(h.length/tn);for(let ie=0;ie<tn;ie++){let fe=0;for(let z=0;z<de;z++)fe+=h[ie*de+z]??0;const ce=fe/de,Te=ce/255*ee*.85,ye=ie*(J+se),X=ee-Te,L=30+ce/255*15,H=55+ce/255*15;S.fillStyle=`hsl(${L}, 90%, ${H}%)`,S.fillRect(ye,X,J,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function me(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(F){a=F,Vc(),I.push(F.on("sonification:play",()=>q())),I.push(F.on("sonification:pause",()=>U())),I.push(F.on("sonification:stop",()=>C())),I.push(F.on("sonification:scrub",(...ee)=>{const j=typeof ee[0]=="string"?ee[0]:void 0;j&&A(j)})),I.push(F.on("sonification:configure",(...ee)=>{const j=ee[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(F,ee,j){if(r==="stopped"||!a)return;const{headerHeight:J}=ee.config,se=ee.scrollX,de=ee.scrollY,ie=J,fe=a.getTimeScale(),ce=f+g*v,Te=new Date(ce),ye=fe.dateToX(Te);F.save(),F.beginPath(),F.rect(0,ie,F.canvas.width,F.canvas.height-ie),F.clip(),F.translate(-se,0),F.save(),F.shadowColor=Xn,F.shadowBlur=Jo,F.strokeStyle=Xn,F.lineWidth=Xc,F.beginPath(),F.moveTo(ye,ie),F.lineTo(ye,F.canvas.height+de),F.stroke(),F.restore();const X=new Map;for(const L of j)X.set(L.taskId,L);for(const L of p.values()){const H=X.get(L.taskId);if(!H)continue;const z=H.x,G=H.barY-de,V=H.width,te=H.barHeight;if(G+te<ie||G>F.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);F.save(),F.globalAlpha=ae,F.shadowColor=zc,F.shadowBlur=Jo,F.fillStyle=Xn;const le=Math.min(ee.config.theme.barBorderRadius,V/2,te/2);F.beginPath(),F.moveTo(z+le,G),F.lineTo(z+V-le,G),F.arcTo(z+V,G,z+V,G+le,le),F.lineTo(z+V,G+te-le),F.arcTo(z+V,G+te,z+V-le,G+te,le),F.lineTo(z+le,G+te),F.arcTo(z,G+te,z,G+te-le,le),F.lineTo(z,G+le),F.arcTo(z,G,z+le,G,le),F.closePath(),F.fill(),F.restore()}F.restore()},renderDOM(F,ee){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=re(),D.title="Play / Pause",D.addEventListener("click",()=>P()),m.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=me(),E.title="Stop",E.addEventListener("click",()=>C()),m.appendChild(E);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const J=document.createElement("div");J.style.display="flex",J.style.flexDirection="column",J.style.alignItems="center",J.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",J.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),J.appendChild(de),m.appendChild(J);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const H of Object.keys(Yn)){const z=document.createElement("option");z.value=H,z.textContent=H.charAt(0).toUpperCase()+H.slice(1),H===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const ye=document.createElement("div");ye.style.display="flex",ye.style.flexDirection="column",ye.style.alignItems="center",ye.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",ye.appendChild(X);const L=document.createElement("input");L.type="range",L.className="ng-son-slider",L.min="0",L.max="100",L.value=String(Math.round(i*100)),L.addEventListener("input",()=>{i=Number(L.value)/100,u&&(u.gain.value=i)}),ye.appendChild(L),m.appendChild(ye),F.appendChild(m)}if(!w){w=document.createElement("div"),w.className="ng-sonification-waveform ng-hidden",k=document.createElement("canvas"),S=k.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,J=F.getBoundingClientRect();k.width=J.width*j,k.height=Wn*j,k.style.width="100%",k.style.height=Wn+"px",S&&S.scale(j,j),w.appendChild(k),F.appendChild(w)}},destroy(){for(const F of I)F();I.length=0,C(),W(),l&&(l.close(),l=null),u=null,d=null,h=null,m&&(m.remove(),m=null),w&&(w.remove(),w=null),k=null,S=null,D=null,E=null,Kc(),a=null,M=[],R=[]}}}return ne.BaselinePlugin=fa,ne.CLOUD_NIMBUS_PRIORITY_BUCKETS=Zi,ne.ConfigPanelPlugin=rl,ne.CriticalPathPlugin=oa,ne.DARK_THEME=cs,ne.DarkThemePlugin=Aa,ne.DependencyRenderer=as,ne.EventBus=Kn,ne.ExportPlugin=wa,ne.GroupingPlugin=Vi,ne.HeatmapViewPlugin=yl,ne.HitTest=os,ne.KeyboardPlugin=Ai,ne.LIGHT_THEME=rn,ne.LayoutEngine=Qn,ne.MSProjectPlugin=Ga,ne.MilestonePlugin=Oi,ne.MiniMapPlugin=Ll,ne.MonteCarloPlugin=Tc,ne.MotionControlPlugin=Fa,ne.NarrativePlugin=Ic,ne.NetworkGraphPlugin=tl,ne.NimbusGantt=ki,ne.PriorityGroupingPlugin=qi,ne.ResourceLevelingPlugin=ur,ne.RiskAnalysisPlugin=Hr,ne.SonificationPlugin=jc,ne.SplitTaskPlugin=nr,ne.TelemetryPlugin=Ha,ne.TimeScale=Zn,ne.TimeTravelPlugin=oc,ne.TimelineNotesPlugin=Vl,ne.TooltipManager=ls,ne.UndoRedoPlugin=Ii,ne.VirtualScrollPlugin=ya,ne.WhatIfPlugin=xc,ne.WorkCalendarPlugin=_a,ne.computeCPM=un,ne.exportMSProjectXML=vn,ne.hoursWeightedProgress=Ji,ne.importMSProjectXML=bn,ne.parseDate=gt,ne.resolveConfig=ds,Object.defineProperty(ne,Symbol.toStringTag,{value:"Module"}),ne})({});
//# sourceMappingURL=nimbus-gantt.iife.js.map
