var NimbusGantt=(function(ne){"use strict";function Oe(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(u);d||(d=[],n.set(u,d)),d.push(l)}const s=[];function o(l,u){const d=l.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return d!==h?d-h:l.name.localeCompare(u.name)}function i(l,u,d){const h=n.get(l);return h?(h.sort(o),h.map(p=>{const c=n.has(p.id)&&t.has(p.id),g=d,b={task:p,children:[],depth:u,expanded:c,visible:g,rowIndex:-1};return g&&(b.rowIndex=s.length,s.push(p.id)),b.children=i(p.id,u+1,g&&c),b})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function ut(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class Vn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=ti(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function ti(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Oe(n,e.expandedIds),a=ut(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Oe(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=ut(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}class Kn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const nn=864e5,ni=nn*7,si={day:40,week:120,month:180,quarter:200},jn=["January","February","March","April","May","June","July","August","September","October","November","December"],qn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class Zn{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=si[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/nn)}countWeeks(){return Math.ceil(this.totalMs/ni)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=Jn(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=sn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${jn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=Jn(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${qn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=sn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),d=this.dateToX(l);t.push({label:`${jn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:d-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:qn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=sn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=oi(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(l)}),i=a}return[t,n]}}function Jn(e,t){return new Date(e.getTime()+t*nn)}function oi(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function sn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class Qn{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const d=gt(u.startDate),h=gt(u.endDate),p=s.dateToX(d),r=s.dateToX(h)-p,c=Math.max(r,o.minBarWidth),g=a*o.rowHeight,b=g+(o.rowHeight-o.barHeight)/2,T=c*(u.progress||0),f=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:g,width:c,barY:b,barHeight:o.barHeight,progressWidth:T,color:f,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function gt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const on=864e5,es=1,ii=2,ai=.5,ri=2,ts=8,li=6,ns=2;class ci{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:d}=u,h=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=u.headerHeight,g=a-c;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,g),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,c,g,d),this.renderGridLines(s,c,g,d,h),this.renderAltRows(t,n,c,d,h,p);const b=this.getTodayX(t,u,s);u.showToday&&b!==null&&this.renderTodayBackground(b,s,c,g,d),this.renderGroupRowBgs(t,n,u,h,p,c,g),this.renderTaskBars(t,n,u,d,h,p,c,g),u.showToday&&b!==null&&this.renderTodayLine(b,c,g,d),o.restore(),this.renderHeader(s,u,d,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const d=l.getTime();for(;u.getTime()<=d;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+on),g=n.dateToX(r)-p;this.fillRect(p,s,g,o,i.timelineWeekendBg)}u.setTime(u.getTime()+on)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=ai;for(const u of l){const d=this.snapToPixel(u);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,d=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+on),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:u,displayWidth:d}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const c=p.y-i+a;c+h<a||c>a+l||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,c,d,h),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,c,d,2)),u.restore())}}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:d}=this,h=o.barBorderRadius;for(const p of n){const r=p.x,c=p.barY-a+l,g=p.width,b=p.barHeight;if(!(c+b<l||c>l+u)){if(p.isMilestone){this.renderMilestone(r,c,b,p.color,o,t.selectedIds.has(p.taskId));continue}if(this.fillRoundedRect(r,c,g,b,h,p.color),s.showProgress&&p.progressWidth>0){const T=this.darkenColor(p.color,.2);d.save(),d.beginPath(),this.roundedRectPath(r,c,g,b,h),d.clip(),d.fillStyle=T,d.fillRect(r,c,p.progressWidth,b),d.restore()}t.selectedIds.has(p.taskId)&&this.strokeRoundedRect(r,c,g,b,h,o.barSelectedBorder,ns),this.renderBarLabel(p,r,c,g,b,o)}}}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-ri*2)/2,d=n+s/2;l.save(),l.beginPath(),l.moveTo(t,d-u),l.lineTo(t+u,d),l.lineTo(t,d+u),l.lineTo(t-u,d),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=ns,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const d=l.measureText(t.label).width,h=s+i/2;d+ts*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+ts,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+li,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=ii,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const d=u.length||2,h=l/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<u.length;c++){const g=u[c],b=c*h;for(const T of g){const f=T.x-o,y=T.width;if(f+y<0||f>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=es;const v=this.snapToPixelRaw(f+y);i.moveTo(v,b),i.lineTo(v,b+h),i.stroke(),i.save(),i.beginPath(),i.rect(f,b,y,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(T.label,f+y/2,b+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=es,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const ss="ng-tree-grid-styles";function di(e,t){const n=e.querySelector(`#${ss}`);n&&n.remove();const s=document.createElement("style");s.id=ss,s.textContent=`
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

    .ng-group-row {
      font-weight: 600;
      letter-spacing: 0.01em;
    }

    .ng-group-row .ng-grid-cell-text {
      opacity: 0.9;
    }

    .ng-group-row .ng-expand-icon {
      opacity: 0.75;
    }

    .ng-group-row:hover {
      filter: brightness(0.97);
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
  `,e.insertBefore(s,e.firstChild)}function ui(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Ct(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class gi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;di(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=ui(n),u=l.map(d=>d.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,u.appendChild(d);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=d=>{const h=d.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),c[n]&&(c[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const d of t)l.set(d.task.id,d);for(const[d,h]of this.rows)a.has(d)||(h.remove(),this.rows.delete(d));let u=null;for(let d=0;d<t.length;d++){const h=t[d],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,d,s):(r=this.createRow(h,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const d=this.createCell(t,u,s);l.appendChild(d)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const d=document.createElement("span");d.className="ng-expand-icon",t.expanded&&d.classList.add("ng-expanded"),d.innerHTML="&#9654;",d.setAttribute("data-expand",t.task.id),o.appendChild(d)}else{const d=document.createElement("span");d.className="ng-expand-spacer",o.appendChild(d)}if(t.children.length===0&&!t.task.groupBg){const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",o.appendChild(d)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const d=document.createElement("span");d.className="ng-status-dot",d.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(d)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=Ct(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=Ct(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let d=0;d<a.length;d++){const h=a[d],p=l[d];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const c=`${n.depth*20+8}px`;p.style.paddingLeft!==c&&(p.style.paddingLeft=c);const g=p.querySelector(".ng-expand-icon"),b=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(g)n.expanded?g.classList.add("ng-expanded"):g.classList.remove("ng-expanded");else{b&&b.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(g){g.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const T=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!T){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const S=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");S?p.insertBefore(m,S):p.appendChild(m)}}else T&&T.remove();const f=p.querySelector(".ng-status-dot"),y=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(y&&n.children.length===0)if(f)f.style.background=y;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${y};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const S=p.querySelector(".ng-grid-cell-text");S?p.insertBefore(m,S):p.appendChild(m)}else f&&f.remove();const v=p.querySelector(".ng-grid-cell-text");if(v){const m=Ct(n.task,h);v.textContent!==m&&(v.textContent=m)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",p.appendChild(c)}}else r&&(p.textContent="")}else{const r=Ct(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class hi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class os{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const is=864e5;function an(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/is)}function ht(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function st(e,t){const n=ht(e),s=new Date(n.getTime()+t*is),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function fi(e,t,n){return Math.max(t,Math.min(n,e))}const pi=3,mi=300;class Ti{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=t,this.options=n,this.hitTest=new os,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none")return;t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l&&(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(t.pointerId),this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly)){const u=yi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s})}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<pi?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<mi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var l,u,d,h,p,r,c,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale();n.config;const i=this.dragHit.type,a=t.clientX-this.dragStartX;switch(i){case"bar":{const b=an(a,o),T=st(this.dragOriginalStartDate,b),f=st(this.dragOriginalEndDate,b);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:T,endDate:f}),(u=(l=this.options).onTaskMove)==null||u.call(l,s,T,f);break}case"bar-left-edge":{const b=an(a,o),T=st(this.dragOriginalStartDate,b),f=ht(this.dragOriginalEndDate),v=ht(T).getTime()>=f.getTime()?st(this.dragOriginalEndDate,-1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:v,endDate:this.dragOriginalEndDate}),(h=(d=this.options).onTaskResize)==null||h.call(d,s,v,this.dragOriginalEndDate);break}case"bar-right-edge":{const b=an(a,o),T=st(this.dragOriginalEndDate,b),f=ht(this.dragOriginalStartDate),v=ht(T).getTime()<=f.getTime()?st(this.dragOriginalStartDate,1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:v}),(r=(p=this.options).onTaskResize)==null||r.call(p,s,this.dragOriginalStartDate,v);break}case"progress-handle":{const b=this.dragHit.layout,{canvasX:T}=this.toCanvasCoords(t),f=T-b.x,y=fi(f/b.width,0,1),v=Math.round(y*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:v}}),(g=(c=this.options).onTaskProgressChange)==null||g.call(c,s,v);break}}this.options.dispatch({type:"DRAG_END"})}}function yi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const ot=12,It=6,Mt=4,bi=3;class as{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const c=d.get(r.source),g=d.get(r.target);if(!c||!g)continue;const b=r.type||"FS",{sourceX:T,sourceY:f,targetX:y,targetY:v}=this.getConnectionPoints(b,c,g,a,l);this.drawRoutedPath(t,b,T,f,y,v,o),this.drawArrowhead(t,b,y,v,o),this.drawConnectionDot(t,T,f,o),this.drawConnectionDot(t,y,v,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",d=n==="FS"||n==="SS",h=u?s+ot:s-ot,p=d?i-ot:i+ot;if(u?d?p>=h:i+ot>=h:d?i-ot<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(h,o),t.lineTo(h,c),t.lineTo(p,c),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-It,o-Mt),t.lineTo(s-It,o+Mt)):(t.moveTo(s,o),t.lineTo(s+It,o-Mt),t.lineTo(s+It,o+Mt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,bi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const At=12,vi=100,wi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Si=`
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
`;function it(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function rs(e){const t=e.split("-");if(t.length!==3)return it(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?it(e):`${wi[n]} ${s}`}function ft(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${it(e)}</span><span class="ng-tooltip-value">${it(t)}</span></div>`}function Di(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=ft("Status",e.status||"None"),i+=ft("Assignee",e.assignee||"Unassigned"),i+=ft("Dates",`${rs(e.startDate)} → ${rs(e.endDate)}`),n>0&&(i+=ft("Progress",`${n}%`)),s!=null&&(i+=ft("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${it(t)}"><span class="ng-tooltip-name">${it(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class ls{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Si,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const d=this.customRenderer(t);typeof d=="string"?this.tooltipEl.innerHTML=d:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(d))}else this.tooltipEl.innerHTML=Di(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+At,u=s+At;l+i.width>a.width&&(l=n-At-i.width),u+i.height>a.height&&(u=s-At-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},vi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const rn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},cs={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Ei=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function ds(e){const t=ki(e.theme);return{columns:e.columns??Ei,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function ki(e){return!e||e==="light"?{...rn}:e==="dark"?{...cs}:{...rn,...e}}const us="nimbus-gantt-root-styles";function Ci(){if(typeof document>"u"||document.getElementById(us))return;const e=document.createElement("style");e.id=us,e.textContent=`
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
  `,document.head.appendChild(e)}class Ii{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.container=t,this.config=ds(n),Ci(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=Oe(s,i),u=ut(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new Kn,this.store=new Vn(d),this.layoutEngine=new Qn,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new ci(this.timelinePanel),this.treeGrid=new gi(this.gridPanel),this.scrollManager=new hi(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new as,this.tooltipManager=new ls(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new Ti(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,c,g)=>{var b;p?this.tooltipManager.show(p,r,c,g):this.tooltipManager.hide();try{(b=n.onHover)==null||b.call(n,p,r,c,g)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const d=u.getContext("2d");d&&l.renderCanvas(d,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new Zn(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const t=this.store.getState(),{tree:n,flatIds:s}=Oe(t.tasks,t.expandedIds);t.tree=n,t.flatVisibleIds.length=0;for(const o of s)t.flatVisibleIds.push(o)}}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new Vn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function gs(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function hs(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of gs(a)){let u=s.get(l);u||(u=[],s.set(l,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const u of l)o.has(u)||(o.add(u),i.push(u))}return o}function Mi(e,t){const n=hs(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const Ai=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ln(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Li(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function d(c){s.push(c),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const c=ln(n.getState()),g=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const c=ln(n.getState()),g=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),p()):(c.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(c){n=c,u=c.on("render",()=>{if(l)return;const g=document.querySelector(".nimbus-gantt");g&&(l=g.parentElement??g,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,g){if(i){g(c);return}if(Ai.has(c.type)&&n){const b=ln(n.getState());d(b),o=[]}g(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const pt=["day","week","month","quarter"];function Ri(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function cn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Pi(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=Ri(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d>0&&e.dispatch({type:"SELECT_TASK",taskId:l[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[d+1]})}break}case"ArrowRight":{if(u)if(cn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(u)if(cn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!u)return;i.preventDefault();const d=a.tasks.get(u);if(d&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const d=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=pt.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:pt[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=pt.indexOf(a.zoomLevel);d<pt.length-1&&e.dispatch({type:"SET_ZOOM",level:pt[d+1]});break}case" ":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;cn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const fs="#D4A017",$i="rgba(212, 160, 23, 0.25)",_i=[6,4],Ni=1,Oi=2,Hi=4,ps=8,ms=10,Ts=16,xi=6;function Bi(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const c=r.x,g=r.barY-a,b=r.barHeight,T=g+b/2,f=r.color===l.barDefaultColor?fs:r.color||fs;t.save(),t.beginPath(),t.strokeStyle=$i,t.lineWidth=Ni,t.setLineDash(_i),t.moveTo(c,h),t.lineTo(c,h+p),t.stroke(),t.setLineDash([]),t.restore();const y=(b-Oi*2)/2;t.save(),t.beginPath(),t.moveTo(c,T-y),t.lineTo(c+y,T),t.lineTo(c,T+y),t.lineTo(c-y,T),t.closePath(),t.fillStyle=f,t.fill(),t.strokeStyle=ys(f,.25),t.lineWidth=1,t.stroke(),t.restore();const v=c+y+Hi,m=T-Ts/2;if(t.save(),t.beginPath(),t.strokeStyle=ys(f,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+Ts),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+ps,m+ms/2),t.lineTo(v,m+ms),t.closePath(),t.fillStyle=f,t.fill(),t.restore(),r.label){const S=v+ps+xi,k=T;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,S,k),t.restore()}}t.restore()},destroy(){e=null}}}function ys(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Fi="rgba(100, 116, 139, 0.12)",Yi="rgba(100, 116, 139, 0.25)",bs="#334155",Ui="rgba(100, 116, 139, 0.2)",Wi="#475569",Xi=8,zi=6,Gi=2,Xe=5,Vi=12,Ki=28,ji=8;function qi(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(h){const p=new Map,r=[];for(const c of h.flatVisibleIds){const g=h.tasks.get(c);if(g)if(g.groupId){let b=p.get(g.groupId);b||(b={groupId:g.groupId,groupName:g.groupName||g.groupId,taskIds:[],collapsed:t.has(g.groupId)},p.set(g.groupId,b)),b.taskIds.push(c)}else r.push(c)}n=Array.from(p.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const g=o.length,b=`__group_header__${c.groupId}`;if(o.push(b),s.set(g,c),!c.collapsed)for(const T of c.taskIds)o.push(T)}}function d(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const c=e.getState(),g=p.querySelector(".ng-timeline-panel");if(!g)return;const b=g.getBoundingClientRect(),T=r.clientY-b.top,f=c.config.headerHeight;if(T<f)return;const y=T-f+c.scrollY,v=Math.floor(y/c.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),d(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let c=!1;for(const g of r.tasks.values())if(g.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const g=new Set;for(const b of n)if(b.collapsed)for(const T of b.taskIds)g.add(T);if(g.size>0){const b=r.flatVisibleIds.filter(T=>!g.has(T));if(b.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const T of b)r.flatVisibleIds.push(T)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:c,scrollX:g,scrollY:b}=p,{theme:T}=c,f=c.headerHeight,y=c.rowHeight,v=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-f;h.save(),h.beginPath(),h.rect(0,f,v,m),h.clip();let S=0;const k=[];for(const w of p.flatVisibleIds){const E=p.tasks.get(w);E&&!E.groupId&&k.push(w)}S=k.length;for(const w of n){const E=f+S*y-b;if(E+y>=f&&E<f+m){h.fillStyle=Fi,h.fillRect(0,E,v,y),h.beginPath(),h.strokeStyle=Yi,h.lineWidth=1,h.moveTo(0,Math.round(E+y)+.5),h.lineTo(v,Math.round(E+y)+.5),h.stroke();const D=Vi,I=E+y/2;h.save(),h.beginPath(),h.fillStyle=bs,w.collapsed?(h.moveTo(D,I-Xe),h.lineTo(D+Xe,I),h.lineTo(D,I+Xe)):(h.moveTo(D-Xe/2,I-Xe/2),h.lineTo(D+Xe/2,I-Xe/2),h.lineTo(D,I+Xe/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${T.fontSize}px ${T.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=bs;const M=Ki,R=E+y/2;h.fillText(w.groupName,M,R);const _=h.measureText(w.groupName).width;h.restore();const x=`${w.taskIds.length}`;h.save(),h.font=`${T.fontSize-1}px ${T.fontFamily}`;const N=h.measureText(x).width+zi*2,Y=T.fontSize+Gi*2,W=M+_+ji,K=R-Y/2;h.beginPath();const q=Xi;h.moveTo(W+q,K),h.lineTo(W+N-q,K),h.arcTo(W+N,K,W+N,K+q,q),h.lineTo(W+N,K+Y-q),h.arcTo(W+N,K+Y,W+N-q,K+Y,q),h.lineTo(W+q,K+Y),h.arcTo(W,K+Y,W,K+Y-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=Ui,h.fill(),h.fillStyle=Wi,h.textBaseline="middle",h.textAlign="center",h.fillText(x,W+N/2,R),h.restore()}S+=1,w.collapsed||(S+=w.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const at="__bucket_header__";function vs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Zi(e){return e.groupId??null}function Ji(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function Qi(e){const t=[...e.buckets].sort((r,c)=>r.order-c.order),n=new Map;t.forEach((r,c)=>n.set(r.id,c));const s=e.getBucket??Zi,o=e.getBucketProgress??Ji,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function d(r,c){l=t.map(g=>({config:g,taskIds:[],allTaskIds:[],collapsed:i.has(g.id),progress:0,startDate:null,endDate:null,totalHours:0}));for(const g of c){const b=r.tasks.get(g);if(!b)continue;const T=s(b);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].taskIds.push(g)}for(const[g,b]of r.tasks){if(g.startsWith(at))continue;const T=s(b);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].allTaskIds.push(g)}for(const g of l){if(g.allTaskIds.length===0){g.progress=0,g.startDate=null,g.endDate=null,g.totalHours=0;continue}const b=[];let T=1/0,f=-1/0,y=0;for(const v of g.allTaskIds){const m=r.tasks.get(v);if(!m)continue;if(b.push(m),m.startDate){const k=gt(m.startDate).getTime();!isNaN(k)&&k<T&&(T=k)}if(m.endDate){const k=gt(m.endDate).getTime();!isNaN(k)&&k>f&&(f=k)}const S=m.metadata;typeof(S==null?void 0:S.hoursHigh)=="number"&&(y+=S.hoursHigh)}g.startDate=isFinite(T)?new Date(T):null,g.endDate=isFinite(f)?new Date(f):null,g.totalHours=y,g.progress=Math.max(0,Math.min(1,o(b)))}}function h(r){if(!r.startDate||!r.endDate)return null;const c=Math.round(r.progress*100),g=r.totalHours>0?`${r.totalHours}h (${c}%)`:`${r.allTaskIds.length} items`;return{id:`${at}${r.config.id}`,name:g,startDate:vs(r.startDate),endDate:vs(r.endDate),progress:r.progress,color:r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const c=a.getState();a.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...c)=>{const g=c[0];let b=null;typeof g=="string"?b=g:g&&typeof g=="object"&&"id"in g&&(b=String(g.id)),b&&b.startsWith(at)&&p(b.substring(at.length))}))},middleware(r,c){if(c(r),!a)return;const g=a.getState(),b=[];for(const y of g.tasks.keys())y.startsWith(at)&&b.push(y);for(const y of b)g.tasks.delete(y);const T=g.flatVisibleIds.filter(y=>!y.startsWith(at));let f=!1;for(const y of g.tasks.values())if(s(y)!=null){f=!0;break}if(!f){if(l=[],T.length!==g.flatVisibleIds.length){g.flatVisibleIds.length=0;for(const y of T)g.flatVisibleIds.push(y)}return}d(g,T);for(const y of l){if(y.allTaskIds.length===0)continue;const v=h(y);if(v){g.tasks.set(v.id,v);for(const m of y.allTaskIds){const S=g.tasks.get(m);S&&(S.parentId=v.id)}y.collapsed?g.expandedIds.delete(v.id):g.expandedIds.add(v.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const ea=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function ta(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const ws=864e5,na=6,sa=2,oa=2,ia=.18,aa=.4;function Ss(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function dn(e,t){return Math.round((t.getTime()-e.getTime())/ws)}function rt(e,t){return new Date(e.getTime()+t*ws)}function un(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const D of n)s.set(D,[]),o.set(D,[]),i.set(D,0);for(const D of t.values()){if((D.type||"FS")!=="FS"||!e.has(D.source)||!e.has(D.target))continue;const M=D.lag||0;s.get(D.source).push({target:D.target,lag:M,depId:D.id}),o.get(D.target).push({source:D.source,lag:M,depId:D.id}),i.set(D.target,(i.get(D.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[D,I]of e){const M=Ss(I.startDate),R=Ss(I.endDate);l.set(D,M),u.set(D,R),a.set(D,Math.max(dn(M,R),0))}const d=new Map,h=new Map,p=[],r=[],c=new Map(i);for(const D of n)c.get(D)===0&&(r.push(D),d.set(D,l.get(D)),h.set(D,u.get(D)));for(;r.length>0;){const D=r.shift();p.push(D),d.get(D);const I=h.get(D);for(const M of s.get(D)){const{target:R,lag:_}=M,x=rt(I,_),O=d.get(R);(!O||x.getTime()>O.getTime())&&(d.set(R,x),h.set(R,rt(x,a.get(R))));const N=c.get(R)-1;c.set(R,N),N===0&&r.push(R)}}for(const D of n)d.has(D)||(d.set(D,l.get(D)),h.set(D,u.get(D)),p.push(D));let g=-1/0;for(const D of h.values())D.getTime()>g&&(g=D.getTime());const b=new Date(g);let T=1/0;for(const D of d.values())D.getTime()<T&&(T=D.getTime());const f=new Date(T),y=dn(f,b),v=new Map,m=new Map;for(const D of n)s.get(D).length===0&&(m.set(D,b),v.set(D,rt(b,-a.get(D))));for(let D=p.length-1;D>=0;D--){const I=p[D];if(!m.has(I)){let M=1/0;for(const R of s.get(I)){const _=v.get(R.target);if(_){const x=rt(_,-R.lag);x.getTime()<M&&(M=x.getTime())}}M===1/0?m.set(I,b):m.set(I,new Date(M)),v.set(I,rt(m.get(I),-a.get(I)))}}for(const D of n)m.has(D)||(m.set(D,b),v.set(D,rt(b,-a.get(D))));const S=.5,k=new Set,w=new Map;for(const D of n){const I=d.get(D),M=h.get(D),R=v.get(D),_=m.get(D),x=dn(I,R),O=Math.abs(x)<S;O&&k.add(D),w.set(D,{earlyStart:I,earlyFinish:M,lateStart:R,lateFinish:_,totalFloat:x,isCritical:O})}const E=new Set;for(const D of t.values())(D.type||"FS")==="FS"&&k.has(D.source)&&k.has(D.target)&&E.add(D.id);return{criticalTaskIds:k,criticalDependencyIds:E,taskAnalysis:w,projectDuration:y}}function ra(){let e,t=null,n=[];function s(){const o=e.getState();t=un(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:d,barHeight:h}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,g=u,b=e.getTimeScale(),T=new Map;for(const m of a)T.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,g,o.canvas.width,o.canvas.height-g),o.clip(),o.translate(-r,0);for(const m of a){const S=t.taskAnalysis.get(m.taskId);if(!S||S.isCritical||S.totalFloat<=0)continue;const k=m.barY-c,w=h*aa,E=m.x+m.width,I=b.dateToX(S.lateFinish)-E;I>1&&(o.fillStyle=m.color,o.globalAlpha=ia,o.fillRect(E,k+h-w,I,w),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const S=m.x,k=m.barY-c,w=m.width,E=m.barHeight;if(!(k+E<g||k>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=na;for(let D=0;D<sa;D++){o.strokeStyle=p,o.lineWidth=oa,o.beginPath();const I=l.barBorderRadius,M=Math.min(I,w/2,E/2);o.moveTo(S+M,k),o.lineTo(S+w-M,k),o.arcTo(S+w,k,S+w,k+M,M),o.lineTo(S+w,k+E-M),o.arcTo(S+w,k+E,S+w-M,k+E,M),o.lineTo(S+M,k+E),o.arcTo(S,k+E,S,k+E-M,M),o.lineTo(S,k+M),o.arcTo(S,k,S+M,k,M),o.closePath(),o.stroke()}o.restore()}}const f=6,y=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const S=T.get(m.source),k=T.get(m.target);if(!S||!k)continue;const w=S.x+S.width,E=S.barY+S.barHeight/2-c,D=k.x,I=k.barY+k.barHeight/2-c;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=w+v,R=D-v;if(o.moveTo(w,E),R>=M)o.lineTo(M,E),o.lineTo(M,I),o.lineTo(D,I);else{const _=(E+I)/2;o.lineTo(M,E),o.lineTo(M,_),o.lineTo(R,_),o.lineTo(R,I),o.lineTo(D,I)}o.stroke(),o.beginPath(),o.moveTo(D,I),o.lineTo(D-f,I-y),o.lineTo(D-f,I+y),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const la=864e5,ca=.6,Ds=.25,da="#38A169",ua="#E53E3E",ga="#A0AEC0",ha=10,fa=4,ze=16,pa=3;function Lt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ma(e,t){return Math.round((t.getTime()-e.getTime())/la)}function Ta(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:Lt(s.startDate),end:Lt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var b,T;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,d=o.scrollX,h=o.scrollY,p=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const g=u*ca;for(const f of i){if(f.isMilestone)continue;const y=t.get(f.taskId);if(!y)continue;const v=f.barY-h;if(v+u+g<p||v>s.canvas.height)continue;const m=r.dateToX(y.start),S=r.dateToX(y.end),k=Math.max(S-m,2),w=v+u+1;Lt(((b=o.tasks.get(f.taskId))==null?void 0:b.startDate)||"");const E=Lt(((T=o.tasks.get(f.taskId))==null?void 0:T.endDate)||""),D=ma(y.end,E);let I;D<0?I=da:D>0?I=ua:I=ga,s.save(),s.globalAlpha=Ds,s.fillStyle=I;const M=Math.min(c,k/2,g/2);if(s.beginPath(),s.moveTo(m+M,w),s.lineTo(m+k-M,w),s.arcTo(m+k,w,m+k,w+M,M),s.lineTo(m+k,w+g-M),s.arcTo(m+k,w+g,m+k-M,w+g,M),s.lineTo(m+M,w+g),s.arcTo(m,w+g,m,w+g-M,M),s.lineTo(m,w+M),s.arcTo(m,w,m+M,w,M),s.closePath(),s.fill(),s.globalAlpha=Ds*2,s.strokeStyle=I,s.lineWidth=1,s.stroke(),s.restore(),D!==0){const R=D>0?`+${D}d`:`${D}d`;s.save(),s.font=`600 ${ha}px ${a.fontFamily}`;const O=s.measureText(R).width+fa*2,N=f.x+f.width+4,Y=w+(g-ze)/2;s.globalAlpha=.85,s.fillStyle=I;const W=pa;s.beginPath(),s.moveTo(N+W,Y),s.lineTo(N+O-W,Y),s.arcTo(N+O,Y,N+O,Y+W,W),s.lineTo(N+O,Y+ze-W),s.arcTo(N+O,Y+ze,N+O-W,Y+ze,W),s.lineTo(N+W,Y+ze),s.arcTo(N,Y+ze,N,Y+ze-W,W),s.lineTo(N,Y+W),s.arcTo(N,Y,N+W,Y,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(R,N+O/2,Y+ze/2),s.restore()}}s.restore()},destroy(){}}}const Es=5,ya=5,ba=.3,va=15;function wa(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:h,headerHeight:p}=d.config,r=d.scrollY,c=d.flatVisibleIds.length,g=a(d),b=Math.floor(r/h),T=Math.ceil((r+g)/h);let f=Math.max(0,b-Es),y=Math.min(c,T+Es);if(Math.abs(s)>0){const m=Math.min(va,Math.ceil(Math.abs(s*ba)/h));s>0?y=Math.min(c,y+m):f=Math.max(0,f-m)}const v=new Set;for(let m=f;m<y&&m<d.flatVisibleIds.length;m++)v.add(d.flatVisibleIds[m]);return{startRow:f,endRow:y,totalRows:c,visibleTaskIds:v}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function l(d){const h=performance.now();for(o.push({y:d,time:h});o.length>ya;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],c=(r.time-p.time)/1e3;c>0&&(s=(r.y-p.y)/c)}n=d}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(l(d.scrollY),t=i(d)),t},filterLayouts(d){const h=u.getVisibleRange();return h.totalRows===0?[]:d.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(d){return u.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,h){if(h(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const He=864e5,gn=1,ks=2,Cs=.5,Is=2,Rt=8,Ms=6,As=2,Pt=1e4;function hn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Ls(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Qe(e){return Math.round(e)+.5}function Rs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Ps(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const c=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,c,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const c=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let g=0;e.fillStyle=i.gridTextColor;for(const b of a){const T=b.width??120,f=Rs(r,b.field);e.save(),e.beginPath(),e.rect(g,c,T,l),e.clip(),e.textBaseline="middle";const y=b.tree?8:0;e.textAlign=b.align==="right"?"right":b.align==="center"?"center":"left";const v=b.align==="right"?g+T-8:b.align==="center"?g+T/2:g+8+y;e.fillText(f,v,c+l/2),e.restore(),g+=T}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function $s(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,d=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:g,end:b}=t.dateRange,T=new Date(g);T.setUTCHours(0,0,0,0);const f=b.getTime();for(;T.getTime()<=f;){const y=T.getUTCDay();if(y===0||y===6){const v=o+s.dateToX(T),m=new Date(T.getTime()+He),S=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,l,S-v,h)}T.setTime(T.getTime()+He)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Cs;for(const g of r){const b=Qe(o+g);e.moveTo(b,l),e.lineTo(b,p)}e.stroke();for(let g=0;g<t.flatVisibleIds.length;g++)g%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+g*u,d,u));if(i.showToday){const g=new Date;g.setHours(0,0,0,0);const{start:b,end:T}=t.dateRange;if(g.getTime()>=b.getTime()&&g.getTime()<=T.getTime()){const f=o+s.dateToX(g),y=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(f,l,y,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=ks,e.moveTo(Qe(f),l),e.lineTo(Qe(f),p),e.stroke()}}const c=a.barBorderRadius;for(const g of n){const b=o+g.x,T=g.barY,f=g.width,y=g.barHeight;if(g.isMilestone){const v=(y-Is*2)/2,m=T+y/2;e.beginPath(),e.moveTo(b,m-v),e.lineTo(b+v,m),e.lineTo(b,m+v),e.lineTo(b-v,m),e.closePath(),e.fillStyle=g.color,e.fill();continue}if(fn(e,b,T,f,y,c),e.fillStyle=g.color,e.fill(),i.showProgress&&g.progressWidth>0){const v=Ls(g.color,.2);e.save(),e.beginPath(),fn(e,b,T,f,y,c),e.clip(),e.fillStyle=v,e.fillRect(b,T,g.progressWidth,y),e.restore()}if(t.selectedIds.has(g.taskId)&&(e.beginPath(),fn(e,b,T,f,y,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=As,e.stroke()),g.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(g.label).width,m=T+y/2;v+Rt*2<=f?(e.beginPath(),e.rect(b,T,f,y),e.clip(),e.fillStyle=g.textColor,e.textAlign="left",e.fillText(g.label,b+Rt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(g.label,b+f+Ms,m)),e.restore()}}Sa(e,t,n,a,o),Da(e,s,i,a,o)}function Sa(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,l=6,u=4;e.save();for(const d of t.dependencies.values()){const h=i.get(d.source),p=i.get(d.target);if(!h||!p)continue;const r=d.type||"FS",c=h.barY+h.barHeight/2,g=p.barY+p.barHeight/2;let b,T;const f=r==="FS"||r==="FF",y=r==="FS"||r==="SS";switch(r){case"FS":b=o+h.x+h.width,T=o+p.x;break;case"SS":b=o+h.x,T=o+p.x;break;case"FF":b=o+h.x+h.width,T=o+p.x+p.width;break;case"SF":b=o+h.x,T=o+p.x+p.width;break}const v=f?b+a:b-a,m=y?T-a:T+a,S=f?y?m>=v:T+a>=v:y?T-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(b,c),S)e.lineTo(v,c),e.lineTo(v,g),e.lineTo(T,g);else{const k=(c+g)/2;e.lineTo(v,c),e.lineTo(v,k),e.lineTo(m,k),e.lineTo(m,g),e.lineTo(T,g)}e.stroke(),e.beginPath(),y?(e.moveTo(T,g),e.lineTo(T-l,g-u),e.lineTo(T-l,g+u)):(e.moveTo(T,g),e.lineTo(T+l,g-u),e.lineTo(T+l,g+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function Da(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let d=0;d<a.length;d++){const h=a[d],p=d*u;for(const r of h){const c=o+r.x,g=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=gn,e.moveTo(Qe(c+g),p),e.lineTo(Qe(c+g),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(c,p,g,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+g/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=gn,e.moveTo(o,Qe(i)),e.lineTo(o+t.getTotalWidth(),Qe(i)),e.stroke()}function fn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function mt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Ea(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),d=s+u,h=e.flatVisibleIds.length*l,p=a+h,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),c.push(`<style>text { font-family: ${mt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let g=0;for(const m of o.columns){const S=m.width??120;c.push(`<text x="${g+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${mt(m.header)}</text>`),c.push(`<line x1="${g+S}" y1="0" x2="${g+S}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),g+=S}for(let m=0;m<e.flatVisibleIds.length;m++){const S=e.tasks.get(e.flatVisibleIds[m]);if(!S)continue;const k=a+m*l;m%2===1&&c.push(`<rect x="0" y="${k}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let w=0;for(const E of o.columns){const D=E.width??120,I=Rs(S,E.field),M=E.tree?8:0;c.push(`<text x="${w+8+M}" y="${k+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${I}]]></text>`),w+=D}c.push(`<line x1="0" y1="${k+l}" x2="${s}" y2="${k+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const b=n.getHeaderRows(),T=b.length||2,f=a/T;for(let m=0;m<b.length;m++){const S=b[m],k=m*f;for(const w of S){const E=s+w.x+w.width/2,D=k+f/2,I=m===0?' font-weight="600"':"";c.push(`<text x="${E}" y="${D}" text-anchor="middle" dominant-baseline="central"${I} fill="${i.timelineHeaderText}">${mt(w.label)}</text>`),c.push(`<line x1="${s+w.x+w.width}" y1="${k}" x2="${s+w.x+w.width}" y2="${k+f}" stroke="${i.timelineGridColor}" stroke-width="${gn}" />`)}}const y=n.getGridLines();for(const m of y)c.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Cs}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&c.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:S}=e.dateRange,k=new Date(m);for(k.setUTCHours(0,0,0,0);k.getTime()<=S.getTime();){if(k.getUTCDay()===0||k.getUTCDay()===6){const w=s+n.dateToX(k),E=new Date(k.getTime()+He),D=s+n.dateToX(E);c.push(`<rect x="${w}" y="${a}" width="${D-w}" height="${h}" fill="${i.timelineWeekendBg}" />`)}k.setTime(k.getTime()+He)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:S,end:k}=e.dateRange;if(m.getTime()>=S.getTime()&&m.getTime()<=k.getTime()){const w=s+n.dateToX(m),E=n.getColumnWidth();c.push(`<rect x="${w}" y="${a}" width="${E}" height="${h}" fill="${i.todayBg}" />`),c.push(`<line x1="${w}" y1="${a}" x2="${w}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${ks}" />`)}}for(const m of t){const S=s+m.x,k=m.barY,w=m.width,E=m.barHeight;if(m.isMilestone){const D=(E-Is*2)/2,I=k+E/2;c.push(`<polygon points="${S},${I-D} ${S+D},${I} ${S},${I+D} ${S-D},${I}" fill="${m.color}" />`);continue}if(c.push(`<rect x="${S}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const D=Ls(m.color,.2);c.push(`<clipPath id="clip-${m.taskId}"><rect x="${S}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${S}" y="${k}" width="${m.progressWidth}" height="${E}" fill="${D}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&c.push(`<rect x="${S}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${As}" />`),m.label){const D=k+E/2;i.fontSize*.6*m.label.length+Rt*2<=w?c.push(`<text x="${S+Rt}" y="${D}" dominant-baseline="central" fill="${m.textColor}">${mt(m.label)}</text>`):c.push(`<text x="${S+w+Ms}" y="${D}" dominant-baseline="central" fill="${i.gridTextColor}">${mt(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const S=v.get(m.source),k=v.get(m.target);if(!S||!k)continue;const w=m.type||"FS",E=S.barY+S.barHeight/2,D=k.barY+k.barHeight/2;let I,M;const R=w==="FS"||w==="FF",_=w==="FS"||w==="SS";switch(w){case"FS":I=s+S.x+S.width,M=s+k.x;break;case"SS":I=s+S.x,M=s+k.x;break;case"FF":I=s+S.x+S.width,M=s+k.x+k.width;break;case"SF":I=s+S.x,M=s+k.x+k.width;break}const x=12,O=6,N=4,Y=R?I+x:I-x,W=_?M-x:M+x,K=R?_?W>=Y:M+x>=Y:_?M-x<=Y:W<=Y;let q;if(K)q=`M${I},${E} L${Y},${E} L${Y},${D} L${M},${D}`;else{const U=(E+D)/2;q=`M${I},${E} L${Y},${E} L${Y},${U} L${W},${U} L${W},${D} L${M},${D}`}c.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),_?c.push(`<polygon points="${M},${D} ${M-O},${D-N} ${M-O},${D+N}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${M},${D} ${M+O},${D-N} ${M+O},${D+N}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function ka(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:d,end:h}=l.dateRange,p=h.getTime()-d.getTime(),r=u.getColumnWidth(),c=l.zoomLevel;let g;switch(c){case"day":g=Math.round(p/He);break;case"week":g=Math.ceil(p/(He*7));break;case"month":{const T=d.getUTCFullYear(),f=d.getUTCMonth(),y=h.getUTCFullYear(),v=h.getUTCMonth();g=(y-T)*12+(v-f);break}case"quarter":{const T=d.getUTCFullYear(),f=Math.floor(d.getUTCMonth()/3),y=h.getUTCFullYear(),v=Math.floor(h.getUTCMonth()/3);g=(y-T)*4+(v-f);break}}const b=g*r;return{dateToX(T){return(T.getTime()-d.getTime())/p*b},getColumnWidth(){return r},getTotalWidth(){return b},getHeaderRows(){return Ma(c,d,h,r,b)},getGridLines(){return this.getHeaderRows()[1].map(f=>f.x).filter(f=>f>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,c=l.flatVisibleIds.length*l.config.rowHeight,g=l.config.headerHeight+c,b=a??"gantt-export.png";if(r>Pt||g>Pt){o(l,d,u,h,r,g,b);return}const T=document.createElement("canvas");T.width=r,T.height=g;const f=T.getContext("2d");f&&(h>0&&Ps(f,l,h,g),$s(f,l,d,u,h),T.toBlob(y=>{y&&hn(y,b)},"image/png"))}function o(a,l,u,d,h,p,r){const c=Math.min(1,Pt/h,Pt/p),g=Math.ceil(h*c),b=Math.ceil(p*c),T=document.createElement("canvas");T.width=g,T.height=b;const f=T.getContext("2d");f&&(f.scale(c,c),d>0&&Ps(f,a,d,p),$s(f,a,l,u,d),T.toBlob(y=>{y&&hn(y,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=Ea(l,d,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});hn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const _s=["January","February","March","April","May","June","July","August","September","October","November","December"],Ns=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Os(e,t){return new Date(e.getTime()+t*He)}function pn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Ca(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ia(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function Ma(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Ia(l,t,i,o);switch(e){case"day":{const l=[],u=[],d=Math.round(i/He);let h=new Date(t);for(let r=0;r<d;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Os(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=pn(p),c=a(p),g=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${_s[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:c,width:g-c,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],d=Math.ceil(i/(He*7));for(let p=0;p<d;p++){const r=Os(t,p*7);u.push({label:`${Ns[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=pn(h),r=h.getTime()<t.getTime()?t:h,c=p.getTime()>n.getTime()?n:p;l.push({label:`${_s[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),h=p}return[l,u]}case"month":{const l=[],u=[],d=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),c=(p-d)*12+(r-h);let g=new Date(Date.UTC(d,h,1));for(let T=0;T<c;T++)u.push({label:Ns[g.getUTCMonth()],x:T*s,width:s,date:new Date(g)}),g=pn(g);let b=new Date(Date.UTC(d,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,y=T.getTime()>n.getTime()?n:T;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(y)-a(f),date:new Date(f)}),b=T}return[l,u]}case"quarter":{const l=[],u=[],d=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(p-d)*4+(r-h);let g=new Date(Date.UTC(d,h*3,1));for(let T=0;T<c;T++){const f=Math.floor(g.getUTCMonth()/3)+1;u.push({label:`Q${f}`,x:T*s,width:s,date:new Date(g)}),g=Ca(g,3)}let b=new Date(Date.UTC(d,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,y=T.getTime()>n.getTime()?n:T;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(y)-a(f),date:new Date(f)}),b=T}return[l,u]}default:return[[],[]]}}const Aa={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},mn="nimbus-gantt-dark-theme-transition";function La(){if(typeof document>"u"||document.getElementById(mn))return;const e=document.createElement("style");e.id=mn,e.textContent=`
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
  `,document.head.appendChild(e)}function Ra(){if(typeof document>"u")return;const e=document.getElementById(mn);e&&e.remove()}function Pa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const g={...c.config.theme,...Aa};Object.assign(c.config.theme,g),s=!0,p()}function d(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,p()}function h(){s?d():u()}function p(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?u():d()}return{name:"DarkThemePlugin",install(c){n=c,La(),c.on("theme:toggle",()=>{h()}),c.on("theme:dark",()=>{u()}),c.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}Ra(),n=null,o=null,i=null,a=null,s=!1}}}const Ae=864e5,$a=[1,2,3,4,5],_a="rgba(128, 128, 128, 0.06)",Na="rgba(128, 128, 128, 0.04)",Oa="#f87171",Tt=4;function yt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function $e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ha(e){const t=new Set((e==null?void 0:e.workDays)??$a),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=$e(r);return t.has(c.getUTCDay())}function i(r){const c=yt(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=$e(r);for(c=new Date(c.getTime()+Ae);!i(c);)c=new Date(c.getTime()+Ae);return yt(c)}function l(r,c){if(c===0)return r;let g=$e(r);const b=c>0?1:-1;let T=Math.abs(c);if(!i(g))for(g=new Date(g.getTime()+b*Ae);!i(g);)g=new Date(g.getTime()+b*Ae);for(;T>0;)g=new Date(g.getTime()+b*Ae),i(g)&&T--;return yt(g)}function u(r,c){const g=$e(r),b=$e(c);if(g.getTime()>b.getTime())return-u(c,r);let T=0,f=new Date(g.getTime());for(;f.getTime()<b.getTime();)i(f)&&T++,f=new Date(f.getTime()+Ae);return T}function d(r,c="forward"){if(o(r))return r;let g=$e(r);const b=c==="forward"?Ae:-Ae;for(let T=0;T<30;T++)if(g=new Date(g.getTime()+b),i(g))return yt(g);return r}function h(r,c){if(r.type==="TASK_MOVE"){const g=d(r.startDate,"forward"),b=d(r.endDate,"backward"),T=$e(b).getTime()<$e(g).getTime()?g:b;c({...r,startDate:g,endDate:T});return}if(r.type==="TASK_RESIZE"){const g=d(r.startDate,"forward"),b=d(r.endDate,"backward"),T=$e(b).getTime()<$e(g).getTime()?g:b;c({...r,startDate:g,endDate:T});return}c(r)}function p(r,c,g){const{config:b}=c,T=b.headerHeight,f=c.flatVisibleIds.length*b.rowHeight,y=s==null?void 0:s.getTimeScale();if(!y||f===0)return;const{start:v,end:m}=c.dateRange,S=c.scrollX,k=c.scrollY;r.save();const w=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(w,0,0,w,0,0),r.beginPath(),r.rect(0,T,r.canvas.width/w,f),r.clip(),r.translate(-S,0);const E=new Date(v);E.setUTCHours(0,0,0,0);const D=m.getTime();for(y.getColumnWidth();E.getTime()<=D;){const I=yt(E),M=n.has(I),R=!t.has(E.getUTCDay());if(M||R){const _=y.dateToX(E),x=new Date(E.getTime()+Ae),N=y.dateToX(x)-_;if(r.fillStyle=_a,r.fillRect(_,T-k,N,f+k),R&&!M){r.save(),r.beginPath(),r.rect(_,T,N,f),r.clip(),r.strokeStyle=Na,r.lineWidth=1;const Y=8,W=f;for(let K=-W;K<N+W;K+=Y)r.beginPath(),r.moveTo(_+K,T),r.lineTo(_+K+W,T+W),r.stroke();r.restore()}}if(M){const _=y.dateToX(E),x=new Date(E.getTime()+Ae),O=y.dateToX(x),N=(_+O)/2;r.save(),r.setTransform(w,0,0,w,0,0),r.translate(-S,0);const Y=T-Tt-3;r.beginPath(),r.moveTo(N,Y-Tt),r.lineTo(N+Tt,Y),r.lineTo(N,Y+Tt),r.lineTo(N-Tt,Y),r.closePath(),r.fillStyle=Oa,r.fill(),r.restore()}E.setTime(E.getTime()+Ae)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const g=c[0],b=c[1],T=c[2],f=l(g,b);T&&T(f)}),r.on("calendar:workDaysBetween",(...c)=>{const g=c[0],b=c[1],T=c[2],f=u(g,b);T&&T(f)}),r.on("calendar:isWorkDay",(...c)=>{const g=c[0],b=c[1],T=o(g);b&&b(T)}),r.on("calendar:nextWorkDay",(...c)=>{const g=c[0],b=c[1],T=a(g);b&&b(T)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function xa(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Ba(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function Fa(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=xa(),a=[],l=Date.now();let u=null,d=null,h=!1,p=[];const r=[];function c(m,S){if(h)return;const k={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:S};a.push(k),o&&o(k)}function g(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function b(){d===null&&(d=setInterval(()=>{g()},s))}function T(){d!==null&&(clearInterval(d),d=null)}const f=Ba(()=>{if(!u)return;const m=u.getState();c("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let y=0;function v(m,S){switch(m.type){case"SET_ZOOM":{const k=u?u.getState().zoomLevel:"unknown";S(m),c("gantt.zoom",{oldLevel:k,newLevel:m.level});return}case"TASK_MOVE":{const k=y>0?Date.now()-y:0;S(m),c("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:k}),y=0;return}case"TASK_RESIZE":{S(m),c("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{y=Date.now(),S(m);return}case"SELECT_TASK":{S(m),c("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{S(m),f();return}case"TOGGLE_EXPAND":{const k=u?u.getState().expandedIds.has(m.taskId):!1;S(m),c(k?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{S(m),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{S(m),c("gantt.collapse",{all:!0});return}default:S(m);return}}return{name:"TelemetryPlugin",install(m){u=m,b();const S=m.getState();c("gantt.init",{taskCount:S.tasks.size,dependencyCount:S.dependencies.size,zoomLevel:S.zoomLevel}),setTimeout(()=>{h||c("gantt.feature.used",{plugins:p})},0);const k=m.on("taskClick",(...w)=>{const E=w[0];E&&c("gantt.task.click",{taskId:E.id})});r.push(k)},middleware:v,destroy(){h=!0;const m=Date.now()-l;c("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),g(),T();for(const S of r)S();r.length=0,u=null}}}const Hs=5,Tn=.15,yn=.85,Ya=2,xs=30,xe=["day","week","month","quarter"];function Bs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function Ua(e,t,n){return Math.max(t,Math.min(n,e))}function Wa(e){const t=Ua((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,d=0,h=0,p=0,r=null,c=null,g=null,b=null,T=null,f=null,y=0,v=0,m=0,S=!1;function k(O,N,Y){m=O,y=N,v=Y,S=!0,r===null&&(r=O)}function w(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(b=O=>{u||O.alpha==null||O.beta==null||O.gamma==null||k(O.alpha,O.beta,O.gamma)},window.addEventListener("deviceorientation",b),!0)}function E(){b&&(window.removeEventListener("deviceorientation",b),b=null)}function D(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function I(O){try{const N=JSON.parse(O);N.type==="orientation"?k(N.alpha,N.beta,N.gamma):N.type==="gesture"&&M(N.gesture)}catch{}}function M(O){if(!l)return;const N=l.getState();switch(O){case"tap":{N.selectedIds.size===0&&N.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:N.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const Y=xe.indexOf(N.zoomLevel);Y<xe.length-1&&l.dispatch({type:"SET_ZOOM",level:xe[Y+1]});break}case"swipe-right":{const Y=xe.indexOf(N.zoomLevel);Y>0&&l.dispatch({type:"SET_ZOOM",level:xe[Y-1]});break}}}function R(){if(u||typeof WebSocket>"u")return;const O=D();try{T=new WebSocket(O),T.onmessage=N=>{typeof N.data=="string"&&I(N.data)},T.onclose=()=>{T=null,u||(f=setTimeout(R,3e3))},T.onerror=()=>{T&&T.close()}}catch{u||(f=setTimeout(R,3e3))}}function _(){f!==null&&(clearTimeout(f),f=null),T&&(T.onmessage=null,T.onclose=null,T.onerror=null,T.close(),T=null)}function x(){if(!(u||!l)){if(S){d=d*yn+y*Tn,h=h*yn+v*Tn,p=p*yn+m*Tn;const O=l.getState(),N=Ya*a;if(n){const Y=Bs(h,Hs);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const Y=Bs(d,Hs);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=xe.indexOf(O.zoomLevel);if(W>xs&&K>0){const q=xe[K-1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}else if(W<-xs&&K<xe.length-1){const q=xe[K+1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}}}g=requestAnimationFrame(x)}}return{name:"MotionControlPlugin",install(O){l=O,c=O.getState().zoomLevel,(!w()||i)&&R(),g=requestAnimationFrame(x)},destroy(){u=!0,g!==null&&(cancelAnimationFrame(g),g=null),E(),_(),l=null}}}const bt="http://schemas.microsoft.com/project",Xa=8,Fs=4800,za={0:"FF",1:"FS",2:"SF",3:"SS"},Ga={FF:0,FS:1,SF:2,SS:3};function Ys(e){return e?e.substring(0,10):""}function Us(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function De(e,t){var s;let n=e.getElementsByTagNameNS(bt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function Va(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function Ka(e){return`PT${e*Xa}H0M0S`}function vt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function bn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(bt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let f=0;f<l.length;f++){const y=l[f],v=De(y,"UID"),m=De(y,"Name");v&&m&&i.set(v,m)}const u=new Map,d=o.getElementsByTagNameNS(bt,"Assignment"),h=d.length>0?d:o.getElementsByTagName("Assignment");for(let f=0;f<h.length;f++){const y=h[f],v=De(y,"TaskUID"),m=De(y,"ResourceUID");if(v&&m){const S=i.get(m);S&&u.set(v,S)}}const p=[],r=[],c=o.getElementsByTagNameNS(bt,"Task"),g=c.length>0?c:o.getElementsByTagName("Task"),b=[];let T=1;for(let f=0;f<g.length;f++){const y=g[f],v=De(y,"UID"),m=De(y,"Name"),S=De(y,"Start"),k=De(y,"Finish"),w=De(y,"PercentComplete"),E=De(y,"Summary")==="1",D=De(y,"Milestone")==="1",I=parseInt(De(y,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const M=`msp-${v}`,R=Ys(S),_=Ys(k);if(!R&&!D)continue;let x;I>0&&b[I-1]&&(x=b[I-1]),b[I]=M,b.length=I+1;const O={id:M,name:m||`Task ${v}`,startDate:R||_,endDate:_||R,progress:w?parseInt(w,10)/100:0,isMilestone:D,parentId:x,sortOrder:f},N=u.get(v);N&&(O.assignee=N),E&&(O.metadata={...O.metadata,isSummary:!0}),p.push(O);const Y=y.getElementsByTagNameNS(bt,"PredecessorLink"),W=Y.length>0?Y:y.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],U=De(q,"PredecessorUID"),C=parseInt(De(q,"Type")||"1",10),P=De(q,"LinkLag"),A=P?parseInt(P,10):0;if(!U||U==="0")continue;const $={id:`msp-dep-${T++}`,source:`msp-${U}`,target:M,type:za[C]??"FS",lag:A!==0?A/Fs:void 0};r.push($)}}return{tasks:p,dependencies:r}}function vn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(v){let m=1,S=v;for(;S!=null&&S.parentId;)m++,S=e.tasks.get(S.parentId);return m}const d=new Map,h=new Map;for(const v of a){const m=v.parentId??"__root__",S=(d.get(m)??0)+1;if(d.set(m,S),!v.parentId)h.set(v.id,String(S));else{const k=h.get(v.parentId)??"0";h.set(v.id,`${k}.${S}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const c=new Map;for(const v of l){const m=c.get(v.target)??[];m.push(v),c.set(v.target,m)}const g=new Set;for(const v of a)v.assignee&&g.add(v.assignee);const b=Array.from(g),T=new Map;b.forEach((v,m)=>{T.set(v,m+1)});const f=[];f.push('<?xml version="1.0" encoding="UTF-8"?>'),f.push('<Project xmlns="http://schemas.microsoft.com/project">'),f.push(`  <Name>${vt(n)}</Name>`),f.push(`  <Author>${vt(s)}</Author>`),f.push(`  <CreationDate>${o}</CreationDate>`),f.push("  <CalendarUID>1</CalendarUID>"),f.push("  <Calendars>"),f.push("    <Calendar>"),f.push("      <UID>1</UID>"),f.push(`      <Name>${vt(i)}</Name>`),f.push("      <IsBaseCalendar>1</IsBaseCalendar>"),f.push("    </Calendar>"),f.push("  </Calendars>"),f.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,S=u(v),k=h.get(v.id)??"1",w=p.has(v.id),E=v.isMilestone??!1,D=Us(v.startDate),I=Us(v.endDate),M=Va(D,I),R=Ka(M),_=Math.round((v.progress??0)*100);f.push("    <Task>"),f.push(`      <UID>${m}</UID>`),f.push(`      <ID>${m}</ID>`),f.push(`      <Name>${vt(v.name)}</Name>`),f.push(`      <Start>${v.startDate}T08:00:00</Start>`),f.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),f.push(`      <Duration>${R}</Duration>`),f.push(`      <PercentComplete>${_}</PercentComplete>`),f.push(`      <Summary>${w?"1":"0"}</Summary>`),f.push(`      <Milestone>${E?"1":"0"}</Milestone>`),f.push(`      <OutlineLevel>${S}</OutlineLevel>`),f.push(`      <OutlineNumber>${k}</OutlineNumber>`);const x=c.get(v.id);if(x)for(const O of x){const N=r.get(O.source)??0;if(N===0)continue;const Y=Ga[O.type??"FS"]??1,W=Math.round((O.lag??0)*Fs);f.push("      <PredecessorLink>"),f.push(`        <PredecessorUID>${N}</PredecessorUID>`),f.push(`        <Type>${Y}</Type>`),f.push(`        <LinkLag>${W}</LinkLag>`),f.push("      </PredecessorLink>")}f.push("    </Task>")}f.push("  </Tasks>"),f.push("  <Resources>");for(const v of b){const m=T.get(v)??0;f.push("    <Resource>"),f.push(`      <UID>${m}</UID>`),f.push(`      <Name>${vt(v)}</Name>`),f.push("    </Resource>")}f.push("  </Resources>"),f.push("  <Assignments>");let y=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,S=T.get(v.assignee)??0;m===0||S===0||(f.push("    <Assignment>"),f.push(`      <UID>${y++}</UID>`),f.push(`      <TaskUID>${m}</TaskUID>`),f.push(`      <ResourceUID>${S}</ResourceUID>`),f.push("    </Assignment>"))}return f.push("  </Assignments>"),f.push("</Project>"),f.join(`
`)}function ja(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var d;const u=(d=l.target)==null?void 0:d.result;if(!(!u||!e))try{const h=bn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=bn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),d=vn(u,a);l&&l(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),d=vn(u,a),h=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const qa=[4,3],Za=1.5,Ja=.5,Qa=.06,er=4,tr=8,nr=.35,sr=1,Ws=.2,wt=6,Xs=864e5;function _e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function zs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function wn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Sn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function or(e){let t=0;for(const n of e){const s=_e(n.startDate).getTime(),o=_e(n.endDate).getTime();t+=Math.max(o-s,Xs)}return t}function ir(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=_e(l.startDate).getTime(),h=_e(s.startDate).getTime()-u,p=i.segments.map(r=>{const c=new Date(_e(r.startDate).getTime()+h),g=new Date(_e(r.endDate).getTime()+h);return{startDate:zs(c),endDate:zs(g)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,d=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:d,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),c=d.barBorderRadius,g=h;s.save(),s.beginPath(),s.rect(0,g,s.canvas.width,s.canvas.height-g),s.clip(),s.translate(-l,0);for(const b of i){if(b.isMilestone)continue;const T=t.get(b.taskId);if(!T||T.segments.length===0)continue;const f=b.barY-u,y=b.barHeight,v=f+y/2;if(f+y<g||f>s.canvas.height)continue;const m=[];for(const I of T.segments){const M=r.dateToX(_e(I.startDate)),R=r.dateToX(_e(I.endDate)),_=Math.max(R-M,4);m.push({startX:M,endX:M+_,width:_})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(b.x-1,f-1,b.width+2,y+2),s.restore();for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX,_=R-M;if(!(_<=0)){s.save(),s.globalAlpha=Qa,s.strokeStyle=b.color,s.lineWidth=er,s.beginPath(),s.rect(M,f,_,y),s.clip();for(let x=M-y;x<R+y;x+=tr)s.beginPath(),s.moveTo(x,f+y),s.lineTo(x+y,f),s.stroke();s.restore()}}for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX;s.save(),s.globalAlpha=Ja,s.strokeStyle=wn(b.color,Ws),s.lineWidth=Za,s.setLineDash(qa),s.beginPath(),s.moveTo(M,v),s.lineTo(R,v),s.stroke(),s.setLineDash([]),s.restore()}const S=o.tasks.get(b.taskId),k=(S==null?void 0:S.progress)??0,w=or(T.segments);let D=k*w;for(let I=0;I<m.length;I++){const M=m[I],R=Math.max(_e(T.segments[I].endDate).getTime()-_e(T.segments[I].startDate).getTime(),Xs);if(s.save(),Sn(s,M.startX,f,M.width,y,c),s.fillStyle=b.color,s.fill(),s.strokeStyle=wn(b.color,Ws),s.lineWidth=sr,s.stroke(),s.restore(),D>0&&a.showProgress){const _=Math.min(D,R),x=_/R,O=M.width*x;s.save(),Sn(s,M.startX,f,M.width,y,c),s.clip(),s.globalAlpha=nr,s.fillStyle=wn(b.color,.3),s.fillRect(M.startX,f,O,y),s.restore(),D-=_}}if(b.label){const I=m[0],M=m[m.length-1],R=M.endX-I.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const x=s.measureText(b.label).width;s.textBaseline="middle",s.textAlign="left",x+wt*2<=I.width?(s.fillStyle=b.textColor,Sn(s,I.startX,f,I.width,y,c),s.clip(),s.fillText(b.label,I.startX+wt,v)):x+wt<=R?(s.fillStyle=b.textColor,s.fillText(b.label,I.startX+wt,v)):(s.fillStyle=d.gridTextColor,s.fillText(b.label,M.endX+wt,v)),s.restore()}}s.restore()},destroy(){n=null}}}const Dn=864e5,Gs=1e3,$t=4,ar=.6,rr="#E53E3E",lr="#48BB78",cr="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function lt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function _t(e,t){return Math.round((t.getTime()-e.getTime())/Dn)}function Vs(e,t){return new Date(e.getTime()+t*Dn)}function Ge(e,t){return lt(Vs(he(e),t))}function Be(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(lt(n)),o;for(;i.getTime()<s.getTime();)o.push(lt(i)),i.setTime(i.getTime()+Dn);return o}class En{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(l=a.get(d))==null||l.delete(n),((u=a.get(d))==null?void 0:u.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const d of s){let h=(a==null?void 0:a.get(d))??0;if((u=l==null?void 0:l.get(d))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Nt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function dr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const d=parseInt(l,10);isNaN(d)||(u=d)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Ks(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function ur(e,t,n,s,o){const i=new Map;for(const f of s)e.has(f.taskId)&&n.has(f.resourceId)&&(i.has(f.taskId)||i.set(f.taskId,[]),i.get(f.taskId).push({resourceId:f.resourceId,units:f.units||1}));const a=new Map,l=new Map;for(const f of e.keys())a.set(f,[]),l.set(f,[]);for(const f of t.values()){if((f.type||"FS")!=="FS"||!e.has(f.source)||!e.has(f.target))continue;const v=f.lag||0;a.get(f.source).push({target:f.target,lag:v}),l.get(f.target).push({source:f.source,lag:v})}const u=new Map;for(const[f,y]of e){const v=he(y.startDate),m=he(y.endDate);u.set(f,{taskId:f,startDate:y.startDate,endDate:y.endDate,duration:Math.max(_t(v,m),0)})}const d=new En;function h(){d.clear();for(const[f,y]of u){const v=i.get(f);if(!v)continue;const m=Be(y.startDate,y.endDate);for(const S of v)d.allocate(S.resourceId,f,m,S.units)}}function p(f,y){const v=u.get(f);if(!v)return new Set;const m=new Set,S=v.startDate;if(y===S||he(y).getTime()<he(S).getTime())return m;const k=i.get(f);if(k){const w=Be(v.startDate,v.endDate);for(const E of k)d.deallocate(E.resourceId,f,w,E.units)}if(v.startDate=y,v.endDate=Ge(y,v.duration),m.add(f),k){const w=Be(v.startDate,v.endDate);for(const E of k)d.allocate(E.resourceId,f,w,E.units)}return m}function r(f){const y=new Set,v=u.get(f);if(!v)return y;const m=a.get(f)??[];for(const{target:S,lag:k}of m){const w=u.get(S);if(!w)continue;const E=Ge(v.endDate,k);if(he(w.startDate).getTime()<he(E).getTime()){const D=p(S,E);for(const I of D){y.add(I);const M=r(I);for(const R of M)y.add(R)}}}return y}function c(f){const y=l.get(f)??[];let v=u.get(f).startDate;v=e.get(f).startDate;for(const{source:S,lag:k}of y){const w=u.get(S);if(!w)continue;const E=Ge(w.endDate,k);he(E).getTime()>he(v).getTime()&&(v=E)}return v}h();for(let f=0;f<Gs;f++){const y=Nt(d,n);if(y.length===0)break;let v=!1;const m=y[0],S=m.taskIds.map(k=>o.get(k)).filter(k=>k!==void 0).sort(Ks);if(!(S.length<2))for(let k=1;k<S.length;k++){const w=S[k],E=u.get(w.taskId);if(!E)continue;const D=u.get(S[0].taskId);if(!D)continue;const I=D.endDate,M=c(w.taskId),R=he(I).getTime()>he(M).getTime()?I:M;he(R).getTime()>he(E.startDate).getTime()&&(p(w.taskId,R),r(w.taskId),v=!0);const _=d.getLoad(m.resourceId,m.date),x=n.get(m.resourceId).maxUnits;if(_<=x)break}}const g=new Map;let b=0;for(const[f,y]of u){const v=e.get(f),m=_t(he(v.startDate),he(y.startDate));m!==0&&(g.set(f,{startDate:y.startDate,endDate:y.endDate,delayDays:m}),b+=m)}const T=Nt(d,n);return{adjustedTasks:g,totalDelay:b,conflicts:T,resolved:T.length===0}}function gr(e,t,n,s,o){const i=new Map;for(const y of s)e.has(y.taskId)&&n.has(y.resourceId)&&(i.has(y.taskId)||i.set(y.taskId,[]),i.get(y.taskId).push({resourceId:y.resourceId,units:y.units||1}));const a=new Map;for(const y of e.keys())a.set(y,[]);for(const y of t.values())(y.type||"FS")==="FS"&&(!e.has(y.source)||!e.has(y.target)||a.get(y.target).push({source:y.source,lag:y.lag||0}));const l=Array.from(e.keys()).map(y=>o.get(y)).filter(y=>y!==void 0).sort(Ks),u=new Map,d=new En,h=new Set,p=new Map;for(const[y,v]of e)p.set(y,Math.max(_t(he(v.startDate),he(v.endDate)),0));function r(y){let m=e.get(y).startDate;const S=a.get(y)??[];for(const{source:k,lag:w}of S){const E=u.get(k);if(!E)continue;const D=Ge(E.endDate,w);he(D).getTime()>he(m).getTime()&&(m=D)}return m}function c(y,v,m){const S=i.get(y);if(!S||S.length===0)return v;let k=v;const w=365*5;for(let E=0;E<w;E++){const D=Ge(k,m),I=Be(k,D);let M=!0;for(const R of S){const _=n.get(R.resourceId);if(!_||_.maxUnits===0)continue;const x=_.calendar?new Set(_.calendar):null;if(x&&I.some(N=>x.has(N))){M=!1;break}if(!d.canFit(R.resourceId,y,I,R.units,_.maxUnits)){M=!1;break}}if(M)return k;k=Ge(k,1)}return v}const g=new Set(l.map(y=>y.taskId));for(let y=0;y<Gs&&g.size>0;y++){let v=!1;for(const m of l){if(!g.has(m.taskId)||!(a.get(m.taskId)??[]).every(_=>h.has(_.source)))continue;const w=m.taskId,E=p.get(w)??0,D=r(w),I=c(w,D,E),M=Ge(I,E);u.set(w,{taskId:w,startDate:I,endDate:M,duration:E});const R=i.get(w);if(R){const _=Be(I,M);for(const x of R)d.allocate(x.resourceId,w,_,x.units)}h.add(w),g.delete(w),v=!0}if(!v){for(const m of g){const S=e.get(m),k=p.get(m)??0;u.set(m,{taskId:m,startDate:S.startDate,endDate:S.endDate,duration:k});const w=i.get(m);if(w){const E=Be(S.startDate,S.endDate);for(const D of w)d.allocate(D.resourceId,m,E,D.units)}h.add(m)}g.clear()}}const b=new Map;let T=0;for(const[y,v]of u){const m=e.get(y),S=_t(he(m.startDate),he(v.startDate));S!==0&&(b.set(y,{startDate:v.startDate,endDate:v.endDate,delayDays:S}),T+=S)}const f=Nt(d,n);return{adjustedTasks:b,totalDelay:T,conflicts:f,resolved:f.length===0}}function hr(e,t,n,s){const o=[],i=Be(n,Ge(s,1)),a=i.length;for(const[l,u]of t){const d=new Map;let h=0,p=0;for(const g of i){const b=e.getLoad(l,g);d.set(g,b),h+=b,b>p&&(p=b)}const r=u.maxUnits===0?1:u.maxUnits,c=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:d,overallUtilization:Math.min(c,1),peakUtilization:p})}return o}function js(e,t,n,s){const o=new En,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const d=s.get(a),h=(d==null?void 0:d.startDate)??l.startDate,p=(d==null?void 0:d.endDate)??l.endDate,r=Be(h,p);for(const c of u)o.allocate(c.resourceId,a,r,c.units)}return o}function fr(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:g}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const b=u(),T=dr(c,b,n);s==="parallel"?i=gr(c,g,t,e.assignments,T):i=ur(c,g,t,e.assignments,T);const f=h(c,i.adjustedTasks),y=js(c,t,e.assignments,i.adjustedTasks);return a=hr(y,t,f.start,f.end),i}function h(r,c){let g=1/0,b=-1/0;for(const[T,f]of r){const y=c.get(T),v=he((y==null?void 0:y.startDate)??f.startDate).getTime(),m=he((y==null?void 0:y.endDate)??f.endDate).getTime();v<g&&(g=v),m>b&&(b=m)}if(g===1/0){const T=lt(new Date);return{start:T,end:T}}return{start:lt(new Date(g)),end:lt(new Date(b))}}function p(r){const c=[];for(const g of e.assignments)g.taskId===r&&c.push(g.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),l.push(r.on("resourceLeveling:run",(...c)=>{const g=c[0],b=d();g&&g(b)})),l.push(r.on("resourceLeveling:result",(...c)=>{const g=c[0];g&&g(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const g=c[0];g&&g(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const g=c[0];if(!g)return;const b=r.getState(),T=js(b.tasks,t,e.assignments,new Map);g(Nt(T,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,c,g){if(!i||a.length===0)return;const{config:b}=c,{headerHeight:T,rowHeight:f}=b,y=c.scrollX,v=c.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,T,r.canvas.width,r.canvas.height-T),r.clip(),r.translate(-y,0);const S=new Map;for(const k of a)S.set(k.resourceId,k);for(const k of g){const w=p(k.taskId);if(w.length===0)continue;const E=S.get(w[0]);if(!E)continue;const D=t.get(w[0]);if(!D)continue;const I=D.maxUnits===0?1:D.maxUnits,R=k.barY+k.barHeight-v+1;if(R+$t<T||R>r.canvas.height)continue;const _=c.tasks.get(k.taskId);if(!_)continue;const x=i.adjustedTasks.get(k.taskId),O=(x==null?void 0:x.startDate)??_.startDate,N=(x==null?void 0:x.endDate)??_.endDate,Y=m.dateToX(he(O)),K=m.dateToX(he(N))-Y;if(K<2)continue;r.fillStyle=cr,r.fillRect(Y,R,K,$t);const q=Be(O,N);for(const U of q){const C=E.dailyLoad.get(U)??0;if(C===0)continue;const P=m.dateToX(he(U)),$=m.dateToX(Vs(he(U),1))-P,Q=Math.min(C/I,2)/2*$t,Z=C>I;r.globalAlpha=ar,r.fillStyle=Z?rr:lr,r.fillRect(P,R+$t-Q,$,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const pr=864e5,mr=75,Tr=50,qs=25,Ot=.3,Ht=.25,Zs=.2,kn=.15,xt=.1,yr=.3,Js=.5,br=20,Qs=40,vr=3,wr=5,Sr=30,eo=.25,to=4,Dr=2,Er=5,Cn=5,no=4,so=.4,kr=.003,Ve=260,ct=260,oo=16,Fe=14,Cr="rgba(30, 30, 46, 0.92)",In="#e0e0e0",Ir=10,Bt=32,Mr=6,Ft="#EF4444",Yt="#F97316",Ut="#EAB308",Wt="#22C55E";function ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ke(e,t){return Math.round((t.getTime()-e.getTime())/pr)}function Ee(e,t,n){return Math.max(t,Math.min(n,e))}function Ar(e){return e>=mr?"critical":e>=Tr?"high":e>=qs?"medium":"low"}function Lr(e){switch(e){case"critical":return Ft;case"high":return Yt;case"medium":return Ut;case"low":return Wt}}function Xt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Rr(e,t){const n=new Map,s=new Map;for(const f of e.keys())n.set(f,[]),s.set(f,[]);for(const f of t.values())!e.has(f.source)||!e.has(f.target)||(n.get(f.source).push(f.target),s.get(f.target).push(f.source));const o=new Map,i=new Set;function a(f){if(o.has(f))return o.get(f);if(i.has(f))return 0;i.add(f);let y=0;for(const v of n.get(f)||[])y+=1+a(v);return o.set(f,y),y}for(const f of e.keys())a(f);const l=new Map;for(const[f,y]of e){const v=ve(y.startDate),m=ve(y.endDate);l.set(f,Math.max(ke(v,m),0))}const u=new Map,d=new Map,h=new Map;for(const f of e.keys())h.set(f,(s.get(f)||[]).length),u.set(f,l.get(f)||0),d.set(f,null);const p=[],r=new Map(h);for(const[f,y]of r)y===0&&p.push(f);for(;p.length>0;){const f=p.shift();for(const y of n.get(f)||[]){const v=u.get(f)+(l.get(y)||0);v>u.get(y)&&(u.set(y,v),d.set(y,f));const m=r.get(y)-1;r.set(y,m),m===0&&p.push(y)}}const c=new Set;let g=0,b=null;for(const[f,y]of u)y>g&&(g=y,b=f);let T=b;for(;T!==null;)c.add(T),T=d.get(T)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function Pr(e){const t=Xt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ve(o.startDate),a=ve(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function $r(e,t,n){const s=[],o=Xt(),i=ve(e.startDate),a=ve(e.endDate),l=Math.max(ke(i,a),1),u=Math.max(ke(i,o),0),d=Math.max(ke(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const E=ke(a,o);p=Ee(80+E*2,80,100),s.push({type:"time-pressure",description:`Task is ${E} day${E===1?"":"s"} past its end date`,impact:Math.round(p*Ot)})}else{const E=d/l;E<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(E*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*Ot)})):(p=Ee(Math.round((1-E)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(E*100)}% of scheduled time remaining`,impact:Math.round(p*Ot)}))}let c=0;const g=Ee(u/l,0,1),b=g-h;b>Js?(c=Ee(Math.round(b*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Ht)})):b>yr?(c=Ee(Math.round(b*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Ht)})):b>.1&&(c=Ee(Math.round(b*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(g*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(c*Ht)}));let T=0;const f=t.downstreamCount.get(e.id)||0,y=t.criticalPathIds.has(e.id);if(f>0){T=Ee(Math.round(Math.log2(f+1)*20),0,70),y&&(T=Ee(Math.round(T*1.5),0,100));const E=y?" (on critical path)":"";s.push({type:"dependency-chain",description:`${f} downstream dependent${f===1?"":"s"}${E}`,impact:Math.round(T*Zs)})}let v=0;l>Qs?(v=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(v*kn)})):l>br&&(v=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(v*kn)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*xt)});else{const E=n.activeTasks.get(e.assignee)||[];E.length>wr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*xt)})):E.length>vr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*xt)}))}const S=Ee(Math.round(p*Ot+c*Ht+T*Zs+v*kn+m*xt),0,100),k=Ar(S);let w;return r&&h===0?w="Task is overdue with no progress — escalate immediately":r?w="Task is past its deadline — review scope or extend timeline":b>Js?w="Task is significantly behind schedule — investigate blockers":l>Qs&&h<eo?w="Large task with little progress — consider splitting into smaller work items":(k==="high"||k==="critical")&&(w="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:k,riskScore:S,factors:s,suggestion:w}}function _r(e,t,n,s,o){const i=Xt();let a=0,l=0,u=0;for(const[y,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;l++;const m=ve(v.startDate),S=ve(v.endDate),k=Math.max(ke(m,S),1),w=Math.max(ke(m,i),0),E=Ee(w/k,0,1);(v.progress??0)>=E-.1&&a++;const I=t.get(y);I&&(I.riskLevel==="high"||I.riskLevel==="critical")&&u++}const d=l>0?a/l:1;let h=0;for(const y of n.criticalPathIds){const v=e.get(y);if(!v||v.isCompleted)continue;const m=ve(v.endDate);i.getTime()>m.getTime()&&(h+=ke(m,i))}const p=[],r=[];for(const[y,v]of s.activeTasks)p.push(v.length),v.length>to&&r.push(y);let c=100;if(p.length>1){const y=p.reduce((v,m)=>v+m,0)/p.length;if(y>0){const v=p.reduce((S,k)=>S+(k-y)**2,0)/p.length,m=Math.sqrt(v)/y;c=Ee(Math.round(100-m*50),0,100)}}let g=100;if(l>0){let y=0,v=0,m=0;for(const S of e.values()){if(S.isCompleted)continue;const k=ve(S.startDate),w=ve(S.endDate),E=Math.max(ke(k,w),1),D=Math.max(ke(k,i),0),I=Ee(D/E,0,2);y+=S.progress??0,v+=I,m++}if(m>0){const S=y/m,k=v/m;if(k>0){const w=S/k;g=Ee(Math.round(w*100),0,100)}}}const b=d*100,T=Ee(100-h*10,0,100);return{overallScore:Ee(Math.round(b*.25+T*.25+c*.25+g*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function Nr(e,t,n,s){const o=[],i=Xt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.endDate),g=ke(c,i),b=r.progress??0;g>Er&&b===0&&o.push({type:"escalate",description:`"${r.name}" is ${g} days overdue with zero progress — flag for management`,impact:`Prevents further ${g}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.startDate),g=ve(r.endDate),b=ke(c,g),T=r.progress??0;if(b>Sr&&T<eo){const f=Math.ceil(b/15);o.push({type:"split",description:`"${r.name}" spans ${b} days — split into ${f} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>to?l.push({assignee:p,taskIds:r}):r.length<Dr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const c=r.filter(g=>!t.criticalPathIds.has(g));c.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const c=ve(r.endDate),g=ke(i,c);if(g>=0&&g<=5){const b=s.get(p);b&&b.riskScore>=qs&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${g} day${g===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${g}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ve(p.startDate).getTime()-ve(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const c of r)h.add(`${c}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const c=d[p],g=d[r],b=ve(c.endDate),T=ve(g.startDate);if(b.getTime()<=T.getTime()&&!(h.has(`${c.id}->${g.id}`)||h.has(`${g.id}->${c.id}`))){const y=ke(b,T);y>0&&o.push({type:"parallel",description:`"${c.name}" and "${g.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${y} days on the critical path`,taskIds:[c.id,g.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function Or(e,t,n,s,o,i,a){if(e.save(),i){const l=so+(1-so)*(.5+.5*Math.sin(a*kr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function Hr(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,d=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Wt:i>=50?Ut:i>=25?Yt:Ft;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=In,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function xr(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Ft,label:"Critical"},{count:o.high,color:Yt,label:"High"},{count:o.medium,color:Ut,label:"Medium"},{count:o.low,color:Wt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const d=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+d),e.closePath(),e.fillStyle=u.color,e.fill(),l+=d}}function Br(e,t,n,s,o){const i=t-Ve-oo,a=n+oo;e.save(),e.beginPath();const l=Ir;e.moveTo(i+l,a),e.lineTo(i+Ve-l,a),e.arcTo(i+Ve,a,i+Ve,a+l,l),e.lineTo(i+Ve,a+ct-l),e.arcTo(i+Ve,a+ct,i+Ve-l,a+ct,l),e.lineTo(i+l,a+ct),e.arcTo(i,a+ct,i,a+ct-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Cr,e.fill(),e.fillStyle=In,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Fe,a+Fe);const u=i+Fe+Bt+4,d=a+Fe+20+Bt+8;Hr(e,u,d,Bt,Mr,s.overallScore);const h=24,p=i+Ve-Fe-h-4,r=d;xr(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const c=r+h+8,g=[{count:o.critical,color:Ft,label:"C"},{count:o.high,color:Yt,label:"H"},{count:o.medium,color:Ut,label:"M"},{count:o.low,color:Wt,label:"L"}],b=28,T=p-g.length*b/2+b/2;for(let m=0;m<g.length;m++){const S=g[m],k=T+m*b;e.fillStyle=S.color,e.fillText(`${S.label}:${S.count}`,k,c)}const f=d+Bt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Fe,f);const y=f+18;e.font="10px sans-serif",e.fillStyle=In,e.fillText("Recommendations:",i+Fe,y);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const S=v[m],k=y+14+m*16,w=S.type==="escalate"?"⚠":S.type==="split"?"✂":S.type==="reassign"?"⇄":S.type==="parallel"?"⇉":S.type==="add-buffer"?"⏱":"ℹ",E=34,D=S.description.length>E?S.description.substring(0,E-1)+"…":S.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${w} ${D}`,i+Fe,k)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Fe,y+14)),e.restore()}function Fr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:d,dependencies:h}=u;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=Rr(d,h),r=Pr(d),c=new Map;for(const[g,b]of d)c.set(g,$r(b,p,r));n=c,o=Nr(d,p,r,n),s=_r(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,d){d(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,d,h){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,c=d.scrollY,g=p,b=Date.now()-a;u.save(),u.beginPath(),u.rect(0,g,u.canvas.width,u.canvas.height-g),u.clip(),u.translate(-r,0);for(const T of h){const f=n.get(T.taskId);if(!f||f.riskLevel==="low")continue;const y=T.x,v=T.barY-c,m=T.width,S=T.barHeight;if(v+S<g||v>u.canvas.height||y+m<0)continue;const k=y+m-Cn-no,w=v+Cn+no,E=Lr(f.riskLevel),D=f.riskLevel==="critical";Or(u,k,w,Cn,E,D,b)}if(u.restore(),i){const T={critical:0,high:0,medium:0,low:0};for(const f of n.values())T[f.riskLevel]++;u.save(),Br(u,u.canvas.width,p,s,T),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Le=160,Ke=80,Mn=8,Yr=240,Ur=160,Wr=100,Xr=200,zt=8,io=.1,ao=3,zr=.001,Gr=500,Vr=5,Kr=864e5,jr={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function ro(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function qr(e,t){return Math.round((t.getTime()-e.getTime())/Kr)}function lo(e,t,n){return e+(t-e)*n}function Gt(e,t,n){return Math.max(t,Math.min(n,e))}function An(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function Zr(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const d of s.get(l)){const h=n.get(d),p=u+1;(h===void 0||p>h)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function Jr(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Qr(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<Vr;a++){for(let l=1;l<e.length;l++){const u=e[l],d=new Map;for(const h of u){const p=o.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let l=e.length-2;l>=0;l--){const u=e[l],d=new Map;for(const h of u){const p=s.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function el(e,t){const n=new Map;if(t==="radial")return tl(e);const s=t==="lr",o=s?Yr:Ur,i=s?Wr:Xr;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],c=h+p*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function tl(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function St(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function nl(e,t){return e.color?e.color:e.status&&(t[e.status]||jr[e.status])||"#94A3B8"}function sl(e){const t=ro(e.startDate),n=ro(e.endDate);return Math.max(qr(t,n),0)}function ol(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,d=new Map,h=[],p=null,r=0,c=0,g=1,b=!1,T=0,f=0,y=0,v=0,m=null,S=0,k=0,w=null,E=null,D=new Set,I=!1,M=0,R=0,_=0,x=0;function O(X,L){return{x:(X-r)/g,y:(L-c)/g}}function N(X,L){const{x:H,y:z}=O(X,L);for(const G of d.values()){const V=G.x,te=G.y;if(H>=V&&H<=V+Le&&z>=te&&z<=te+Ke)return G}return null}function Y(){const X=e.getState(),{tasks:L,dependencies:H,config:z}=X;if(L.size===0){d=new Map,h=[];return}p=un(L,H);const G=Zr(L,H),V=Jr(G);Qr(V,H,L);const te=el(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:Se}of te.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Le),le=Math.min(le,Se),pe=Math.max(pe,Se+Ke);const be=(oe+ae)/2,Ce=(le+pe)/2,Ie=d;d=new Map;for(const[ue,Se]of L){const Me=te.get(ue);if(!Me)continue;const We=Me.x-be,Je=Me.y-Ce,Ne=Ie.get(ue);d.set(ue,{id:ue,task:Se,layer:G.get(ue)??0,orderInLayer:0,x:Ne?Ne.x:We,y:Ne?Ne.y:Je,targetX:We,targetY:Je,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let Se=0;Se<ue.length;Se++){const Me=d.get(ue[Se]);Me&&(Me.orderInLayer=Se)}h=[];for(const ue of H.values())!L.has(ue.source)||!L.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const L=e.getState(),H=new Set;H.add(X);const z=new Map,G=new Map;for(const oe of L.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of L.dependencies.values())!L.tasks.has(oe.source)||!L.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])H.has(ae)||(H.add(ae),V.push(ae))}const te=[X];for(;te.length>0;){const oe=te.shift();for(const ae of z.get(oe)||[])H.has(ae)||(H.add(ae),te.push(ae))}return H}function K(){I&&cancelAnimationFrame(R),I=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,L=Gt(X/Gr,0,1),H=1-Math.pow(1-L,3);let z=!1;for(const G of d.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),te=Math.abs(G.y-G.targetY);V>.5||te>.5?(G.x=lo(G.x,G.targetX,H),G.y=lo(G.y,G.targetY,H),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(U(),z&&L<1)R=requestAnimationFrame(q);else{I=!1;for(const G of d.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);U()}}function U(){if(!i||!o)return;const X=e.getState(),{config:L}=X,H=L.theme,z=L.colorMap,G=H.timelineBg==="#1A202C"||H.gridBg==="#1A202C"||H.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(H.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,_,x),i.save(),i.translate(r,c),i.scale(g,g);for(const V of h){const te=d.get(V.sourceId),oe=d.get(V.targetId);if(!te||!oe)continue;const ae=D.has(V.sourceId)&&D.has(V.targetId),le=w===V.sourceId||w===V.targetId,pe=w!==null&&!le||E!==null&&!ae,be=te.x+Le,Ce=te.y+Ke/2,Ie=oe.x,ue=oe.y+Ke/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=H.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const Se=(be+Ie)/2;i.beginPath(),i.moveTo(be,Ce),i.quadraticCurveTo(Se,Ce,(be+Ie)/2,(Ce+ue)/2),i.quadraticCurveTo(Se,ue,Ie,ue),i.stroke();const Me=Math.atan2(ue-(Ce+ue)/2,Ie-Se);i.beginPath(),i.moveTo(Ie,ue),i.lineTo(Ie-zt*Math.cos(Me-Math.PI/6),ue-zt*Math.sin(Me-Math.PI/6)),i.lineTo(Ie-zt*Math.cos(Me+Math.PI/6),ue-zt*Math.sin(Me+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const We=V.dep.type||"FS",Je=V.dep.lag||0,Ne=Je!==0?`${We} +${Je}d`:We!=="FS"?We:"";if(Ne&&!pe){const kt=(be+Ie)/2,Gn=(Ce+ue)/2-8;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ne,kt,Gn)}i.restore()}for(const V of d.values()){const te=w!==null&&w!==V.id&&!P(w,V.id)||E!==null&&!D.has(V.id),oe=w===V.id,ae=E===V.id,le=nl(V.task,z),pe=V.x,be=V.y;i.save(),te&&(i.globalAlpha=.25),V.isCritical&&!te&&(i.save(),i.shadowColor=H.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,St(i,pe,be,Le,Ke,Mn),i.fillStyle="transparent",i.fill(),i.restore()),St(i,pe,be,Le,Ke,Mn),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=H.selectionColor||"#3182CE",i.lineWidth=2,St(i,pe-2,be-2,Le+4,Ke+4,Mn+2),i.stroke()),i.font=`600 12px ${H.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ce=An(i,V.task.name,Le-20);i.fillText(Ce,pe+10,be+8);const Ie=be+26;i.beginPath(),i.arc(pe+16,Ie+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(An(i,ue,Le-40),pe+24,Ie);const Se=sl(V.task),Me=Se===1?"1 day":`${Se} days`;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Me,pe+10,be+42),V.task.assignee&&(i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(An(i,V.task.assignee,Le/2-10),pe+Le-10,be+42));const We=V.task.progress??0,Je=be+Ke-6,Ne=Le-20,kt=3;if(St(i,pe+10,Je,Ne,kt,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),We>0){const Gn=Math.max(kt,Ne*Gt(We,0,1));St(i,pe+10,Je,Gn,kt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),C(G,H.fontFamily)}function C(X,L){if(!i)return;const H={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${H[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(g*100)}%`,_-12,12),i.restore()}function P(X,L){for(const H of h)if(H.sourceId===X&&H.targetId===L||H.sourceId===L&&H.targetId===X)return!0;return!1}function A(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;u=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const H=o.getContext("2d");H&&(i=H,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",me),o.addEventListener("mouseup",F),o.addEventListener("mouseleave",ee),o.addEventListener("dblclick",j),o.addEventListener("wheel",J,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function $(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(_=X.clientWidth,x=X.clientHeight,o.width=Math.round(_*a),o.height=Math.round(x*a),o.style.width=`${_}px`,o.style.height=`${x}px`)}function B(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),$(),Z(),Y();for(const X of d.values())X.x=X.targetX,X.y=X.targetY;U()}}function Q(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),w=null,E=null,D=new Set)}function Z(){r=_/2,c=x/2,g=1}function re(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function ge(X){const{x:L,y:H}=re(X),z=N(L,H);z?(m=z,z.isDragging=!0,S=O(L,H).x-z.x,k=O(L,H).y-z.y,E=z.id,D=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),U()):(b=!0,T=L,f=H,y=r,v=c,E&&(E=null,D=new Set,e.dispatch({type:"DESELECT_ALL"}),U()))}function me(X){if(!o)return;const{x:L,y:H}=re(X);if(m){const V=O(L,H);m.x=V.x-S,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U();return}if(b){const V=L-T,te=H-f;r=y+V,c=v+te,U();return}const z=N(L,H),G=z?z.id:null;G!==w&&(w=G,o.style.cursor=w?"pointer":"default",U())}function F(X){m&&(m.isDragging=!1,m=null),b=!1}function ee(X){m&&(m.isDragging=!1,m=null),b=!1,w&&(w=null,U())}function j(X){const{x:L,y:H}=re(X),z=N(L,H);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function J(X){if(X.preventDefault(),!o)return;const{x:L,y:H}=re(X),z=O(L,H),G=-X.deltaY*zr;g=Gt(g+G*g,io,ao);const V=O(L,H);r+=(V.x-z.x)*g,c+=(V.y-z.y)*g,U()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],H=o.getBoundingClientRect(),z=L.clientX-H.left,G=L.clientY-H.top,V=N(z,G);V?(m=V,V.isDragging=!0,S=O(z,G).x-V.x,k=O(z,G).y-V.y,E=V.id,D=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(b=!0,T=z,f=G,y=r,v=c),U()}else if(X.touches.length===2){b=!1,m&&(m.isDragging=!1,m=null);const L=X.touches[0],H=X.touches[1];se=Math.hypot(H.clientX-L.clientX,H.clientY-L.clientY),de=(L.clientX+H.clientX)/2,ie=(L.clientY+H.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const H=X.touches[0],z=H.clientX-L.left,G=H.clientY-L.top;if(m){const V=O(z,G);m.x=V.x-S,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U()}else if(b){const V=z-T,te=G-f;r=y+V,c=v+te,U()}}else if(X.touches.length===2){const H=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-H.clientX,z.clientY-H.clientY),V=(H.clientX+z.clientX)/2,te=(H.clientY+z.clientY)/2,oe=V-L.left,ae=te-L.top;if(se>0){const le=G/se,pe=O(oe,ae);g=Gt(g*le,io,ao);const be=O(oe,ae);r+=(be.x-pe.x)*g,c+=(be.y-pe.y)*g}r+=V-de,c+=te-ie,se=G,de=V,ie=te,U()}}function Te(X){m&&(m.isDragging=!1,m=null),b=!1,se=0}function ye(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",me),o.removeEventListener("mouseup",F),o.removeEventListener("mouseleave",ee),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",J),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),I&&(cancelAnimationFrame(R),I=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():B()})),t.push(e.on("networkGraph:layout",(...L)=>{const H=L[0];H!==s&&(s=H,n&&(Y(),K()))})),t.push(e.on("stateChange",()=>{n&&(Y(),K())}))},renderDOM(X,L){o||A(X),n&&($(),U())},destroy(){for(const X of t)X();t=[],ye(),d=new Map,h=[],p=null,n=!1}}}const co=300,uo="nimbus-gantt-config-panel",Ln="nimbus-gantt-config-panel-styles",go=300,Rn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],il=`
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
    transition: opacity ${go}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${co}px;
    width: ${co}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${go}ms ease;
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
`;function al(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(uo);return e?JSON.parse(e):{}}catch{return{}}}function rl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(uo,JSON.stringify(e))}catch{}}function ho(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Vt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ll(){if(typeof document>"u"||document.getElementById(Ln))return;const e=document.createElement("style");e.id=Ln,e.textContent=il,document.head.appendChild(e)}function cl(){if(typeof document>"u")return;const e=document.getElementById(Ln);e&&e.remove()}function Kt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);d.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(u),a.appendChild(d),a}function Dt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function jt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=fo(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function fo(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function dl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const w=e.getState();e.dispatch({type:"SET_SCROLL",x:w.scrollX,y:w.scrollY})}function d(w){Object.assign(t,w),rl(t)}function h(w,E,D){w[E]=D}function p(w,E){if(!e)return;const D=e.getState();h(D.config,w,E),d({[w]:E}),u()}function r(w,E){if(!e)return;const D=e.getState();h(D.config.theme,w,E),u()}function c(w){if(!e)return;const E=Rn.find(I=>I.name===w);if(!E)return;const D=e.getState();Object.assign(D.config.theme,E.values),d({themePreset:w}),u()}function g(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function b(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function T(w,E){var X;const{config:D}=E;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?b():g()}),w.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",b),w.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",w.appendChild(o)),o.innerHTML="";const I=document.createElement("div");I.className="ng-config-panel-header",I.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",b),I.appendChild(M),o.appendChild(I);const R=f("Display Settings");R.appendChild(Kt("Row height",24,60,D.rowHeight,2,L=>p("rowHeight",L))),R.appendChild(Kt("Bar height",16,40,D.barHeight,2,L=>p("barHeight",L))),R.appendChild(Kt("Grid width",0,500,D.gridWidth,10,L=>p("gridWidth",L))),R.appendChild(Kt("Font size",10,16,D.theme.fontSize,1,L=>{h(E.config.theme,"fontSize",L),d({fontSize:L}),u()})),R.appendChild(Dt("Today marker",D.showToday,L=>{h(E.config,"showToday",L),d({showToday:L}),u()})),R.appendChild(Dt("Weekends",D.showWeekends,L=>{h(E.config,"showWeekends",L),d({showWeekends:L}),u()})),R.appendChild(Dt("Progress bars",D.showProgress,L=>{h(E.config,"showProgress",L),d({showProgress:L}),u()})),R.appendChild(Dt("Dependency arrows",a,L=>{a=L,d({showDependencies:L}),u()})),R.appendChild(Dt("Labels on bars",t.showBarLabels!==!1,L=>{d({showBarLabels:L}),u()})),o.appendChild(R);const _=f("Color Theme"),x=document.createElement("div");x.className="ng-config-row";const O=document.createElement("span");O.className="ng-config-label",O.textContent="Preset";const N=document.createElement("select");N.className="ng-config-select";const Y=document.createElement("option");Y.value="",Y.textContent="Custom",N.appendChild(Y);for(const L of Rn){const H=document.createElement("option");H.value=L.name,H.textContent=L.name,t.themePreset===L.name&&(H.selected=!0),N.appendChild(H)}N.addEventListener("change",()=>{N.value&&c(N.value)}),x.appendChild(O),x.appendChild(N),_.appendChild(x),_.appendChild(jt("Bar default",D.theme.barDefaultColor,L=>{r("barDefaultColor",L),d({customColors:{...t.customColors,barDefault:L}})})),_.appendChild(jt("Today line",D.theme.todayLineColor,L=>{r("todayLineColor",L),d({customColors:{...t.customColors,todayLine:L}})})),_.appendChild(jt("Grid lines",D.theme.timelineGridColor,L=>{r("timelineGridColor",L),d({customColors:{...t.customColors,gridLines:L}})})),_.appendChild(jt("Background",D.theme.timelineBg,L=>{r("timelineBg",L),d({customColors:{...t.customColors,background:L}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",_.appendChild(W);const K={...D.colorMap,...t.statusColorMap},q=document.createElement("div");function U(){q.innerHTML="";const L=Object.entries(K);for(const[z,G]of L){const V=document.createElement("div");V.className="ng-config-color-map-entry";const te=document.createElement("input");te.className="ng-config-color-map-status",te.value=z,te.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=fo(G),oe.addEventListener("input",()=>{K[z]=oe.value,D.colorMap[z]=oe.value,d({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete D.colorMap[z],d({statusColorMap:{...K}}),U(),u()}),V.appendChild(te),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const H=document.createElement("button");H.className="ng-config-color-map-add",H.textContent="+ Add status color",H.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",D.colorMap[z.trim()]="#3b82f6",d({statusColorMap:{...K}}),U(),u())}),q.appendChild(H)}U(),_.appendChild(q),o.appendChild(_);const C=f("Zoom & Time"),P=document.createElement("div");P.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const $=document.createElement("div");$.className="ng-config-zoom-group";const B=["day","week","month","quarter"];for(const L of B){const H=document.createElement("button");H.className="ng-config-zoom-btn"+(E.zoomLevel===L?" ng-active":""),H.textContent=L.charAt(0).toUpperCase()+L.slice(1),H.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),d({zoomLevel:L}),$.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===H)))}),$.appendChild(H)}P.appendChild(A),P.appendChild($),C.appendChild(P);const Q=document.createElement("div");Q.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=ho(E.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const L=Vt(re.value),H=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeStart:re.value})}),Q.appendChild(Z),Q.appendChild(re),C.appendChild(Q);const ge=document.createElement("div");ge.className="ng-config-row";const me=document.createElement("span");me.className="ng-config-label",me.textContent="End date";const F=document.createElement("input");F.type="date",F.className="ng-config-date-input",F.value=ho(E.dateRange.end),F.addEventListener("change",()=>{if(!e||!F.value)return;const L=e.getState().dateRange.start,H=Vt(F.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeEnd:F.value})}),ge.appendChild(me),ge.appendChild(F),C.appendChild(ge);const ee=document.createElement("div");ee.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),ee.appendChild(j),C.appendChild(ee),o.appendChild(C);const J=f("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:E.scrollX,y:E.scrollY}),y("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>y("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&S(e.getState())}),se.appendChild(ce),J.appendChild(se),o.appendChild(J);const Te=f("Plugin Toggles"),ye=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of ye){const H=document.createElement("div");H.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=L.label;const G=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const te=document.createElement("div");te.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",te.appendChild(oe);let ae=G;te.addEventListener("click",()=>{ae=!ae,te.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[L.key]:ae};d({pluginToggles:pe}),y(L.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),H.appendChild(le),H.appendChild(te),Te.appendChild(H)}o.appendChild(Te)}function f(w){const E=document.createElement("div");E.className="ng-config-section";const D=document.createElement("div");return D.className="ng-config-section-title",D.textContent=w,E.appendChild(D),E}function y(w){e&&v.forEach(E=>E(w))}const v=[];function m(w){const E=Array.from(w.tasks.values());if(E.length===0)return;const D=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],I=E.map(O=>[O.id,`"${(O.name||"").replace(/"/g,'""')}"`,O.startDate,O.endDate,String(Math.round((O.progress??0)*100))+"%",O.status||"",O.assignee||"",O.priority||"",O.groupName||""]),M=[D.join(","),...I.map(O=>O.join(","))].join(`
`),R=new Blob([M],{type:"text/csv;charset=utf-8;"}),_=URL.createObjectURL(R),x=document.createElement("a");x.href=_,x.download="gantt-tasks.csv",document.body.appendChild(x),x.click(),document.body.removeChild(x),URL.revokeObjectURL(_)}function S(w){const E=Array.from(w.tasks.values());if(E.length===0)return;const D=["Name","Start","End","Progress","Status","Assignee"],I=E.map(_=>[_.name,_.startDate,_.endDate,Math.round((_.progress??0)*100)+"%",_.status||"",_.assignee||""]),R=[D.join("	"),...I.map(_=>_.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(R).catch(()=>{})}function k(w){const E=t;if(E.rowHeight!==void 0&&h(w.config,"rowHeight",E.rowHeight),E.barHeight!==void 0&&h(w.config,"barHeight",E.barHeight),E.gridWidth!==void 0&&h(w.config,"gridWidth",E.gridWidth),E.fontSize!==void 0&&h(w.config.theme,"fontSize",E.fontSize),E.showToday!==void 0&&h(w.config,"showToday",E.showToday),E.showWeekends!==void 0&&h(w.config,"showWeekends",E.showWeekends),E.showProgress!==void 0&&h(w.config,"showProgress",E.showProgress),E.showDependencies!==void 0&&(a=E.showDependencies),E.themePreset){const D=Rn.find(I=>I.name===E.themePreset);D&&Object.assign(w.config.theme,D.values)}E.customColors&&(E.customColors.barDefault&&h(w.config.theme,"barDefaultColor",E.customColors.barDefault),E.customColors.todayLine&&h(w.config.theme,"todayLineColor",E.customColors.todayLine),E.customColors.gridLines&&h(w.config.theme,"timelineGridColor",E.customColors.gridLines),E.customColors.background&&h(w.config.theme,"timelineBg",E.customColors.background)),E.statusColorMap&&Object.assign(w.config.colorMap,E.statusColorMap),E.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:E.zoomLevel})),E.dateRangeStart&&E.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:Vt(E.dateRangeStart),end:Vt(E.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(w){e=w,ll(),t=al();const E=w.on("render",()=>{E(),k(w.getState()),u()});l.push(E);const D=w.on("config:open",()=>g()),I=w.on("config:close",()=>b()),M=w.on("config:toggle",()=>{i?b():g()});l.push(D,I,M)},renderDOM(w,E){T(w,E)},destroy(){l.forEach(w=>w()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),cl(),e=null,i=!1}}}const po=864e5,Pn="nimbus-gantt-heatmap-styles",we=28,Re=2,je=48,Pe=160,ul=3,mo="#1e1e2e",To="#166534",yo="#a16207",bo="#b91c1c",gl=`
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
`;function vo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function hl(e){return String(e.getUTCDate())}function fl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function pl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function wo(e,t){return Math.round((t.getTime()-e.getTime())/po)}function So(e,t){return new Date(e.getTime()+t*po)}function dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function ml(e,t){return e===0?mo:e===1?To:e===2?yo:bo}function Tl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function yl(){if(typeof document>"u"||document.getElementById(Pn))return;const e=document.createElement("style");e.id=Pn,e.textContent=gl,document.head.appendChild(e)}function bl(){if(typeof document>"u")return;const e=document.getElementById(Pn);e&&e.remove()}function vl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=wo(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(So(o,h));const u=new Map;let d=0;for(const h of s)for(const p of l){const r=`${h}|${dt(p)}`;u.set(r,{assignee:h,date:p,dateKey:dt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=vo(h.startDate),c=vo(h.endDate),g=wo(r,c)+1;for(let b=0;b<g;b++){const T=So(r,b),f=`${p}|${dt(T)}`,y=u.get(f);y&&(y.tasks.push(h),y.count++,y.count>d&&(d=y.count))}}return{assignees:s,dates:l,cells:u,maxCount:d}}function wl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=vl(p);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const g=document.createElement("canvas"),b=Pe+r.dates.length*(we+Re),T=je+r.assignees.length*(we+Re),f=window.devicePixelRatio||1;g.width=b*f,g.height=T*f,g.style.width=b+"px",g.style.height=T+"px",g.style.cursor="pointer";const y=g.getContext("2d");y.scale(f,f),y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle";let v="",m=Pe;for(let S=0;S<r.dates.length;S++){const k=r.dates[S],w=fl(k),E=Pe+S*(we+Re);if(w!==v){if(v&&S>0){const D=(m+E)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,D,12)}m=E,v=w}}if(v){const S=Pe+r.dates.length*(we+Re),k=(m+S)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,k,12)}y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let S=0;S<r.dates.length;S++){const k=r.dates[S],w=Pe+S*(we+Re)+we/2,E=k.getUTCDay()===0||k.getUTCDay()===6;y.fillStyle=E?"#475569":"#64748b",y.fillText(hl(k),w,32)}y.beginPath(),y.strokeStyle="#1e293b",y.lineWidth=1,y.moveTo(0,je-.5),y.lineTo(b,je-.5),y.stroke();for(let S=0;S<r.assignees.length;S++){const k=r.assignees[S],w=je+S*(we+Re);y.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="left",y.textBaseline="middle",y.fillStyle="#cbd5e1",y.save(),y.beginPath(),y.rect(0,w,Pe-8,we),y.clip(),y.fillText(k,8,w+we/2),y.restore();for(let E=0;E<r.dates.length;E++){const D=r.dates[E],I=`${k}|${dt(D)}`,M=r.cells.get(I),R=(M==null?void 0:M.count)??0,_=Pe+E*(we+Re),x=ml(R),O=Tl(R,r.maxCount);y.globalAlpha=O,y.fillStyle=x,h(y,_,w,we,we,ul),y.fill(),R>=2&&(y.globalAlpha=1,y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle",y.fillStyle="#fff",y.fillText(String(R),_+we/2,w+we/2)),y.globalAlpha=1}}c.appendChild(g),g.addEventListener("mousemove",S=>{if(!n)return;const k=g.getBoundingClientRect(),w=S.clientX-k.left,E=S.clientY-k.top,D=Math.floor((w-Pe)/(we+Re)),I=Math.floor((E-je)/(we+Re));if(D<0||D>=r.dates.length||I<0||I>=r.assignees.length||w<Pe||E<je){n.classList.remove("ng-visible");return}const M=r.dates[D],R=r.assignees[I],_=`${R}|${dt(M)}`,x=r.cells.get(_);if(!x||x.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const O=document.createElement("div");O.className="ng-heatmap-tooltip-date",O.textContent=`${R} - ${pl(M)}`,n.appendChild(O);for(const W of x.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const N=S.clientX+12,Y=S.clientY+12;n.style.left=N+"px",n.style.top=Y+"px"}),g.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),g.addEventListener("click",S=>{if(!e)return;const k=g.getBoundingClientRect(),w=S.clientX-k.left,E=S.clientY-k.top,D=Math.floor((w-Pe)/(we+Re)),I=Math.floor((E-je)/(we+Re));if(D<0||D>=r.dates.length||I<0||I>=r.assignees.length||w<Pe||E<je)return;const M=r.dates[D],_=`${r.assignees[I]}|${dt(M)}`,x=r.cells.get(_);if(!(!x||x.count===0)){u();for(const O of x.tasks)e.dispatch({type:"SELECT_TASK",taskId:O.id,multi:!0})}})}function h(p,r,c,g,b,T){p.beginPath(),p.moveTo(r+T,c),p.lineTo(r+g-T,c),p.quadraticCurveTo(r+g,c,r+g,c+T),p.lineTo(r+g,c+b-T),p.quadraticCurveTo(r+g,c+b,r+g-T,c+b),p.lineTo(r+T,c+b),p.quadraticCurveTo(r,c+b,r,c+b-T),p.lineTo(r,c+T),p.quadraticCurveTo(r,c,r+T,c),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,yl();const r=p.on("heatmap:toggle",()=>a()),c=p.on("heatmap:show",()=>l()),g=p.on("heatmap:hide",()=>u());i.push(r,c,g)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const g=document.createElement("span");g.className="ng-heatmap-title",g.textContent="Resource Heatmap",c.appendChild(g);const b=document.createElement("div");b.className="ng-heatmap-legend";const T=[{color:mo,label:"None"},{color:To,label:"1 task"},{color:yo,label:"2 tasks"},{color:bo,label:"3+ tasks"}];for(const y of T){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=y.color,b.appendChild(v);const m=document.createElement("span");m.textContent=y.label,b.appendChild(m)}c.appendChild(b);const f=document.createElement("button");f.className="ng-heatmap-close",f.textContent="Back to Gantt",f.addEventListener("click",u),c.appendChild(f),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),bl(),e=null,s=!1,o=null}}}const qe=200,Ze=80,Do=12,Eo=6,Sl="rgba(255, 255, 255, 0.95)",Dl="#cbd5e1",El="rgba(59, 130, 246, 0.3)",kl="rgba(59, 130, 246, 0.7)",Cl=1.5,Il=2,Ml=1,$n="nimbus-gantt-minimap-styles",Al=864e5,Ll=`
  .ng-minimap {
    position: absolute;
    bottom: ${Do}px;
    right: ${Do}px;
    width: ${qe}px;
    height: ${Ze}px;
    z-index: 900;
    border-radius: ${Eo}px;
    border: 1px solid ${Dl};
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
    border-radius: ${Eo}px;
  }
`;function Rl(){if(typeof document>"u"||document.getElementById($n))return;const e=document.createElement("style");e.id=$n,e.textContent=Ll,document.head.appendChild(e)}function Pl(){if(typeof document>"u")return;const e=document.getElementById($n);e&&e.remove()}function $l(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,d=0,h=0,p=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function g(){o=!0,t&&t.classList.remove("ng-hidden")}function b(){o=!1,t&&t.classList.add("ng-hidden")}function T(S,k){const w=S/l-p/2,E=k/u-r/2;return{x:Math.max(0,Math.min(w,d-p)),y:Math.max(0,Math.min(E,h-r))}}function f(S){if(!e||!n)return;S.preventDefault(),i=!0;const k=n.getBoundingClientRect(),w=S.clientX-k.left,E=S.clientY-k.top,D=T(w,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function y(S){if(!i||!e||!n)return;S.preventDefault();const k=n.getBoundingClientRect(),w=Math.max(0,Math.min(S.clientX-k.left,qe)),E=Math.max(0,Math.min(S.clientY-k.top,Ze)),D=T(w,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function v(){i=!1}function m(S,k){if(!s||!n||!o)return;const w=window.devicePixelRatio||1;n.width=qe*w,n.height=Ze*w,n.style.width=qe+"px",n.style.height=Ze+"px",s.scale(w,w);const{config:E,scrollX:D,scrollY:I,dateRange:M}=S,R=e.getTimeScale(),_=Math.round((M.end.getTime()-M.start.getTime())/Al),x=R.getColumnWidth();if(d=Math.max(_*x,1),h=Math.max(S.flatVisibleIds.length*E.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const A=t.parentElement;p=A.clientWidth-E.gridWidth,r=A.clientHeight-E.headerHeight}l=qe/Math.max(d,1),u=Ze/Math.max(h,1),s.fillStyle=Sl,s.fillRect(0,0,qe,Ze);const O=new Map;for(const A of k)O.has(A.rowIndex)||O.set(A.rowIndex,[]),O.get(A.rowIndex).push(A);for(const A of k){const $=A.x*l,B=Math.max(A.width*l,1),Q=A.rowIndex*E.rowHeight*u;s.fillStyle=A.color||E.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect($,Q,B,Math.max(Il,E.rowHeight*u-Ml))}s.globalAlpha=1;const N=D*l,Y=I*u,W=p*l,K=r*u,q=Math.max(0,Math.min(N,qe-1)),U=Math.max(0,Math.min(Y,Ze-1)),C=Math.min(W,qe-q),P=Math.min(K,Ze-U);s.fillStyle=El,s.fillRect(q,U,C,P),s.strokeStyle=kl,s.lineWidth=Cl,s.strokeRect(q,U,C,P)}return{name:"MiniMapPlugin",install(S){e=S,Rl();const k=S.on("minimap:toggle",()=>c()),w=S.on("minimap:show",()=>g()),E=S.on("minimap:hide",()=>b());a.push(k,w,E),typeof document<"u"&&(document.addEventListener("mousemove",y),document.addEventListener("mouseup",v))},renderDOM(S,k){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",f),t.appendChild(n),S.appendChild(t));const w=(e==null?void 0:e.getLayouts())??[];m(k,w)},destroy(){a.forEach(S=>S()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",y),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,Pl(),e=null,o=!0,i=!1}}}const _l="#f59e0b",Nl=[6,4],Ol=1,et=16,Hl=4,xl="rgba(15, 23, 42, 0.95)",Bl="#e2e8f0",Fl="#334155",Yl=6,tt=10,ko=220,Co=12,Io=13;function Ul(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Et(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Wl(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Et(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function Xl(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const d=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(h)*d,r=n+Math.sin(h)*d;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke()}function zl(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function Gl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Vl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Mo={flag:Wl,star:Xl,warning:zl,info:Gl,deadline:Vl};function Kl(e,t,n,s,o){e.save();const i=`${Co}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Io}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let d=0;if(t.description){const T=t.description.split(" ");let f="";for(const y of T){const v=f?f+" "+y:y;e.measureText(v).width>ko-tt*2&&f?(u.push(f),d=Math.max(d,e.measureText(f).width),f=y):f=v}f&&(u.push(f),d=Math.max(d,e.measureText(f).width))}const h=Math.min(ko,Math.max(l,d)+tt*2),p=Co+4,r=Io+4,c=tt*2+r+(u.length>0?4+u.length*p:0);let g=n-h/2;const b=s-c-8;if(g<4&&(g=4),g+h>o-4&&(g=o-h-4),e.beginPath(),jl(e,g,b,h,c,Yl),e.fillStyle=xl,e.fill(),e.strokeStyle=Fl,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Bl,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,g+tt,b+tt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let T=b+tt+r+4;for(const f of u)e.fillText(f,g+tt,T),T+=p}e.restore()}function jl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function ql(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,d=null;function h(f){return n.find(y=>y.id===f)}function p(f){n.push(f),b()}function r(f){n=n.filter(y=>y.id!==f),b()}function c(f,y){const v=h(f);v&&(Object.assign(v,y),b())}function g(){return[...n]}function b(){if(!t)return;const f=t.getState();t.dispatch({type:"SET_SCROLL",x:f.scrollX,y:f.scrollY})}function T(f){const y=f.canvas;d!==y&&(d&&u&&d.removeEventListener("mousemove",u),d=y,u=v=>{const m=y.getBoundingClientRect();a=v.clientX-m.left,l=v.clientY-m.top;let S=null;for(const k of o){const w=a-k.x,E=l-k.y;if(Math.sqrt(w*w+E*E)<=k.size){S=k.note.id;break}}S!==s&&(s=S,y.style.cursor=s?"pointer":"",b())},y.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(f){t=f;const y=f.on("notes:add",(...k)=>{const w=k[0];w&&w.id&&w.date&&w.label&&p(w)}),v=f.on("notes:remove",(...k)=>{const w=k[0];w&&r(w)}),m=f.on("notes:update",(...k)=>{const w=k[0];if(w&&w.id){const{id:E,...D}=w;c(E,D)}}),S=f.on("notes:list",(...k)=>{const w=k[0];typeof w=="function"&&w(g())});i.push(y,v,m,S)},renderCanvas(f,y,v){if(!t||n.length===0)return;const{config:m,scrollX:S,scrollY:k,dateRange:w}=y,{theme:E}=m,D=m.headerHeight,I=t.getTimeScale();T(f);const M=f.canvas.width/(window.devicePixelRatio||1),R=f.canvas.height/(window.devicePixelRatio||1),_=D,x=R-_;o=[],f.save();for(const O of n){const N=Ul(O.date);if(N<w.start||N>w.end)continue;const Y=O.color||_l,W=O.icon||"flag",K=I.dateToX(N)-S;if(K<-et||K>M+et)continue;f.save(),f.beginPath(),f.setLineDash(Nl),f.strokeStyle=Y,f.globalAlpha=.5,f.lineWidth=Ol,f.moveTo(K,_),f.lineTo(K,_+x),f.stroke(),f.setLineDash([]),f.globalAlpha=1,f.restore();const q=K,U=_+Hl+et/2,C=Mo[W]||Mo.flag;f.save(),f.beginPath(),f.arc(q,U,et/2+3,0,Math.PI*2),f.fillStyle="rgba(0, 0, 0, 0.4)",f.fill(),f.restore(),f.save(),C(f,q,U,et,Y),f.restore(),o.push({note:O,x:q,y:U,size:et/2+4}),s===O.id&&Kl(f,O,q,U-et/2-4,M)}f.restore()},destroy(){i.forEach(f=>f()),i.length=0,d&&u&&d.removeEventListener("mousemove",u),t=null,d=null,u=null,s=null,o=[]}}}const Zl=500,Jl=40,Ao=7,Lo=3,Ro=5,Ql=500,_n="nimbus-gantt-timetravel-styles",Po={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},ec=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Jl}px;
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
    width: ${Ao*2}px;
    height: ${Ao*2}px;
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
    width: ${Lo*2}px;
    height: ${Lo*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${Ro*2}px;
    height: ${Ro*2}px;
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
`;function tc(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function nc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function sc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function oc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function ic(){if(typeof document>"u"||document.getElementById(_n))return;const e=document.createElement("style");e.id=_n,e.textContent=ec,document.head.appendChild(e)}function ac(){if(typeof document>"u")return;const e=document.getElementById(_n);e&&e.remove()}const $o=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),qt=[.5,1,2,4];function rc(e){const t=(e==null?void 0:e.maxSnapshots)??Zl,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,d=1;const h=[];let p=null,r=null,c=null,g=null,b=null,T=null,f=null,y=!1;function v(U){if(!s||a)return;const C=s.getState(),P=sc(C,U);i<o.length-1&&(o.length=i+1),o.push(P),o.length>t&&o.shift(),i=o.length-1}function m(U){if(!s||o.length===0)return;const C=Math.max(0,Math.min(U,o.length-1));i=C;const P=o[C];a=!0;const A=P.tasks.map(B=>({id:B.id,name:B.name,startDate:B.startDate,endDate:B.endDate,progress:B.progress,status:B.status})),$=P.dependencies.map(B=>({id:B.id,source:B.source,target:B.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:$}),a=!1,_()}function S(){o.length>0&&m(o.length-1),w()}function k(){if(l||o.length<=1)return;l=!0;const U=qt[d],C=Ql/U;u=setInterval(()=>{if(i>=o.length-1){w();return}m(i+1)},C),_()}function w(){l=!1,u!==null&&(clearInterval(u),u=null),_()}function E(){l?w():k()}function D(){d=(d+1)%qt.length,l&&(w(),k()),_()}function I(){w(),i>0&&m(i-1)}function M(){w(),i<o.length-1&&m(i+1)}function R(){w(),o.length=0,i=-1,a=!1,_()}function _(){if(p){if(g){const U=o.length,C=U>0?i+1:0;g.textContent=`${C} / ${U}`}b&&(b.textContent=l?"⏸":"▶",b.classList.toggle("ng-active",l)),T&&(T.textContent=`${qt[d]}x`),x(),O()}}function x(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const U=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${U}%`}function O(){if(!f||!r||(f.innerHTML="",o.length===0))return;const U=200,C=o.length>U?Math.ceil(o.length/U):1;for(let P=0;P<o.length;P+=C){const A=o[P],$=o.length<=1?50:P/(o.length-1)*100,B=tc(A.action.split(" ")[0]==="Loaded"?"SET_DATA":N(A.action)),Q=Po[B]||Po.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${$}%`,Z.style.background=Q;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${oc(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=P;Z.addEventListener("click",me=>{me.stopPropagation(),w(),m(ge)}),f.appendChild(Z)}}function N(U){return U.startsWith("Moved")?"TASK_MOVE":U.startsWith("Resized")?"TASK_RESIZE":U.startsWith("Added task")?"ADD_TASK":U.startsWith("Added dependency")?"ADD_DEPENDENCY":U.startsWith("Removed task")?"REMOVE_TASK":U.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":U.startsWith("Updated")?"UPDATE_TASK":(U.startsWith("Loaded"),"SET_DATA")}function Y(U){if(!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));w(),m(A)}function W(U){U.preventDefault(),U.stopPropagation(),y=!0,c&&c.classList.add("ng-dragging"),w()}function K(U){if(!y||!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));m(A)}function q(){y&&(y=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(U){s=U,ic(),h.push(U.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),U.on("timeTravel:scrub",(...C)=>{const P=C[0];w(),m(P)}),U.on("timeTravel:play",()=>k()),U.on("timeTravel:pause",()=>w()),U.on("timeTravel:present",()=>S()),U.on("timeTravel:clear",()=>R()),U.on("timeTravel:history",(...C)=>{const P=C[0];typeof P=="function"&&P([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(U,C){let P="";n&&$o.has(U.type)&&s&&!a&&(P=nc(U,s.getState())),C(U),n&&$o.has(U.type)&&!a&&P&&v(P)},renderDOM(U,C){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const P=document.createElement("button");P.className="ng-timetravel-btn",P.textContent="◀",P.title="Step backward",P.addEventListener("click",()=>I()),p.appendChild(P),b=document.createElement("button"),b.className="ng-timetravel-btn",b.textContent="▶",b.title="Play / Pause",b.addEventListener("click",()=>E()),p.appendChild(b);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>M()),p.appendChild(A),T=document.createElement("span"),T.className="ng-timetravel-speed ng-timetravel-btn",T.textContent=`${qt[d]}x`,T.title="Click to cycle speed",T.addEventListener("click",()=>D()),p.appendChild(T),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",Y);const $=document.createElement("div");$.className="ng-timetravel-rail",r.appendChild($),f=document.createElement("div"),f.style.position="absolute",f.style.inset="0",r.appendChild(f),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",W),r.appendChild(c),p.appendChild(r),g=document.createElement("span"),g.className="ng-timetravel-counter",p.appendChild(g);const B=document.createElement("button");B.className="ng-timetravel-btn ng-present",B.textContent="Present",B.title="Return to latest state",B.addEventListener("click",()=>S()),p.appendChild(B),U.appendChild(p)}_()},destroy(){w();for(const U of h)U();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,c=null,g=null,b=null,T=null,f=null,ac(),o.length=0,i=-1,a=!1,l=!1,y=!1,s=null}}}const _o=864e5,lc=60,cc=2,No=[6,4],Nn="nimbus-gantt-montecarlo-styles",Oo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},dc=.08,uc=`
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
`;function On(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Zt(e,t){return Math.round((t.getTime()-e.getTime())/_o)}function nt(e,t){return new Date(e.getTime()+t*_o)}function Ho(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function xo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function gc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function hc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function fc(e,t){return e+Math.random()*(t-e)}function pc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const d=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(l),r=[];for(let b=0;b<u;b++)p[b]===0&&(r.push(b),d[b]=o[b],h[b]=o[b]+s[b]);let c=0;for(;c<r.length;){const b=r[c++],T=h[b],f=i[b];for(let y=0;y<f.length;y++){const v=f[y];T>d[v]&&(d[v]=T,h[v]=T+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let b=0;b<u;b++)h[b]===0&&s[b]>0&&(d[b]=o[b],h[b]=o[b]+s[b]);let g=0;for(let b=0;b<u;b++)h[b]>g&&(g=h[b]);return g}function mc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),d=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let T=0;T<e;T++)h[T]===0&&(r.push(T),a[T]=n[T],l[T]=n[T]+t[T]);let c=0;for(;c<r.length;){const T=r[c++];p.push(T);const f=l[T];for(const y of s[T])f>a[y]&&(a[y]=f,l[y]=f+t[y]),h[y]--,h[y]===0&&r.push(y)}for(let T=0;T<e;T++)l[T]===0&&t[T]>0&&(a[T]=n[T],l[T]=n[T]+t[T],p.push(T));let g=0;for(let T=0;T<e;T++)l[T]>g&&(g=l[T]);for(let T=0;T<e;T++)s[T].length===0?(d[T]=g,u[T]=g-t[T]):(d[T]=1/0,u[T]=1/0);for(let T=p.length-1;T>=0;T--){const f=p[T];if(d[f]===1/0){let y=1/0;for(const v of s[f])u[v]<y&&(y=u[v]);y===1/0?d[f]=g:d[f]=y,u[f]=d[f]-t[f]}}const b=new Set;for(let T=0;T<e;T++){const f=u[T]-a[T];Math.abs(f)<.5&&b.add(T)}return b}function Tc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const $ of e.keys())u.set($,l.length),l.push($);const d=l.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const $ of e.values()){const B=On($.startDate).getTime();B<r&&(r=B)}const c=new Date(r);for(let $=0;$<d;$++){const B=e.get(l[$]),Q=On(B.startDate),Z=On(B.endDate);h[$]=Math.max(Zt(Q,Z),1),p[$]=Zt(c,Q)}const g=Array.from({length:d},()=>[]),b=Array.from({length:d},()=>[]),T=new Int32Array(d);for(const $ of t.values()){if(($.type||"FS")!=="FS")continue;const Q=u.get($.source),Z=u.get($.target);Q===void 0||Z===void 0||(g[Q].push(Z),b[Z].push(Q),T[Z]++)}const f=g.map($=>new Int32Array($)),y=b.map($=>new Int32Array($)),v=new Float64Array(s),m=new Float64Array(d),S=new Float64Array(d),k=new Float64Array(d),w=new Float64Array(d),E=new Float64Array(d),D=Math.max(1,Math.floor(s/100));for(let $=0;$<s;$++){for(let B=0;B<d;B++){const Q=h[B];let Z;switch(i){case"triangular":{const re=Q*(1-o),ge=Q,me=Q*(1+o*1.5);Z=gc(re,ge,me);break}case"normal":{Z=hc(Q,Q*o);break}case"uniform":{Z=fc(Q*(1-o),Q*(1+o));break}}m[B]=Math.max(.5,Z),S[B]+=m[B],k[B]+=m[B]*m[B],m[B]>h[B]&&w[B]++}if(v[$]=pc(l,u,h,m,p,f,y,T),$%D===0){const B=mc(d,m,p,f,y,T);for(const Q of B)E[Q]++}}const I=Array.from(v).sort(($,B)=>$-B),M=I.map($=>nt(c,$)),R=new Map;for(const $ of a){const B=Math.min(Math.floor($*I.length),I.length-1);R.set($,nt(c,I[B]))}let _=0;for(let $=0;$<s;$++)_+=I[$];const x=_/s,O=nt(c,x),N=Math.floor(s/2),Y=nt(c,I[N]);let W=0;for(let $=0;$<s;$++){const B=I[$]-x;W+=B*B}const K=Math.sqrt(W/s),q=nt(c,I[0]),U=nt(c,I[I.length-1]),C=new Map;for(let $=0;$<d;$++){const B=S[$]/s,Q=k[$]/s-B*B;C.set(l[$],{meanDuration:B,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:w[$]/s})}const P=Math.floor(s/D),A=new Map;for(let $=0;$<d;$++)E[$]>0&&A.set(l[$],E[$]/P);return{iterations:s,finishDates:M,percentiles:R,meanFinishDate:O,medianFinishDate:Y,earliestFinish:q,latestFinish:U,standardDeviation:K,taskRisk:C,criticalPathFrequency:A}}function yc(){if(typeof document>"u"||document.getElementById(Nn))return;const e=document.createElement("style");e.id=Nn,e.textContent=uc,document.head.appendChild(e)}function bc(){if(typeof document>"u")return;const e=document.getElementById(Nn);e&&e.remove()}function vc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},g=n.getState();s=Tc(g.tasks,g.dependencies,c),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",c=0;for(const[f,y]of s.criticalPathFrequency)y>c&&(c=y,r=f);let g=r;if(n){const f=n.getState().tasks.get(r);f&&(g=f.name)}let b=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const f of t.confidenceLevels){const y=s.percentiles.get(f);if(!y)continue;const v=Math.round(f*100),m=Oo[f]||"#94A3B8";b+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${xo(y)}</span>
        </div>
      `}if(b+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${xo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const f=Math.round(c*100);b+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${g} (on critical path ${f}% of runs)
        </div>
      `}a.innerHTML=b;const T=a.querySelector(".ng-montecarlo-close");T&&T.addEventListener("click",()=>u())}function p(r,c){if(!s||!n||s.finishDates.length===0)return;const g=n.getTimeScale(),{headerHeight:b}=c.config,T=c.scrollX,f=r.canvas.width/(window.devicePixelRatio||1),y=r.canvas.height/(window.devicePixelRatio||1),v=b,m=y-v,S=s.earliestFinish,k=s.latestFinish,w=Math.max(Zt(S,k),1),E=g.getColumnWidth(),D=Math.max(E,cc),I=Math.max(Math.ceil(w),1),M=new Uint32Array(I);for(const N of s.finishDates){const Y=Zt(S,N),W=Math.min(Math.max(Math.floor(Y),0),I-1);M[W]++}let R=0;for(let N=0;N<I;N++)M[N]>R&&(R=M[N]);if(R===0)return;r.save(),r.beginPath(),r.rect(0,v,f,m),r.clip(),r.translate(-T,0);const _=s.finishDates[Math.floor(s.finishDates.length*.1)],x=s.finishDates[Math.floor(s.finishDates.length*.9)];if(_&&x){const N=g.dateToX(_),Y=g.dateToX(x),W=r.createLinearGradient(N,0,Y,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=dc*5,r.fillRect(N,v,Y-N,m),r.globalAlpha=1}const O=y-8;for(let N=0;N<I;N++){if(M[N]===0)continue;const Y=nt(S,N),W=g.dateToX(Y),K=M[N]/R*lc,q=I>1?N/(I-1):.5;let U,C,P;if(q<.5){const A=q*2;U=Math.round(34+200*A),C=Math.round(197+-18*A),P=Math.round(94+-86*A)}else{const A=(q-.5)*2;U=Math.round(234+5*A),C=Math.round(179+-111*A),P=Math.round(8+60*A)}r.fillStyle=`rgba(${U}, ${C}, ${P}, 0.6)`,r.fillRect(W,O-K,Math.max(D-1,1),K)}r.setLineDash(No),r.lineWidth=1.5;for(const[N,Y]of s.percentiles){const W=g.dateToX(Y),K=Oo[N]||"#94A3B8",q=`P${Math.round(N*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,v),r.lineTo(W,y),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const U=r.measureText(`${q}: ${Ho(Y)}`).width,C=`${q}: ${Ho(Y)}`,P=U+8,A=16,$=W-P/2,B=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo($+3,B),r.lineTo($+P-3,B),r.arcTo($+P,B,$+P,B+3,3),r.lineTo($+P,B+A-3),r.arcTo($+P,B+A,$+P-3,B+A,3),r.lineTo($+3,B+A),r.arcTo($,B+A,$,B+A-3,3),r.lineTo($,B+3),r.arcTo($,B,$+3,B,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(C,W,B+3),r.setLineDash(No)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,yc(),i.push(r.on("montecarlo:run",(...c)=>{const g=c[0];l(g)}),r.on("montecarlo:result",(...c)=>{const g=c[0];typeof g=="function"&&g(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...c)=>{const g=c[0];g&&d(g)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,g){!o||!s||p(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),bc(),s=null,n=null}}}const Jt=864e5,Bo=400,Hn="nimbus-gantt-narrative-styles",Fo=300;function Ye(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function xn(e,t){return Math.round((t.getTime()-e.getTime())/Jt)}function Yo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Uo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*Jt)}function Wo(e,t){return new Date(e.getTime()+t*Jt)}function wc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const D of n){const I=Ye(D.startDate).getTime(),M=Ye(D.endDate).getTime();I<s&&(s=I),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=xn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const d=new Map,h=new Map;for(const D of t.values())!e.has(D.source)||!e.has(D.target)||(d.has(D.source)||d.set(D.source,[]),d.get(D.source).push(D.target),h.has(D.target)||h.set(D.target,[]),h.get(D.target).push(D.source));const p=kc(n,t),r=Uo(i),c=Uo(a),g=[];let b=r;for(;b.getTime()<=c.getTime();)g.push({start:new Date(b),end:Wo(b,6)}),b=Wo(b,7);const T=[];for(let D=0;D<g.length;D++){const I=g[D],M=I.start,R=I.end,_=[],x=[],O=[],N=[],Y=[],W=[],K=[];for(const A of n){const $=Ye(A.startDate),B=Ye(A.endDate);$>=M&&$<=R&&(_.push(A),A.isMilestone?(W.push(A),K.push(`Milestone: ${A.name}`)):K.push(`Started: ${A.name}`)),B>=M&&B<=R&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(x.push(A),K.push(`Completed: ${A.name}`)),$<=R&&B>=M&&(Y.push(A),$<M&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&O.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&N.push(A))}for(const A of n)if(A.isMilestone){const $=Ye(A.startDate);$>=M&&$<=R&&!W.includes(A)&&(W.push(A),K.push(`Milestone: ${A.name}`))}const q=Y.filter(A=>p.has(A.id)),U=Sc(_,x,O,Y,q),C=Dc(_,x,O,N,Y,q,W,d,e),P=`Week ${D+1} (${Yo(M)}–${Yo(R)})`;T.push({weekLabel:P,headline:U,body:C,metrics:{started:_.length,completed:x.length,delayed:O.length,onTrack:N.length},events:K})}const f=n.length,y=n.filter(D=>D.isCompleted||D.progress!==void 0&&D.progress>=1).length,v=n.filter(D=>!D.isCompleted&&D.progress!==void 0&&D.progress>0&&D.progress<1).length,m=f-y-v,S=f>0?Math.round(y/f*100):0,k=S>=75?"strong":S>=50?"moderate":S>=25?"early-stage":"just getting started",w=`This project spans ${l} days across ${g.length} weeks with ${f} tasks. Progress is ${k} at ${S}% completion (${y} done, ${v} in progress, ${m} not started).`,E=Ec(n,p,d,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:w,chapters:T,insights:E}}function Sc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Dc(e,t,n,s,o,i,a,l,u){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(g=>g.name).join(", ");d.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const g=l.get(c.id);if(g)for(const b of g){const T=u.get(b);T&&!r.includes(T.name)&&r.push(T.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,c)=>c[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function Ec(e,t,n,s,o,i,a){const l=[];if(t.size>0){const T=e.filter(v=>t.has(v.id)),f=T.slice(0,4).map(v=>v.name).join(", "),y=T.length>4?` and ${T.length-4} more`:"";l.push(`The critical path runs through ${f}${y} — any delay here pushes the project finish.`)}const u=new Map;for(const T of e)T.assignee&&!T.isCompleted&&u.set(T.assignee,(u.get(T.assignee)||0)+1);const d=Array.from(u.entries()).sort((T,f)=>f[1]-T[1]);d.length>0&&d[0][1]>=2&&l.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const h=e.filter(T=>T.isCompleted?!1:Ye(T.startDate)<a&&(T.progress===void 0||T.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=xn(o,i),r=xn(o,a);if(r>0&&p>0){const T=Math.round(r/p*100),f=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,y=Math.round(f/e.length*100),v=y-T;Math.abs(v)>=5?v>0?l.push(`Project is running ahead: ${y}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is running behind: only ${y}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${y}% complete at ${T}% of elapsed time.`)}const c=e.filter(T=>{if(T.isCompleted||T.progress!==void 0&&T.progress>0)return!1;const f=s.get(T.id);return!f||f.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let g=0,b="";for(const T of e){const f=n.get(T.id);f&&f.length>g&&(g=f.length,b=T.name)}return g>=3&&l.push(`"${b}" is a bottleneck with ${g} downstream tasks depending on it.`),l}function kc(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const g=Ye(c.endDate).getTime();i.set(c.id,g)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),g=i.get(c);for(const b of s.get(c)){const T=n.get(b.target),f=Ye(T.endDate).getTime()-Ye(T.startDate).getTime(),y=g+b.lag*Jt+f;y>i.get(b.target)&&i.set(b.target,y);const v=l.get(b.target)-1;l.set(b.target,v),v===0&&a.push(b.target)}}let u=-1/0,d="";for(const[c,g]of i)g>u&&(u=g,d=c);if(!d)return new Set;const h=new Set,p=new Map;for(const c of e)p.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||p.get(c.target).push({source:c.source,lag:c.lag||0}));let r=d;for(;r;){h.add(r);const c=p.get(r);if(!c||c.length===0)break;let g="",b=-1/0;for(const T of c){const f=i.get(T.source)||0;f>b&&(b=f,g=T.source)}if(!g||h.has(g))break;r=g}return h}const Cc=`
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
    transition: opacity ${Fo}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Bo}px;
    width: ${Bo}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${Fo}ms ease;
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
`;function Ic(){if(typeof document>"u"||document.getElementById(Hn))return;const e=document.createElement("style");e.id=Hn,e.textContent=Cc,document.head.appendChild(e)}function Mc(){if(typeof document>"u")return;const e=document.getElementById(Hn);e&&e.remove()}function Ac(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Lc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=wc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const g=document.createElement("span");g.textContent="📖",c.appendChild(g);const b=document.createElement("span");b.textContent="Project Story",c.appendChild(b),r.appendChild(c);const T=document.createElement("div");T.style.display="flex",T.style.alignItems="center",T.style.gap="4px";const f=document.createElement("button");f.className="ng-narrative-refresh",f.innerHTML="↻",f.title="Regenerate",f.addEventListener("click",()=>{l(),h()}),T.appendChild(f);const y=document.createElement("button");y.className="ng-narrative-close",y.innerHTML="×",y.addEventListener("click",d),T.appendChild(y),r.appendChild(T),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const k=document.createElement("div");k.className="ng-narrative-empty",k.textContent="No weekly chapters to display.",a.appendChild(k)}else for(const k of t.chapters){const w=document.createElement("div");w.className="ng-narrative-chapter";const E=Ac(k),D=document.createElement("div");D.className=`ng-narrative-chapter-header ng-${E}`;const I=document.createElement("div");I.className="ng-narrative-week-label",I.textContent=k.weekLabel,D.appendChild(I);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=k.headline,D.appendChild(M),w.appendChild(D);const R=document.createElement("div");if(R.className="ng-narrative-metrics",k.metrics.started>0&&R.appendChild(p("started",`${k.metrics.started} started`)),k.metrics.completed>0&&R.appendChild(p("completed",`${k.metrics.completed} done`)),k.metrics.delayed>0&&R.appendChild(p("delayed",`${k.metrics.delayed} delayed`)),k.metrics.onTrack>0&&R.appendChild(p("ontrack",`${k.metrics.onTrack} on track`)),R.children.length>0&&w.appendChild(R),k.body){const _=document.createElement("div");_.className="ng-narrative-body",_.textContent=k.body,w.appendChild(_)}a.appendChild(w)}if(t.insights.length>0){const k=document.createElement("div");k.className="ng-narrative-insights";const w=document.createElement("div");w.className="ng-narrative-insights-title",w.innerHTML="<span>💡</span> Key Insights",k.appendChild(w);for(const E of t.insights){const D=document.createElement("div");D.className="ng-narrative-insight";const I=document.createElement("span");I.className="ng-narrative-insight-icon",I.textContent="•",D.appendChild(I);const M=document.createElement("span");M.textContent=E,D.appendChild(M),k.appendChild(D)}a.appendChild(k)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const S=new Date(t.generatedAt);m.textContent=`Generated ${S.toLocaleString()}`,a.appendChild(m)}function p(r,c){const g=document.createElement("span");return g.className=`ng-narrative-badge ng-${r}`,g.textContent=c,g}return{name:"NarrativePlugin",install(r){e=r,Ic(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),Mc(),e=null,t=null,n=!1}}}const Rc=864e5,Pc=10,Bn="nimbus-gantt-whatif-styles",Xo=.25,$c=.6,Qt=6,zo="#38A169",Go="#E53E3E",Vo="#A0AEC0",Fn=36,_c="#F6AD55",Ko="#1a202c",Nc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Fn}px;
    background: ${_c};
    color: ${Ko};
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
    color: ${Ko};
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
    color: ${zo};
  }
  .ng-whatif-summary-value--worsened {
    color: ${Go};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${Vo};
  }
`;function Ue(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function jo(e){const t=Ue(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function en(e,t){return Math.round((t.getTime()-e.getTime())/Rc)}function qo(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function Oc(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function Hc(e){return{...e}}function xc(){if(typeof document>"u"||document.getElementById(Bn))return;const e=document.createElement("style");e.id=Bn,e.textContent=Nc,document.head.appendChild(e)}function Bc(){if(typeof document>"u")return;const e=document.getElementById(Bn);e&&e.remove()}function Fc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,Oc(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,Hc(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function Zo(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function Yc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,d=null,h=null,p=null,r=null,c=null,g=null;function b(){t||!e||(o=Fc(e.getState()),i=[],t=!0,n=!1,E())}function T(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],E(),M(),_())}function f(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,D(),M())}function y(C){if(!t||!e||!o)return;a.length>=Pc&&a.shift();const P=e.getState(),A=Zo(P.tasks),$=Ue(o.projectFinish),B=Ue(A),Q=en($,B);let Z=0;for(const[ge,me]of o.tasks){const F=P.tasks.get(ge);if(!F){Z++;continue}(F.startDate!==me.startDate||F.endDate!==me.endDate||F.assignee!==me.assignee)&&Z++}for(const ge of P.tasks.keys())o.tasks.has(ge)||Z++;const re={id:qo(),name:C,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:Q,tasksAffected:Z}};a.push(re),Y()}function v(C){if(!e||!o)return;const P=a.find(A=>A.id===C);if(P){t||b(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of P.changes)S(A);i=[...P.changes],D()}}function m(C){a=a.filter(P=>P.id!==C),Y()}function S(C){if(e)switch(C.type){case"move":case"resize":C.taskId&&C.after&&C.after.startDate&&C.after.endDate&&e.dispatch({type:C.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:C.taskId,startDate:C.after.startDate,endDate:C.after.endDate});break;case"add":C.after&&e.dispatch({type:"ADD_TASK",task:C.after});break;case"remove":C.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:C.taskId});break;case"reassign":C.taskId&&C.after&&e.dispatch({type:"UPDATE_TASK",taskId:C.taskId,changes:C.after});break;case"add-dependency":C.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:C.dependencyId||qo(),source:C.dependency.source,target:C.dependency.target,type:C.dependency.type||"FS"}});break;case"remove-dependency":C.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:C.dependencyId});break}}function k(){t&&(n=!n,n?I():M())}function w(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const C=e.getState(),P=Zo(C.tasks),A=Ue(o.projectFinish),$=Ue(P),B=en(A,$);let Q=0;for(const[Z,re]of o.tasks){const ge=C.tasks.get(Z);if(!ge){Q++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&Q++}for(const Z of C.tasks.keys())o.tasks.has(Z)||Q++;return{baselineFinish:o.projectFinish,sandboxFinish:P,deltaDays:B,tasksAffected:Q}}function E(){u&&u.classList.toggle("ng-hidden",!t)}function D(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function I(){if(!h)return;const C=w();let P="ng-whatif-summary-value--unchanged",A="No change";C.deltaDays<0?(P="ng-whatif-summary-value--improved",A=`${Math.abs(C.deltaDays)} day${Math.abs(C.deltaDays)!==1?"s":""} earlier`):C.deltaDays>0&&(P="ng-whatif-summary-value--worsened",A=`${C.deltaDays} day${C.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${jo(C.baselineFinish)} &rarr; ${jo(C.sandboxFinish)}
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
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function R(){s=!s,d&&d.classList.toggle("ng-open",s),s&&Y()}function _(){s=!1,d&&d.classList.remove("ng-open")}function x(){r&&(r.classList.add("ng-active"),c==null||c.focus())}function O(){r&&r.classList.remove("ng-active"),c&&(c.value="")}function N(){if(!c)return;const C=c.value.trim();C&&(y(C),O())}function Y(){if(g){if(a.length===0){g.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}g.innerHTML=a.map(C=>{var B;const P=new Date(C.createdAt).toLocaleDateString(),A=((B=C.result)==null?void 0:B.criticalPathDelta)??0;let $="No impact";return A<0?$=`${Math.abs(A)}d earlier`:A>0&&($=`${A}d later`),`
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
        `}).join("")}}function W(C){const P=document.createElement("div");return P.textContent=C,P.innerHTML}function K(C){const P=C.target,A=P.getAttribute("data-action"),$=P.getAttribute("data-id");if(!(!A||!$))switch(A){case"load":v($),_();break;case"compare":v($),n=!0,I(),_();break;case"delete":m($);break}}function q(C,P){switch(C.type){case"TASK_MOVE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"move",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"TASK_RESIZE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"resize",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:C.task.id,after:{...C.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:C.taskId,before:P.tasks.get(C.taskId)?{...P.tasks.get(C.taskId)}:void 0});break;case"UPDATE_TASK":{const A=P.tasks.get(C.taskId);A&&i.push({type:"reassign",taskId:C.taskId,before:{...A},after:C.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:C.dependency.id,dependency:{source:C.dependency.source,target:C.dependency.target,type:C.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:C.dependencyId});break}D()}function U(C,P,A,$,B,Q){const Z=Math.min(Q,$/2,B/2);C.beginPath(),C.moveTo(P+Z,A),C.lineTo(P+$-Z,A),C.arcTo(P+$,A,P+$,A+Z,Z),C.lineTo(P+$,A+B-Z),C.arcTo(P+$,A+B,P+$-Z,A+B,Z),C.lineTo(P+Z,A+B),C.arcTo(P,A+B,P,A+B-Z,Z),C.lineTo(P,A+Z),C.arcTo(P,A,P+Z,A,Z),C.closePath()}return{name:"WhatIfPlugin",install(C){e=C,xc(),l.push(C.on("whatif:enter",()=>b())),l.push(C.on("whatif:exit",()=>T())),l.push(C.on("whatif:compare",()=>k())),l.push(C.on("whatif:discard",()=>f())),l.push(C.on("whatif:save",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?y(A):x()})),l.push(C.on("whatif:load",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?v(A):R()})),l.push(C.on("whatif:list-scenarios",(...P)=>{const A=typeof P[0]=="function"?P[0]:void 0;A?A([...a]):R()})),l.push(C.on("whatif:delete-scenario",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A&&m(A)}))},middleware(C,P){if(!t){P(C);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(C.type)&&e){const $=e.getState();q(C,$)}P(C)},renderCanvas(C,P,A){if(!t||!e)return;const{theme:$,headerHeight:B,barHeight:Q}=P.config,Z=P.scrollX,re=P.scrollY,ge=B,me=e.getTimeScale(),F=$.barBorderRadius;if(C.save(),C.beginPath(),C.rect(0,ge,C.canvas.width,C.canvas.height-ge),C.clip(),C.translate(-Z,0),o){const ee=new Set;for(const j of A){const J=o.tasks.get(j.taskId),se=P.tasks.get(j.taskId);(!J&&se||J&&se&&(J.startDate!==se.startDate||J.endDate!==se.endDate||J.assignee!==se.assignee))&&ee.add(j.taskId)}for(const j of A){if(!ee.has(j.taskId))continue;const J=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>C.canvas.height||(C.save(),C.setLineDash([4,3]),C.strokeStyle="#F6AD55",C.lineWidth=2,U(C,J,se,de,ie,F),C.stroke(),C.restore())}}if(n&&o){const ee=Q*$c;for(const j of A){if(j.isMilestone)continue;const J=o.tasks.get(j.taskId);if(!J)continue;const se=P.tasks.get(j.taskId);if(!se)continue;const de=Ue(J.startDate),ie=Ue(J.endDate),fe=Ue(se.startDate),ce=Ue(se.endDate),Te=en(de,fe),ye=en(ie,ce);if(Te===0&&ye===0)continue;let X=Vo;ye<0?X=zo:ye>0&&(X=Go);const L=me.dateToX(de),H=me.dateToX(ie),z=Math.max(H-L,2),G=j.barY-re,V=G+Q+2;C.save(),C.globalAlpha=Xo,C.fillStyle=X,U(C,L,V,z,ee,F),C.fill(),C.globalAlpha=Xo*2,C.strokeStyle=X,C.lineWidth=1,C.stroke(),C.restore();const te=L+z/2,oe=V+ee/2,ae=j.x+j.width/2,le=G+Q/2;C.save(),C.globalAlpha=.6,C.strokeStyle=X,C.lineWidth=1.5,C.setLineDash([3,2]),C.beginPath(),C.moveTo(te,oe),C.lineTo(ae,le),C.stroke();const pe=Math.atan2(le-oe,ae-te),be=ae,Ce=le;C.setLineDash([]),C.beginPath(),C.moveTo(be,Ce),C.lineTo(be-Qt*Math.cos(pe-Math.PI/6),Ce-Qt*Math.sin(pe-Math.PI/6)),C.lineTo(be-Qt*Math.cos(pe+Math.PI/6),Ce-Qt*Math.sin(pe+Math.PI/6)),C.closePath(),C.fillStyle=X,C.fill(),C.restore()}}C.restore()},renderDOM(C,P){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const $=document.createElement("span");$.className="ng-whatif-badge",$.textContent="What-If Mode",A.appendChild($);const B=document.createElement("span");B.textContent="Changes are hypothetical",B.style.fontSize="12px",B.style.opacity="0.7",A.appendChild(B);const Q=document.createElement("span");Q.textContent="·",Q.style.opacity="0.4",A.appendChild(Q),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",A.appendChild(p),u.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",c=document.createElement("input"),c.type="text",c.placeholder="Scenario name...",c.addEventListener("keydown",se=>{se.key==="Enter"&&N(),se.key==="Escape"&&O()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",N);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>O()),r.appendChild(c),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const me=document.createElement("button");me.className="ng-whatif-btn",me.textContent="Scenarios",me.addEventListener("click",()=>R()),Z.appendChild(me);const F=document.createElement("button");F.className="ng-whatif-btn ng-whatif-btn--primary",F.textContent="Compare with Baseline",F.addEventListener("click",()=>k()),Z.appendChild(F);const ee=document.createElement("button");ee.className="ng-whatif-btn",ee.textContent="Save Scenario",ee.addEventListener("click",()=>x()),Z.appendChild(ee);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>f()),Z.appendChild(j);const J=document.createElement("button");J.className="ng-whatif-btn ng-whatif-btn--danger",J.textContent="Exit",J.addEventListener("click",()=>T()),Z.appendChild(J),u.appendChild(Z),C.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",C.appendChild(h)),!d){d=document.createElement("div"),d.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const $=document.createElement("span");$.textContent="Saved Scenarios",A.appendChild($);const B=document.createElement("button");B.className="ng-whatif-panel-close",B.textContent="×",B.addEventListener("click",()=>_()),A.appendChild(B),d.appendChild(A),g=document.createElement("div"),g.addEventListener("click",K),d.appendChild(g),C.appendChild(d),Y()}E(),n&&I()},destroy(){for(const C of l)C();l.length=0,u&&(u.remove(),u=null),d&&(d.remove(),d=null),h&&(h.remove(),h=null),p=null,r=null,c=null,g=null,Bc(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Yn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},Uc=261.63;function Wc(e){return Uc*Math.pow(2,e/12)}function Xc(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return Wc(n?a+12:a)}const Un="nimbus-gantt-sonification-styles",Wn=64,tn=64,Jo=.05,zc=.1,Gc=.7,Qo=.2,Xn="#F6AD55",Vc=2,Kc="rgba(246, 173, 85, 0.35)",ei=12,jc=`
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
`;function zn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function qc(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=jc,document.head.appendChild(e)}function Zc(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function Jc(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,d=null,h=null;const p=new Map;let r="stopped",c=0,g=0,b=0,T=0,f=0,y=0,v=0,m=null,S=null,k=null,w=null,E=null,D=null;const I=[];let M=[],R=[];function _(){if(l)return;const F=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;F&&(l=new F,u=l.createGain(),u.gain.value=i,d=l.createAnalyser(),d.fftSize=256,h=new Uint8Array(d.frequencyBinCount),u.connect(d),d.connect(l.destination))}function x(){l&&l.state==="suspended"&&l.resume()}function O(){if(!a)return;const F=a.getState(),ee=Date.now();let j=1/0,J=-1/0;const se=[],de=new Set,ie=F.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of F.tasks){const ye=zn(Te.startDate).getTime(),X=zn(Te.endDate).getTime();ye<j&&(j=ye),X>J&&(J=X);const L=Te.groupId||"__default__";de.add(L);const H=fe.get(ce)??0,z=!Te.isCompleted&&X<ee&&(Te.progress??0)<1;se.push({id:ce,startMs:ye,endMs:X,rowIndex:H,progress:Te.progress??0,groupId:L,isCritical:!1,isOverdue:z})}M=se,R=Array.from(de),f=j===1/0?0:j,y=J===-1/0?0:J,v=Math.max(y-f,1)}function N(F){if(!l||!u||p.has(F.id))return;const ee=Yn[n]||Yn.major,j=Xc(F.rowIndex,ee,F.isCritical),J=l.createOscillator();J.type=s,J.frequency.value=j,F.isOverdue&&(J.detune.value=25);const se=.3+F.progress*.7,de=F.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+Jo),fe.gain.linearRampToValueAtTime(ie*Gc,l.currentTime+Jo+zc);const ce=l.createStereoPanner();if(R.length<=1)ce.pan.value=0;else{const Te=R.indexOf(F.groupId);ce.pan.value=R.length>1?Te/(R.length-1)*2-1:0}J.connect(fe),fe.connect(ce),ce.connect(u),J.start(),p.set(F.id,{taskId:F.id,oscillator:J,gainNode:fe,panNode:ce})}function Y(F){const ee=p.get(F);if(!ee||!l)return;const j=l.currentTime;ee.gainNode.gain.cancelScheduledValues(j),ee.gainNode.gain.setValueAtTime(ee.gainNode.gain.value,j),ee.gainNode.gain.linearRampToValueAtTime(0,j+Qo),ee.oscillator.stop(j+Qo+.05),p.delete(F)}function W(){for(const F of Array.from(p.keys()))Y(F)}function K(){if(r!=="playing"||!l)return;const F=l.currentTime-c;if(g=Math.min(F/o,1),g>=1){C();return}const ee=f+g*v;for(const j of M){const J=ee>=j.startMs&&ee<j.endMs,se=p.has(j.id);J&&!se?N(j):!J&&se&&Y(j.id)}Z(),T=requestAnimationFrame(K)}function q(){_(),x(),l&&(O(),r==="paused"?c=l.currentTime-b*o:(c=l.currentTime,g=0),r="playing",$(),B(),T=requestAnimationFrame(K))}function U(){r==="playing"&&(r="paused",b=g,W(),cancelAnimationFrame(T),$())}function C(){r="stopped",g=0,b=0,W(),cancelAnimationFrame(T),$(),Q()}function P(){r==="playing"?U():q()}function A(F){const ee=zn(F).getTime(),j=Math.max(0,Math.min((ee-f)/v,1));r==="playing"&&l?c=l.currentTime-j*o:(b=j,g=j)}function $(){E&&(r==="playing"?(E.innerHTML=ge(),E.classList.add("ng-son-btn--active")):(E.innerHTML=re(),E.classList.remove("ng-son-btn--active")))}function B(){S&&S.classList.remove("ng-hidden")}function Q(){S&&S.classList.add("ng-hidden")}function Z(){if(!d||!h||!w||!k)return;d.getByteFrequencyData(h);const F=k.width,ee=k.height;w.clearRect(0,0,F,ee);const j=w.createLinearGradient(0,0,0,ee);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),w.fillStyle=j,w.fillRect(0,0,F,ee);const J=F/tn*.8,se=F/tn*.2,de=Math.floor(h.length/tn);for(let ie=0;ie<tn;ie++){let fe=0;for(let z=0;z<de;z++)fe+=h[ie*de+z]??0;const ce=fe/de,Te=ce/255*ee*.85,ye=ie*(J+se),X=ee-Te,L=30+ce/255*15,H=55+ce/255*15;w.fillStyle=`hsl(${L}, 90%, ${H}%)`,w.fillRect(ye,X,J,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function me(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(F){a=F,qc(),I.push(F.on("sonification:play",()=>q())),I.push(F.on("sonification:pause",()=>U())),I.push(F.on("sonification:stop",()=>C())),I.push(F.on("sonification:scrub",(...ee)=>{const j=typeof ee[0]=="string"?ee[0]:void 0;j&&A(j)})),I.push(F.on("sonification:configure",(...ee)=>{const j=ee[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(F,ee,j){if(r==="stopped"||!a)return;const{headerHeight:J}=ee.config,se=ee.scrollX,de=ee.scrollY,ie=J,fe=a.getTimeScale(),ce=f+g*v,Te=new Date(ce),ye=fe.dateToX(Te);F.save(),F.beginPath(),F.rect(0,ie,F.canvas.width,F.canvas.height-ie),F.clip(),F.translate(-se,0),F.save(),F.shadowColor=Xn,F.shadowBlur=ei,F.strokeStyle=Xn,F.lineWidth=Vc,F.beginPath(),F.moveTo(ye,ie),F.lineTo(ye,F.canvas.height+de),F.stroke(),F.restore();const X=new Map;for(const L of j)X.set(L.taskId,L);for(const L of p.values()){const H=X.get(L.taskId);if(!H)continue;const z=H.x,G=H.barY-de,V=H.width,te=H.barHeight;if(G+te<ie||G>F.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);F.save(),F.globalAlpha=ae,F.shadowColor=Kc,F.shadowBlur=ei,F.fillStyle=Xn;const le=Math.min(ee.config.theme.barBorderRadius,V/2,te/2);F.beginPath(),F.moveTo(z+le,G),F.lineTo(z+V-le,G),F.arcTo(z+V,G,z+V,G+le,le),F.lineTo(z+V,G+te-le),F.arcTo(z+V,G+te,z+V-le,G+te,le),F.lineTo(z+le,G+te),F.arcTo(z,G+te,z,G+te-le,le),F.lineTo(z,G+le),F.arcTo(z,G,z+le,G,le),F.closePath(),F.fill(),F.restore()}F.restore()},renderDOM(F,ee){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=re(),E.title="Play / Pause",E.addEventListener("click",()=>P()),m.appendChild(E),D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=me(),D.title="Stop",D.addEventListener("click",()=>C()),m.appendChild(D);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const J=document.createElement("div");J.style.display="flex",J.style.flexDirection="column",J.style.alignItems="center",J.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",J.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),J.appendChild(de),m.appendChild(J);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const H of Object.keys(Yn)){const z=document.createElement("option");z.value=H,z.textContent=H.charAt(0).toUpperCase()+H.slice(1),H===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const ye=document.createElement("div");ye.style.display="flex",ye.style.flexDirection="column",ye.style.alignItems="center",ye.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",ye.appendChild(X);const L=document.createElement("input");L.type="range",L.className="ng-son-slider",L.min="0",L.max="100",L.value=String(Math.round(i*100)),L.addEventListener("input",()=>{i=Number(L.value)/100,u&&(u.gain.value=i)}),ye.appendChild(L),m.appendChild(ye),F.appendChild(m)}if(!S){S=document.createElement("div"),S.className="ng-sonification-waveform ng-hidden",k=document.createElement("canvas"),w=k.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,J=F.getBoundingClientRect();k.width=J.width*j,k.height=Wn*j,k.style.width="100%",k.style.height=Wn+"px",w&&w.scale(j,j),S.appendChild(k),F.appendChild(S)}},destroy(){for(const F of I)F();I.length=0,C(),W(),l&&(l.close(),l=null),u=null,d=null,h=null,m&&(m.remove(),m=null),S&&(S.remove(),S=null),k=null,w=null,E=null,D=null,Zc(),a=null,M=[],R=[]}}}return ne.BaselinePlugin=Ta,ne.CLOUD_NIMBUS_PRIORITY_BUCKETS=ea,ne.ConfigPanelPlugin=dl,ne.CriticalPathPlugin=ra,ne.DARK_THEME=cs,ne.DarkThemePlugin=Pa,ne.DependencyRenderer=as,ne.EventBus=Kn,ne.ExportPlugin=ka,ne.GroupingPlugin=qi,ne.HeatmapViewPlugin=wl,ne.HitTest=os,ne.KeyboardPlugin=Pi,ne.LIGHT_THEME=rn,ne.LayoutEngine=Qn,ne.MSProjectPlugin=ja,ne.MilestonePlugin=Bi,ne.MiniMapPlugin=$l,ne.MonteCarloPlugin=vc,ne.MotionControlPlugin=Wa,ne.NarrativePlugin=Lc,ne.NetworkGraphPlugin=ol,ne.NimbusGantt=Ii,ne.PriorityGroupingPlugin=Qi,ne.ResourceLevelingPlugin=fr,ne.RiskAnalysisPlugin=Fr,ne.SonificationPlugin=Jc,ne.SplitTaskPlugin=ir,ne.TelemetryPlugin=Fa,ne.TimeScale=Zn,ne.TimeTravelPlugin=rc,ne.TimelineNotesPlugin=ql,ne.TooltipManager=ls,ne.UndoRedoPlugin=Li,ne.VirtualScrollPlugin=wa,ne.WhatIfPlugin=Yc,ne.WorkCalendarPlugin=Ha,ne.computeCPM=un,ne.exportMSProjectXML=vn,ne.getAllParentIds=gs,ne.getDescendantIds=hs,ne.hoursWeightedProgress=ta,ne.importMSProjectXML=bn,ne.parseDate=gt,ne.resolveConfig=ds,ne.rollupHoursDeduped=Mi,Object.defineProperty(ne,Symbol.toStringTag,{value:"Module"}),ne})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
