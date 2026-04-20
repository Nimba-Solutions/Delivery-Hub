var NimbusGantt=(function(ne){"use strict";function Oe(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let c=n.get(u);c||(c=[],n.set(u,c)),c.push(l)}const s=[];function o(l,u){const c=l.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return c!==h?c-h:l.name.localeCompare(u.name)}function i(l,u,c){const h=n.get(l);return h?(h.sort(o),h.map(p=>{const d=n.has(p.id)&&t.has(p.id),g=c,b={task:p,children:[],depth:u,expanded:d,visible:g,rowIndex:-1};return g&&(b.rowIndex=s.length,s.push(p.id)),b.children=i(p.id,u+1,g&&d),b})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function ut(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class Vn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=ti(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function ti(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Oe(n,e.expandedIds),a=ut(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Oe(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Oe(n,e.expandedIds),i=ut(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Oe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=ut(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}class Kn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const nn=864e5,ni=nn*7,si={day:40,week:120,month:180,quarter:200},jn=["January","February","March","April","May","June","July","August","September","October","November","December"],qn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class Zn{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=si[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/nn)}countWeeks(){return Math.ceil(this.totalMs/ni)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=Jn(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=sn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${jn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=Jn(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${qn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=sn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),c=this.dateToX(l);t.push({label:`${jn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:c-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:qn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=sn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=oi(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}}function Jn(e,t){return new Date(e.getTime()+t*nn)}function oi(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function sn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class Qn{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const c=gt(u.startDate),h=gt(u.endDate),p=s.dateToX(c),r=s.dateToX(h)-p,d=Math.max(r,o.minBarWidth),g=a*o.rowHeight,b=g+(o.rowHeight-o.barHeight)/2,y=d*(u.progress||0),f=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:g,width:d,barY:b,barHeight:o.barHeight,progressWidth:y,color:f,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function gt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const on=864e5,es=1,ii=2,ai=.5,ri=2,ts=8,li=6,ns=2;class ci{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:c}=u,h=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const d=u.headerHeight,g=a-d;this.fillRect(0,0,i,a,c.timelineBg),o.save(),o.beginPath(),o.rect(0,d,i,g),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,d,g,c),this.renderGridLines(s,d,g,c,h),this.renderAltRows(t,n,d,c,h,p);const b=this.getTodayX(t,u,s);u.showToday&&b!==null&&this.renderTodayBackground(b,s,d,g,c),this.renderGroupRowBgs(t,n,u,h,p,d,g),this.renderTaskBars(t,n,u,c,h,p,d,g),u.showToday&&b!==null&&this.renderTodayLine(b,d,g,c),o.restore(),this.renderHeader(s,u,c,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const c=l.getTime();for(;u.getTime()<=c;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+on),g=n.dateToX(r)-p;this.fillRect(p,s,g,o,i.timelineWeekendBg)}u.setTime(u.getTime()+on)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=ai;for(const u of l){const c=this.snapToPixel(u);a.moveTo(c,n),a.lineTo(c,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,c=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*c-a;if(r+c<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,c,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+on),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:u,displayWidth:c}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const d=p.y-i+a;d+h<a||d>a+l||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,d,c,h),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,d,c,2)),u.restore())}}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:c}=this,h=o.barBorderRadius;for(const p of n){const r=p.x,d=p.barY-a+l,g=p.width,b=p.barHeight;if(!(d+b<l||d>l+u)){if(p.isMilestone){this.renderMilestone(r,d,b,p.color,o,t.selectedIds.has(p.taskId));continue}if(this.fillRoundedRect(r,d,g,b,h,p.color),s.showProgress&&p.progressWidth>0){const y=this.darkenColor(p.color,.2);c.save(),c.beginPath(),this.roundedRectPath(r,d,g,b,h),c.clip(),c.fillStyle=y,c.fillRect(r,d,p.progressWidth,b),c.restore()}t.selectedIds.has(p.taskId)&&this.strokeRoundedRect(r,d,g,b,h,o.barSelectedBorder,ns),this.renderBarLabel(p,r,d,g,b,o)}}}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-ri*2)/2,c=n+s/2;l.save(),l.beginPath(),l.moveTo(t,c-u),l.lineTo(t+u,c),l.lineTo(t,c+u),l.lineTo(t-u,c),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=ns,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const c=l.measureText(t.label).width,h=s+i/2;c+ts*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+ts,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+li,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=ii,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const c=u.length||2,h=l/c,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let d=0;d<u.length;d++){const g=u[d],b=d*h;for(const y of g){const f=y.x-o,T=y.width;if(f+T<0||f>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=es;const v=this.snapToPixelRaw(f+T);i.moveTo(v,b),i.lineTo(v,b+h),i.stroke(),i.save(),i.beginPath(),i.rect(f,b,T,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(y.label,f+T/2,b+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=es,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const ss="ng-tree-grid-styles";function di(e,t){const n=e.querySelector(`#${ss}`);n&&n.remove();const s=document.createElement("style");s.id=ss,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function ui(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Ct(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class gi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;di(this.rootEl,a),this.columns=o,this.columnWidths=o.map(c=>c.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=ui(n),u=l.map(c=>c.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const c=document.createElement("span");c.className="ng-th-text",c.textContent=a.header,u.appendChild(c);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=c=>{const h=c.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,d=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),d[n]&&(d[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const c of t)l.set(c.task.id,c);for(const[c,h]of this.rows)a.has(c)||(h.remove(),this.rows.delete(c));let u=null;for(let c=0;c<t.length;c++){const h=t[c],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,c,s):(r=this.createRow(h,c,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const c=this.createCell(t,u,s);l.appendChild(c)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const c=document.createElement("span");c.className="ng-expand-icon",t.expanded&&c.classList.add("ng-expanded"),c.innerHTML="&#9654;",c.setAttribute("data-expand",t.task.id),o.appendChild(c)}else{const c=document.createElement("span");c.className="ng-expand-spacer",o.appendChild(c)}if(t.children.length===0&&!t.task.groupBg){const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",o.appendChild(c)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const c=document.createElement("span");c.className="ng-status-dot",c.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(c)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=Ct(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=Ct(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let c=0;c<a.length;c++){const h=a[c],p=l[c];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const d=`${n.depth*20+8}px`;p.style.paddingLeft!==d&&(p.style.paddingLeft=d);const g=p.querySelector(".ng-expand-icon"),b=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(g)n.expanded?g.classList.add("ng-expanded"):g.classList.remove("ng-expanded");else{b&&b.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(g){g.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const y=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!y){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const w=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");w?p.insertBefore(m,w):p.appendChild(m)}}else y&&y.remove();const f=p.querySelector(".ng-status-dot"),T=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(T&&n.children.length===0)if(f)f.style.background=T;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${T};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const w=p.querySelector(".ng-grid-cell-text");w?p.insertBefore(m,w):p.appendChild(m)}else f&&f.remove();const v=p.querySelector(".ng-grid-cell-text");if(v){const m=Ct(n.task,h);v.textContent!==m&&(v.textContent=m)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",p.appendChild(d)}}else r&&(p.textContent="")}else{const r=Ct(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class hi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class os{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const c=i+s.progressWidth;if(Math.abs(t-c)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const is=864e5;function an(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/is)}function ht(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function st(e,t){const n=ht(e),s=new Date(n.getTime()+t*is),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function fi(e,t,n){return Math.max(t,Math.min(n,e))}const pi=3,mi=300;class yi{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=t,this.options=n,this.hitTest=new os,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){try{const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}catch(n){try{const s=n&&n.stack?n.stack:String(n),o=n&&n.message?n.message:String(n);console.error("[NG] click_native threw msg=",o," stack=",s)}catch{}}}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){try{if(this.panning){t.preventDefault();const l=t.clientX-this.panStartClientX,u=t.clientY-this.panStartClientY,c=this.options.scrollManager;if(c){const h=Math.max(0,this.panOrigScrollX-l),p=Math.max(0,this.panOrigScrollY-u);c.setScrollPosition(h,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}catch(n){try{const s=n&&n.stack?n.stack:String(n),o=n&&n.message?n.message:String(n);console.error("[NG] pointermove threw msg=",o," stack=",s)}catch{}}}handlePointerDown(t){try{console.log("[NG] pointerdown enter x=",t.clientX,"y=",t.clientY,"btn=",t.button)}catch{}try{if(t.button!==0){try{console.log("[NG] pointerdown exit reason=non-primary-button")}catch{}return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);try{window.__NG_LAST_HITTEST={x:t.clientX,y:t.clientY,canvasX:n,canvasY:s,hit:a&&a.type!=="none"?{type:a.type,taskId:a.taskId}:null,ts:Date.now()}}catch{}if(!a||a.type==="none"){if(!this.options.scrollManager){try{console.log("[NG] pointerdown exit reason=no-bar-noop")}catch{}return}t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const u=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=u.x,this.panOrigScrollY=u.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";try{console.log("[NG] pointerdown exit reason=no-bar-pan")}catch{}return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(!l){try{console.log("[NG] pointerdown exit reason=task-lookup-failed taskId=",a.taskId)}catch{}return}if(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(t.pointerId),this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const u=Ti(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}try{console.log("[NG] pointerdown exit reason=bar-drag-start hitType=",a.type,"taskId=",a.taskId,"readOnly=",this.options.readOnly)}catch{}}catch(n){try{const s=n&&n.stack?n.stack:String(n),o=n&&n.message?n.message:String(n);console.error("[NG] pointerdown threw msg=",o," stack=",s)}catch{}try{console.log("[NG] pointerdown exit reason=threw")}catch{}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s})}handlePointerUp(t){try{console.log("[NG] pointerup enter x=",t.clientX,"y=",t.clientY,"dragging=",this.dragging,"panning=",this.panning)}catch{}try{if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<pi?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null}catch(n){try{const s=n&&n.stack?n.stack:String(n),o=n&&n.message?n.message:String(n);console.error("[NG] pointerup threw msg=",o," stack=",s)}catch{}}}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<mi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var l,u,c,h,p,r,d,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale();n.config;const i=this.dragHit.type,a=t.clientX-this.dragStartX;switch(i){case"bar":{const b=an(a,o),y=st(this.dragOriginalStartDate,b),f=st(this.dragOriginalEndDate,b);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:y,endDate:f});try{console.log("[NG engine] drag commit move",s.id,y,f,"hasCb=",!!this.options.onTaskMove)}catch{}(u=(l=this.options).onTaskMove)==null||u.call(l,s,y,f);break}case"bar-left-edge":{const b=an(a,o),y=st(this.dragOriginalStartDate,b),f=ht(this.dragOriginalEndDate),v=ht(y).getTime()>=f.getTime()?st(this.dragOriginalEndDate,-1):y;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:v,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,v,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(h=(c=this.options).onTaskResize)==null||h.call(c,s,v,this.dragOriginalEndDate);break}case"bar-right-edge":{const b=an(a,o),y=st(this.dragOriginalEndDate,b),f=ht(this.dragOriginalStartDate),v=ht(y).getTime()<=f.getTime()?st(this.dragOriginalStartDate,1):y;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:v});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,v,"hasCb=",!!this.options.onTaskResize)}catch{}(r=(p=this.options).onTaskResize)==null||r.call(p,s,this.dragOriginalStartDate,v);break}case"progress-handle":{const b=this.dragHit.layout,{canvasX:y}=this.toCanvasCoords(t),f=y-b.x,T=fi(f/b.width,0,1),v=Math.round(T*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:v}}),(g=(d=this.options).onTaskProgressChange)==null||g.call(d,s,v);break}}this.options.dispatch({type:"DRAG_END"})}}function Ti(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const ot=12,It=6,Mt=4,bi=3;class as{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const c=new Map;for(const r of s)c.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const d=c.get(r.source),g=c.get(r.target);if(!d||!g)continue;const b=r.type||"FS",{sourceX:y,sourceY:f,targetX:T,targetY:v}=this.getConnectionPoints(b,d,g,a,l);this.drawRoutedPath(t,b,y,f,T,v,o),this.drawArrowhead(t,b,T,v,o),this.drawConnectionDot(t,y,f,o),this.drawConnectionDot(t,T,v,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",c=n==="FS"||n==="SS",h=u?s+ot:s-ot,p=c?i-ot:i+ot;if(u?c?p>=h:i+ot>=h:c?i-ot<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const d=(o+a)/2;t.lineTo(h,o),t.lineTo(h,d),t.lineTo(p,d),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-It,o-Mt),t.lineTo(s-It,o+Mt)):(t.moveTo(s,o),t.lineTo(s+It,o-Mt),t.lineTo(s+It,o+Mt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,bi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const At=12,vi=100,Si=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],wi=`
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
`;function it(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function rs(e){const t=e.split("-");if(t.length!==3)return it(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?it(e):`${Si[n]} ${s}`}function ft(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${it(e)}</span><span class="ng-tooltip-value">${it(t)}</span></div>`}function Di(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=ft("Status",e.status||"None"),i+=ft("Assignee",e.assignee||"Unassigned"),i+=ft("Dates",`${rs(e.startDate)} → ${rs(e.endDate)}`),n>0&&(i+=ft("Progress",`${n}%`)),s!=null&&(i+=ft("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${it(t)}"><span class="ng-tooltip-name">${it(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class ls{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=wi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const c=this.customRenderer(t);typeof c=="string"?this.tooltipEl.innerHTML=c:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(c))}else this.tooltipEl.innerHTML=Di(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+At,u=s+At;l+i.width>a.width&&(l=n-At-i.width),u+i.height>a.height&&(u=s-At-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},vi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const rn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},cs={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Ei=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function ds(e){const t=ki(e.theme);return{columns:e.columns??Ei,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function ki(e){return!e||e==="light"?{...rn}:e==="dark"?{...cs}:{...rn,...e}}const us="nimbus-gantt-root-styles";function Ci(){if(typeof document>"u"||document.getElementById(us))return;const e=document.createElement("style");e.id=us,e.textContent=`
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
  `,document.head.appendChild(e)}class Ii{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.container=t,this.config=ds(n),Ci(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=Oe(s,i),u=ut(s),c={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new Kn,this.store=new Vn(c),this.layoutEngine=new Qn,this.timeScale=this.createTimeScale(c),this.canvasRenderer=new ci(this.timelinePanel),this.treeGrid=new gi(this.gridPanel),this.scrollManager=new hi(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new as,this.tooltipManager=new ls(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new yi(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,d,g)=>{var b;p?this.tooltipManager.show(p,r,d,g):this.tooltipManager.hide();try{(b=n.onHover)==null||b.call(n,p,r,d,g)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const c=u.getContext("2d");c&&l.renderCanvas(c,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new Zn(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const t=this.store.getState(),{tree:n,flatIds:s}=Oe(t.tasks,t.expandedIds);t.tree=n,t.flatVisibleIds.length=0;for(const o of s)t.flatVisibleIds.push(o)}}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new Vn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function gs(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function hs(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of gs(a)){let u=s.get(l);u||(u=[],s.set(l,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const u of l)o.has(u)||(o.add(u),i.push(u))}return o}function Mi(e,t){const n=hs(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const Ai=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ln(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Li(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function c(d){s.push(d),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const d=ln(n.getState()),g=s.pop();o.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const d=ln(n.getState()),g=o.pop();s.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function r(d){(d.ctrlKey||d.metaKey)&&(d.key==="z"||d.key==="Z")&&(d.shiftKey?(d.preventDefault(),p()):(d.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(d){n=d,u=d.on("render",()=>{if(l)return;const g=document.querySelector(".nimbus-gantt");g&&(l=g.parentElement??g,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(d,g){if(i){g(d);return}if(Ai.has(d.type)&&n){const b=ln(n.getState());c(b),o=[]}g(d)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const pt=["day","week","month","quarter"];function Ri(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function cn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Pi(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=Ri(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c>0&&e.dispatch({type:"SELECT_TASK",taskId:l[c-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[c+1]})}break}case"ArrowRight":{if(u)if(cn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}break}case"ArrowLeft":{if(u)if(cn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}break}case"Enter":{if(!u)return;i.preventDefault();const c=a.tasks.get(u);if(c&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:c,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const c=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:c})}break}case"+":case"=":{i.preventDefault();const c=pt.indexOf(a.zoomLevel);c>0&&e.dispatch({type:"SET_ZOOM",level:pt[c-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const c=pt.indexOf(a.zoomLevel);c<pt.length-1&&e.dispatch({type:"SET_ZOOM",level:pt[c+1]});break}case" ":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA"||c.tagName==="BUTTON")return;cn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const fs="#D4A017",_i="rgba(212, 160, 23, 0.25)",$i=[6,4],Ni=1,Oi=2,Hi=4,ps=8,ms=10,ys=16,xi=6;function Bi(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,c=s.filter(r=>r.isMilestone);if(c.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of c){const d=r.x,g=r.barY-a,b=r.barHeight,y=g+b/2,f=r.color===l.barDefaultColor?fs:r.color||fs;t.save(),t.beginPath(),t.strokeStyle=_i,t.lineWidth=Ni,t.setLineDash($i),t.moveTo(d,h),t.lineTo(d,h+p),t.stroke(),t.setLineDash([]),t.restore();const T=(b-Oi*2)/2;t.save(),t.beginPath(),t.moveTo(d,y-T),t.lineTo(d+T,y),t.lineTo(d,y+T),t.lineTo(d-T,y),t.closePath(),t.fillStyle=f,t.fill(),t.strokeStyle=Ts(f,.25),t.lineWidth=1,t.stroke(),t.restore();const v=d+T+Hi,m=y-ys/2;if(t.save(),t.beginPath(),t.strokeStyle=Ts(f,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+ys),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+ps,m+ms/2),t.lineTo(v,m+ms),t.closePath(),t.fillStyle=f,t.fill(),t.restore(),r.label){const w=v+ps+xi,k=y;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,w,k),t.restore()}}t.restore()},destroy(){e=null}}}function Ts(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Fi="rgba(100, 116, 139, 0.12)",Yi="rgba(100, 116, 139, 0.25)",bs="#334155",Ui="rgba(100, 116, 139, 0.2)",Wi="#475569",Xi=8,Gi=6,zi=2,Xe=5,Vi=12,Ki=28,ji=8;function qi(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(h){const p=new Map,r=[];for(const d of h.flatVisibleIds){const g=h.tasks.get(d);if(g)if(g.groupId){let b=p.get(g.groupId);b||(b={groupId:g.groupId,groupName:g.groupName||g.groupId,taskIds:[],collapsed:t.has(g.groupId)},p.set(g.groupId,b)),b.taskIds.push(d)}else r.push(d)}n=Array.from(p.values()),o=[],s=new Map;for(const d of r)o.push(d);for(const d of n){const g=o.length,b=`__group_header__${d.groupId}`;if(o.push(b),s.set(g,d),!d.collapsed)for(const y of d.taskIds)o.push(y)}}function c(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const d=e.getState(),g=p.querySelector(".ng-timeline-panel");if(!g)return;const b=g.getBoundingClientRect(),y=r.clientY-b.top,f=d.config.headerHeight;if(y<f)return;const T=y-f+d.scrollY,v=Math.floor(T/d.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),c(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let d=!1;for(const g of r.tasks.values())if(g.groupId){d=!0;break}if(!d){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const g=new Set;for(const b of n)if(b.collapsed)for(const y of b.taskIds)g.add(y);if(g.size>0){const b=r.flatVisibleIds.filter(y=>!g.has(y));if(b.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const y of b)r.flatVisibleIds.push(y)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:d,scrollX:g,scrollY:b}=p,{theme:y}=d,f=d.headerHeight,T=d.rowHeight,v=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-f;h.save(),h.beginPath(),h.rect(0,f,v,m),h.clip();let w=0;const k=[];for(const S of p.flatVisibleIds){const E=p.tasks.get(S);E&&!E.groupId&&k.push(S)}w=k.length;for(const S of n){const E=f+w*T-b;if(E+T>=f&&E<f+m){h.fillStyle=Fi,h.fillRect(0,E,v,T),h.beginPath(),h.strokeStyle=Yi,h.lineWidth=1,h.moveTo(0,Math.round(E+T)+.5),h.lineTo(v,Math.round(E+T)+.5),h.stroke();const D=Vi,I=E+T/2;h.save(),h.beginPath(),h.fillStyle=bs,S.collapsed?(h.moveTo(D,I-Xe),h.lineTo(D+Xe,I),h.lineTo(D,I+Xe)):(h.moveTo(D-Xe/2,I-Xe/2),h.lineTo(D+Xe/2,I-Xe/2),h.lineTo(D,I+Xe/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${y.fontSize}px ${y.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=bs;const M=Ki,R=E+T/2;h.fillText(S.groupName,M,R);const $=h.measureText(S.groupName).width;h.restore();const x=`${S.taskIds.length}`;h.save(),h.font=`${y.fontSize-1}px ${y.fontFamily}`;const N=h.measureText(x).width+Gi*2,Y=y.fontSize+zi*2,W=M+$+ji,K=R-Y/2;h.beginPath();const q=Xi;h.moveTo(W+q,K),h.lineTo(W+N-q,K),h.arcTo(W+N,K,W+N,K+q,q),h.lineTo(W+N,K+Y-q),h.arcTo(W+N,K+Y,W+N-q,K+Y,q),h.lineTo(W+q,K+Y),h.arcTo(W,K+Y,W,K+Y-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=Ui,h.fill(),h.fillStyle=Wi,h.textBaseline="middle",h.textAlign="center",h.fillText(x,W+N/2,R),h.restore()}w+=1,S.collapsed||(w+=S.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const at="__bucket_header__";function vs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Zi(e){return e.groupId??null}function Ji(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function Qi(e){const t=[...e.buckets].sort((r,d)=>r.order-d.order),n=new Map;t.forEach((r,d)=>n.set(r.id,d));const s=e.getBucket??Zi,o=e.getBucketProgress??Ji,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function c(r,d){l=t.map(g=>({config:g,taskIds:[],allTaskIds:[],collapsed:i.has(g.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const g of d){const b=r.tasks.get(g);if(!b)continue;const y=s(b);if(!y)continue;const f=n.get(y);f!==void 0&&l[f].taskIds.push(g)}for(const[g,b]of r.tasks){if(g.startsWith(at))continue;const y=s(b);if(!y)continue;const f=n.get(y);f!==void 0&&l[f].allTaskIds.push(g)}for(const g of l){if(g.allTaskIds.length===0){g.progress=0,g.startDate=null,g.endDate=null,g.totalHours=0,g.totalLogged=0;continue}const b=[];let y=1/0,f=-1/0,T=0,v=0;for(const m of g.allTaskIds){const w=r.tasks.get(m);if(!w)continue;if(b.push(w),w.startDate){const S=gt(w.startDate).getTime();!isNaN(S)&&S<y&&(y=S)}if(w.endDate){const S=gt(w.endDate).getTime();!isNaN(S)&&S>f&&(f=S)}const k=w.metadata;typeof(k==null?void 0:k.hoursHigh)=="number"&&(T+=k.hoursHigh),typeof(k==null?void 0:k.hoursLogged)=="number"&&(v+=k.hoursLogged)}g.startDate=isFinite(y)?new Date(y):null,g.endDate=isFinite(f)?new Date(f):null,g.totalHours=T,g.totalLogged=v,g.progress=Math.max(0,Math.min(1,o(b)))}}function h(r){if(!r.startDate||!r.endDate)return null;const d=r.totalHours>0&&r.totalLogged>=r.totalHours,g=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),b=r.totalHours>0?`${r.totalHours}h (${g}% budget)`:`${r.allTaskIds.length} items`;return{id:`${at}${r.config.id}`,name:b,startDate:vs(r.startDate),endDate:vs(r.endDate),progress:r.progress,color:d?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const d=a.getState();a.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...d)=>{const g=d[0];let b=null;typeof g=="string"?b=g:g&&typeof g=="object"&&"id"in g&&(b=String(g.id)),b&&b.startsWith(at)&&p(b.substring(at.length))}))},middleware(r,d){if(d(r),!a)return;const g=a.getState(),b=[];for(const T of g.tasks.keys())T.startsWith(at)&&b.push(T);for(const T of b)g.tasks.delete(T);const y=g.flatVisibleIds.filter(T=>!T.startsWith(at));let f=!1;for(const T of g.tasks.values())if(s(T)!=null){f=!0;break}if(!f){if(l=[],y.length!==g.flatVisibleIds.length){g.flatVisibleIds.length=0;for(const T of y)g.flatVisibleIds.push(T)}return}c(g,y);for(const T of l){if(T.allTaskIds.length===0)continue;const v=h(T);if(v){g.tasks.set(v.id,v);for(const m of T.allTaskIds){const w=g.tasks.get(m);w&&(w.parentId=v.id)}T.collapsed?g.expandedIds.delete(v.id):g.expandedIds.add(v.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const ea=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function ta(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Ss=864e5,na=6,sa=2,oa=2,ia=.18,aa=.4;function ws(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function dn(e,t){return Math.round((t.getTime()-e.getTime())/Ss)}function rt(e,t){return new Date(e.getTime()+t*Ss)}function un(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const D of n)s.set(D,[]),o.set(D,[]),i.set(D,0);for(const D of t.values()){if((D.type||"FS")!=="FS"||!e.has(D.source)||!e.has(D.target))continue;const M=D.lag||0;s.get(D.source).push({target:D.target,lag:M,depId:D.id}),o.get(D.target).push({source:D.source,lag:M,depId:D.id}),i.set(D.target,(i.get(D.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[D,I]of e){const M=ws(I.startDate),R=ws(I.endDate);l.set(D,M),u.set(D,R),a.set(D,Math.max(dn(M,R),0))}const c=new Map,h=new Map,p=[],r=[],d=new Map(i);for(const D of n)d.get(D)===0&&(r.push(D),c.set(D,l.get(D)),h.set(D,u.get(D)));for(;r.length>0;){const D=r.shift();p.push(D),c.get(D);const I=h.get(D);for(const M of s.get(D)){const{target:R,lag:$}=M,x=rt(I,$),O=c.get(R);(!O||x.getTime()>O.getTime())&&(c.set(R,x),h.set(R,rt(x,a.get(R))));const N=d.get(R)-1;d.set(R,N),N===0&&r.push(R)}}for(const D of n)c.has(D)||(c.set(D,l.get(D)),h.set(D,u.get(D)),p.push(D));let g=-1/0;for(const D of h.values())D.getTime()>g&&(g=D.getTime());const b=new Date(g);let y=1/0;for(const D of c.values())D.getTime()<y&&(y=D.getTime());const f=new Date(y),T=dn(f,b),v=new Map,m=new Map;for(const D of n)s.get(D).length===0&&(m.set(D,b),v.set(D,rt(b,-a.get(D))));for(let D=p.length-1;D>=0;D--){const I=p[D];if(!m.has(I)){let M=1/0;for(const R of s.get(I)){const $=v.get(R.target);if($){const x=rt($,-R.lag);x.getTime()<M&&(M=x.getTime())}}M===1/0?m.set(I,b):m.set(I,new Date(M)),v.set(I,rt(m.get(I),-a.get(I)))}}for(const D of n)m.has(D)||(m.set(D,b),v.set(D,rt(b,-a.get(D))));const w=.5,k=new Set,S=new Map;for(const D of n){const I=c.get(D),M=h.get(D),R=v.get(D),$=m.get(D),x=dn(I,R),O=Math.abs(x)<w;O&&k.add(D),S.set(D,{earlyStart:I,earlyFinish:M,lateStart:R,lateFinish:$,totalFloat:x,isCritical:O})}const E=new Set;for(const D of t.values())(D.type||"FS")==="FS"&&k.has(D.source)&&k.has(D.target)&&E.add(D.id);return{criticalTaskIds:k,criticalDependencyIds:E,taskAnalysis:S,projectDuration:T}}function ra(){let e,t=null,n=[];function s(){const o=e.getState();t=un(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:c,barHeight:h}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,d=i.scrollY,g=u,b=e.getTimeScale(),y=new Map;for(const m of a)y.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,g,o.canvas.width,o.canvas.height-g),o.clip(),o.translate(-r,0);for(const m of a){const w=t.taskAnalysis.get(m.taskId);if(!w||w.isCritical||w.totalFloat<=0)continue;const k=m.barY-d,S=h*aa,E=m.x+m.width,I=b.dateToX(w.lateFinish)-E;I>1&&(o.fillStyle=m.color,o.globalAlpha=ia,o.fillRect(E,k+h-S,I,S),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const w=m.x,k=m.barY-d,S=m.width,E=m.barHeight;if(!(k+E<g||k>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=na;for(let D=0;D<sa;D++){o.strokeStyle=p,o.lineWidth=oa,o.beginPath();const I=l.barBorderRadius,M=Math.min(I,S/2,E/2);o.moveTo(w+M,k),o.lineTo(w+S-M,k),o.arcTo(w+S,k,w+S,k+M,M),o.lineTo(w+S,k+E-M),o.arcTo(w+S,k+E,w+S-M,k+E,M),o.lineTo(w+M,k+E),o.arcTo(w,k+E,w,k+E-M,M),o.lineTo(w,k+M),o.arcTo(w,k,w+M,k,M),o.closePath(),o.stroke()}o.restore()}}const f=6,T=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const w=y.get(m.source),k=y.get(m.target);if(!w||!k)continue;const S=w.x+w.width,E=w.barY+w.barHeight/2-d,D=k.x,I=k.barY+k.barHeight/2-d;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=S+v,R=D-v;if(o.moveTo(S,E),R>=M)o.lineTo(M,E),o.lineTo(M,I),o.lineTo(D,I);else{const $=(E+I)/2;o.lineTo(M,E),o.lineTo(M,$),o.lineTo(R,$),o.lineTo(R,I),o.lineTo(D,I)}o.stroke(),o.beginPath(),o.moveTo(D,I),o.lineTo(D-f,I-T),o.lineTo(D-f,I+T),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const la=864e5,ca=.6,Ds=.25,da="#38A169",ua="#E53E3E",ga="#A0AEC0",ha=10,fa=4,Ge=16,pa=3;function Lt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ma(e,t){return Math.round((t.getTime()-e.getTime())/la)}function ya(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:Lt(s.startDate),end:Lt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var b,y;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,c=o.scrollX,h=o.scrollY,p=l,r=n.getTimeScale(),d=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-c,0);const g=u*ca;for(const f of i){if(f.isMilestone)continue;const T=t.get(f.taskId);if(!T)continue;const v=f.barY-h;if(v+u+g<p||v>s.canvas.height)continue;const m=r.dateToX(T.start),w=r.dateToX(T.end),k=Math.max(w-m,2),S=v+u+1;Lt(((b=o.tasks.get(f.taskId))==null?void 0:b.startDate)||"");const E=Lt(((y=o.tasks.get(f.taskId))==null?void 0:y.endDate)||""),D=ma(T.end,E);let I;D<0?I=da:D>0?I=ua:I=ga,s.save(),s.globalAlpha=Ds,s.fillStyle=I;const M=Math.min(d,k/2,g/2);if(s.beginPath(),s.moveTo(m+M,S),s.lineTo(m+k-M,S),s.arcTo(m+k,S,m+k,S+M,M),s.lineTo(m+k,S+g-M),s.arcTo(m+k,S+g,m+k-M,S+g,M),s.lineTo(m+M,S+g),s.arcTo(m,S+g,m,S+g-M,M),s.lineTo(m,S+M),s.arcTo(m,S,m+M,S,M),s.closePath(),s.fill(),s.globalAlpha=Ds*2,s.strokeStyle=I,s.lineWidth=1,s.stroke(),s.restore(),D!==0){const R=D>0?`+${D}d`:`${D}d`;s.save(),s.font=`600 ${ha}px ${a.fontFamily}`;const O=s.measureText(R).width+fa*2,N=f.x+f.width+4,Y=S+(g-Ge)/2;s.globalAlpha=.85,s.fillStyle=I;const W=pa;s.beginPath(),s.moveTo(N+W,Y),s.lineTo(N+O-W,Y),s.arcTo(N+O,Y,N+O,Y+W,W),s.lineTo(N+O,Y+Ge-W),s.arcTo(N+O,Y+Ge,N+O-W,Y+Ge,W),s.lineTo(N+W,Y+Ge),s.arcTo(N,Y+Ge,N,Y+Ge-W,W),s.lineTo(N,Y+W),s.arcTo(N,Y,N+W,Y,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(R,N+O/2,Y+Ge/2),s.restore()}}s.restore()},destroy(){}}}const Es=5,Ta=5,ba=.3,va=15;function Sa(){let e,t=null,n=0,s=0;const o=[];function i(c){const{rowHeight:h,headerHeight:p}=c.config,r=c.scrollY,d=c.flatVisibleIds.length,g=a(c),b=Math.floor(r/h),y=Math.ceil((r+g)/h);let f=Math.max(0,b-Es),T=Math.min(d,y+Es);if(Math.abs(s)>0){const m=Math.min(va,Math.ceil(Math.abs(s*ba)/h));s>0?T=Math.min(d,T+m):f=Math.max(0,f-m)}const v=new Set;for(let m=f;m<T&&m<c.flatVisibleIds.length;m++)v.add(c.flatVisibleIds[m]);return{startRow:f,endRow:T,totalRows:d,visibleTaskIds:v}}function a(c){const p=c.flatVisibleIds.length*c.config.rowHeight-c.scrollY;return Math.min(800,Math.max(p,200))}function l(c){const h=performance.now();for(o.push({y:c,time:h});o.length>Ta;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],d=(r.time-p.time)/1e3;d>0&&(s=(r.y-p.y)/d)}n=c}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const c=e.getState();return(!t||c.scrollY!==n)&&(l(c.scrollY),t=i(c)),t},filterLayouts(c){const h=u.getVisibleRange();return h.totalRows===0?[]:c.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(c){return u.getVisibleRange().visibleTaskIds.has(c)},getContentHeight(){if(!e)return 0;const c=e.getState();return c.flatVisibleIds.length*c.config.rowHeight+c.config.headerHeight}};return{name:"VirtualScrollPlugin",install(c){e=c},middleware(c,h){if(h(c),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(c.type)&&(t=null,c.type==="SET_SCROLL"||c.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const He=864e5,gn=1,ks=2,Cs=.5,Is=2,Rt=8,Ms=6,As=2,Pt=1e4;function hn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Ls(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Qe(e){return Math.round(e)+.5}function Rs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Ps(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let c=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(c,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const d=p.align==="right"?c+r-8:p.align==="center"?c+r/2:c+8;e.fillText(p.header,d,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(c+r,0),e.lineTo(c+r,s),e.stroke(),c+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const d=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,d,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,d+l),e.lineTo(n,d+l),e.stroke();let g=0;e.fillStyle=i.gridTextColor;for(const b of a){const y=b.width??120,f=Rs(r,b.field);e.save(),e.beginPath(),e.rect(g,d,y,l),e.clip(),e.textBaseline="middle";const T=b.tree?8:0;e.textAlign=b.align==="right"?"right":b.align==="center"?"center":"left";const v=b.align==="right"?g+y-8:b.align==="center"?g+y/2:g+8+T;e.fillText(f,v,d+l/2),e.restore(),g+=y}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function _s(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,c=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,c,p),i.showWeekends){const{start:g,end:b}=t.dateRange,y=new Date(g);y.setUTCHours(0,0,0,0);const f=b.getTime();for(;y.getTime()<=f;){const T=y.getUTCDay();if(T===0||T===6){const v=o+s.dateToX(y),m=new Date(y.getTime()+He),w=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,l,w-v,h)}y.setTime(y.getTime()+He)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Cs;for(const g of r){const b=Qe(o+g);e.moveTo(b,l),e.lineTo(b,p)}e.stroke();for(let g=0;g<t.flatVisibleIds.length;g++)g%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+g*u,c,u));if(i.showToday){const g=new Date;g.setHours(0,0,0,0);const{start:b,end:y}=t.dateRange;if(g.getTime()>=b.getTime()&&g.getTime()<=y.getTime()){const f=o+s.dateToX(g),T=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(f,l,T,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=ks,e.moveTo(Qe(f),l),e.lineTo(Qe(f),p),e.stroke()}}const d=a.barBorderRadius;for(const g of n){const b=o+g.x,y=g.barY,f=g.width,T=g.barHeight;if(g.isMilestone){const v=(T-Is*2)/2,m=y+T/2;e.beginPath(),e.moveTo(b,m-v),e.lineTo(b+v,m),e.lineTo(b,m+v),e.lineTo(b-v,m),e.closePath(),e.fillStyle=g.color,e.fill();continue}if(fn(e,b,y,f,T,d),e.fillStyle=g.color,e.fill(),i.showProgress&&g.progressWidth>0){const v=Ls(g.color,.2);e.save(),e.beginPath(),fn(e,b,y,f,T,d),e.clip(),e.fillStyle=v,e.fillRect(b,y,g.progressWidth,T),e.restore()}if(t.selectedIds.has(g.taskId)&&(e.beginPath(),fn(e,b,y,f,T,d),e.strokeStyle=a.barSelectedBorder,e.lineWidth=As,e.stroke()),g.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(g.label).width,m=y+T/2;v+Rt*2<=f?(e.beginPath(),e.rect(b,y,f,T),e.clip(),e.fillStyle=g.textColor,e.textAlign="left",e.fillText(g.label,b+Rt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(g.label,b+f+Ms,m)),e.restore()}}wa(e,t,n,a,o),Da(e,s,i,a,o)}function wa(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const c of n)i.set(c.taskId,c);const a=12,l=6,u=4;e.save();for(const c of t.dependencies.values()){const h=i.get(c.source),p=i.get(c.target);if(!h||!p)continue;const r=c.type||"FS",d=h.barY+h.barHeight/2,g=p.barY+p.barHeight/2;let b,y;const f=r==="FS"||r==="FF",T=r==="FS"||r==="SS";switch(r){case"FS":b=o+h.x+h.width,y=o+p.x;break;case"SS":b=o+h.x,y=o+p.x;break;case"FF":b=o+h.x+h.width,y=o+p.x+p.width;break;case"SF":b=o+h.x,y=o+p.x+p.width;break}const v=f?b+a:b-a,m=T?y-a:y+a,w=f?T?m>=v:y+a>=v:T?y-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(b,d),w)e.lineTo(v,d),e.lineTo(v,g),e.lineTo(y,g);else{const k=(d+g)/2;e.lineTo(v,d),e.lineTo(v,k),e.lineTo(m,k),e.lineTo(m,g),e.lineTo(y,g)}e.stroke(),e.beginPath(),T?(e.moveTo(y,g),e.lineTo(y-l,g-u),e.lineTo(y-l,g+u)):(e.moveTo(y,g),e.lineTo(y+l,g-u),e.lineTo(y+l,g+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function Da(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let c=0;c<a.length;c++){const h=a[c],p=c*u;for(const r of h){const d=o+r.x,g=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=gn,e.moveTo(Qe(d+g),p),e.lineTo(Qe(d+g),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(d,p,g,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,d+g/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=gn,e.moveTo(o,Qe(i)),e.lineTo(o+t.getTotalWidth(),Qe(i)),e.stroke()}function fn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function mt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Ea(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),c=s+u,h=e.flatVisibleIds.length*l,p=a+h,r=i.barBorderRadius,d=[];d.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${c}" height="${p}" viewBox="0 0 ${c} ${p}">`),d.push(`<style>text { font-family: ${mt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),d.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),d.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let g=0;for(const m of o.columns){const w=m.width??120;d.push(`<text x="${g+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${mt(m.header)}</text>`),d.push(`<line x1="${g+w}" y1="0" x2="${g+w}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),g+=w}for(let m=0;m<e.flatVisibleIds.length;m++){const w=e.tasks.get(e.flatVisibleIds[m]);if(!w)continue;const k=a+m*l;m%2===1&&d.push(`<rect x="0" y="${k}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let S=0;for(const E of o.columns){const D=E.width??120,I=Rs(w,E.field),M=E.tree?8:0;d.push(`<text x="${S+8+M}" y="${k+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${I}]]></text>`),S+=D}d.push(`<line x1="0" y1="${k+l}" x2="${s}" y2="${k+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}d.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<line x1="0" y1="${a}" x2="${c}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const b=n.getHeaderRows(),y=b.length||2,f=a/y;for(let m=0;m<b.length;m++){const w=b[m],k=m*f;for(const S of w){const E=s+S.x+S.width/2,D=k+f/2,I=m===0?' font-weight="600"':"";d.push(`<text x="${E}" y="${D}" text-anchor="middle" dominant-baseline="central"${I} fill="${i.timelineHeaderText}">${mt(S.label)}</text>`),d.push(`<line x1="${s+S.x+S.width}" y1="${k}" x2="${s+S.x+S.width}" y2="${k+f}" stroke="${i.timelineGridColor}" stroke-width="${gn}" />`)}}const T=n.getGridLines();for(const m of T)d.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Cs}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&d.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:w}=e.dateRange,k=new Date(m);for(k.setUTCHours(0,0,0,0);k.getTime()<=w.getTime();){if(k.getUTCDay()===0||k.getUTCDay()===6){const S=s+n.dateToX(k),E=new Date(k.getTime()+He),D=s+n.dateToX(E);d.push(`<rect x="${S}" y="${a}" width="${D-S}" height="${h}" fill="${i.timelineWeekendBg}" />`)}k.setTime(k.getTime()+He)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:w,end:k}=e.dateRange;if(m.getTime()>=w.getTime()&&m.getTime()<=k.getTime()){const S=s+n.dateToX(m),E=n.getColumnWidth();d.push(`<rect x="${S}" y="${a}" width="${E}" height="${h}" fill="${i.todayBg}" />`),d.push(`<line x1="${S}" y1="${a}" x2="${S}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${ks}" />`)}}for(const m of t){const w=s+m.x,k=m.barY,S=m.width,E=m.barHeight;if(m.isMilestone){const D=(E-Is*2)/2,I=k+E/2;d.push(`<polygon points="${w},${I-D} ${w+D},${I} ${w},${I+D} ${w-D},${I}" fill="${m.color}" />`);continue}if(d.push(`<rect x="${w}" y="${k}" width="${S}" height="${E}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const D=Ls(m.color,.2);d.push(`<clipPath id="clip-${m.taskId}"><rect x="${w}" y="${k}" width="${S}" height="${E}" rx="${r}" ry="${r}" /></clipPath>`),d.push(`<rect x="${w}" y="${k}" width="${m.progressWidth}" height="${E}" fill="${D}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&d.push(`<rect x="${w}" y="${k}" width="${S}" height="${E}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${As}" />`),m.label){const D=k+E/2;i.fontSize*.6*m.label.length+Rt*2<=S?d.push(`<text x="${w+Rt}" y="${D}" dominant-baseline="central" fill="${m.textColor}">${mt(m.label)}</text>`):d.push(`<text x="${w+S+Ms}" y="${D}" dominant-baseline="central" fill="${i.gridTextColor}">${mt(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const w=v.get(m.source),k=v.get(m.target);if(!w||!k)continue;const S=m.type||"FS",E=w.barY+w.barHeight/2,D=k.barY+k.barHeight/2;let I,M;const R=S==="FS"||S==="FF",$=S==="FS"||S==="SS";switch(S){case"FS":I=s+w.x+w.width,M=s+k.x;break;case"SS":I=s+w.x,M=s+k.x;break;case"FF":I=s+w.x+w.width,M=s+k.x+k.width;break;case"SF":I=s+w.x,M=s+k.x+k.width;break}const x=12,O=6,N=4,Y=R?I+x:I-x,W=$?M-x:M+x,K=R?$?W>=Y:M+x>=Y:$?M-x<=Y:W<=Y;let q;if(K)q=`M${I},${E} L${Y},${E} L${Y},${D} L${M},${D}`;else{const U=(E+D)/2;q=`M${I},${E} L${Y},${E} L${Y},${U} L${W},${U} L${W},${D} L${M},${D}`}d.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),$?d.push(`<polygon points="${M},${D} ${M-O},${D-N} ${M-O},${D+N}" fill="${i.dependencyColor}" />`):d.push(`<polygon points="${M},${D} ${M+O},${D-N} ${M+O},${D+N}" fill="${i.dependencyColor}" />`)}return d.push("</svg>"),d.join(`
`)}function ka(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:c,end:h}=l.dateRange,p=h.getTime()-c.getTime(),r=u.getColumnWidth(),d=l.zoomLevel;let g;switch(d){case"day":g=Math.round(p/He);break;case"week":g=Math.ceil(p/(He*7));break;case"month":{const y=c.getUTCFullYear(),f=c.getUTCMonth(),T=h.getUTCFullYear(),v=h.getUTCMonth();g=(T-y)*12+(v-f);break}case"quarter":{const y=c.getUTCFullYear(),f=Math.floor(c.getUTCMonth()/3),T=h.getUTCFullYear(),v=Math.floor(h.getUTCMonth()/3);g=(T-y)*4+(v-f);break}}const b=g*r;return{dateToX(y){return(y.getTime()-c.getTime())/p*b},getColumnWidth(){return r},getTotalWidth(){return b},getHeaderRows(){return Ma(d,c,h,r,b)},getGridLines(){return this.getHeaderRows()[1].map(f=>f.x).filter(f=>f>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,d=l.flatVisibleIds.length*l.config.rowHeight,g=l.config.headerHeight+d,b=a??"gantt-export.png";if(r>Pt||g>Pt){o(l,c,u,h,r,g,b);return}const y=document.createElement("canvas");y.width=r,y.height=g;const f=y.getContext("2d");f&&(h>0&&Ps(f,l,h,g),_s(f,l,c,u,h),y.toBlob(T=>{T&&hn(T,b)},"image/png"))}function o(a,l,u,c,h,p,r){const d=Math.min(1,Pt/h,Pt/p),g=Math.ceil(h*d),b=Math.ceil(p*d),y=document.createElement("canvas");y.width=g,y.height=b;const f=y.getContext("2d");f&&(f.scale(d,d),c>0&&Ps(f,a,c,p),_s(f,a,l,u,c),y.toBlob(T=>{T&&hn(T,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=Ea(l,c,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});hn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const $s=["January","February","March","April","May","June","July","August","September","October","November","December"],Ns=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Os(e,t){return new Date(e.getTime()+t*He)}function pn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Ca(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ia(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function Ma(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Ia(l,t,i,o);switch(e){case"day":{const l=[],u=[],c=Math.round(i/He);let h=new Date(t);for(let r=0;r<c;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Os(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=pn(p),d=a(p),g=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${$s[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:d,width:g-d,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],c=Math.ceil(i/(He*7));for(let p=0;p<c;p++){const r=Os(t,p*7);u.push({label:`${Ns[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=pn(h),r=h.getTime()<t.getTime()?t:h,d=p.getTime()>n.getTime()?n:p;l.push({label:`${$s[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(d)-a(r),date:new Date(r)}),h=p}return[l,u]}case"month":{const l=[],u=[],c=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),d=(p-c)*12+(r-h);let g=new Date(Date.UTC(c,h,1));for(let y=0;y<d;y++)u.push({label:Ns[g.getUTCMonth()],x:y*s,width:s,date:new Date(g)}),g=pn(g);let b=new Date(Date.UTC(c,0,1));for(;b.getTime()<n.getTime();){const y=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,T=y.getTime()>n.getTime()?n:y;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(T)-a(f),date:new Date(f)}),b=y}return[l,u]}case"quarter":{const l=[],u=[],c=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),d=(p-c)*4+(r-h);let g=new Date(Date.UTC(c,h*3,1));for(let y=0;y<d;y++){const f=Math.floor(g.getUTCMonth()/3)+1;u.push({label:`Q${f}`,x:y*s,width:s,date:new Date(g)}),g=Ca(g,3)}let b=new Date(Date.UTC(c,0,1));for(;b.getTime()<n.getTime();){const y=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,T=y.getTime()>n.getTime()?n:y;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(T)-a(f),date:new Date(f)}),b=y}return[l,u]}default:return[[],[]]}}const Aa={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},mn="nimbus-gantt-dark-theme-transition";function La(){if(typeof document>"u"||document.getElementById(mn))return;const e=document.createElement("style");e.id=mn,e.textContent=`
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
  `,document.head.appendChild(e)}function Ra(){if(typeof document>"u")return;const e=document.getElementById(mn);e&&e.remove()}function Pa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const d=n.getState();o={...d.config.theme};const g={...d.config.theme,...Aa};Object.assign(d.config.theme,g),s=!0,p()}function c(){if(!n||!s||!o)return;const d=n.getState();Object.assign(d.config.theme,o),s=!1,p()}function h(){s?c():u()}function p(){if(!n)return;const d=n.getState();n.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}function r(d){d.matches?u():c()}return{name:"DarkThemePlugin",install(d){n=d,La(),d.on("theme:toggle",()=>{h()}),d.on("theme:dark",()=>{u()}),d.on("theme:light",()=>{c()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=d.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const d=n.getState();Object.assign(d.config.theme,o)}Ra(),n=null,o=null,i=null,a=null,s=!1}}}const Ae=864e5,_a=[1,2,3,4,5],$a="rgba(128, 128, 128, 0.06)",Na="rgba(128, 128, 128, 0.04)",Oa="#f87171",yt=4;function Tt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function _e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ha(e){const t=new Set((e==null?void 0:e.workDays)??_a),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const d=_e(r);return t.has(d.getUTCDay())}function i(r){const d=Tt(r);return n.has(d)?!1:t.has(r.getUTCDay())}function a(r){let d=_e(r);for(d=new Date(d.getTime()+Ae);!i(d);)d=new Date(d.getTime()+Ae);return Tt(d)}function l(r,d){if(d===0)return r;let g=_e(r);const b=d>0?1:-1;let y=Math.abs(d);if(!i(g))for(g=new Date(g.getTime()+b*Ae);!i(g);)g=new Date(g.getTime()+b*Ae);for(;y>0;)g=new Date(g.getTime()+b*Ae),i(g)&&y--;return Tt(g)}function u(r,d){const g=_e(r),b=_e(d);if(g.getTime()>b.getTime())return-u(d,r);let y=0,f=new Date(g.getTime());for(;f.getTime()<b.getTime();)i(f)&&y++,f=new Date(f.getTime()+Ae);return y}function c(r,d="forward"){if(o(r))return r;let g=_e(r);const b=d==="forward"?Ae:-Ae;for(let y=0;y<30;y++)if(g=new Date(g.getTime()+b),i(g))return Tt(g);return r}function h(r,d){if(r.type==="TASK_MOVE"){const g=c(r.startDate,"forward"),b=c(r.endDate,"backward"),y=_e(b).getTime()<_e(g).getTime()?g:b;d({...r,startDate:g,endDate:y});return}if(r.type==="TASK_RESIZE"){const g=c(r.startDate,"forward"),b=c(r.endDate,"backward"),y=_e(b).getTime()<_e(g).getTime()?g:b;d({...r,startDate:g,endDate:y});return}d(r)}function p(r,d,g){const{config:b}=d,y=b.headerHeight,f=d.flatVisibleIds.length*b.rowHeight,T=s==null?void 0:s.getTimeScale();if(!T||f===0)return;const{start:v,end:m}=d.dateRange,w=d.scrollX,k=d.scrollY;r.save();const S=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(S,0,0,S,0,0),r.beginPath(),r.rect(0,y,r.canvas.width/S,f),r.clip(),r.translate(-w,0);const E=new Date(v);E.setUTCHours(0,0,0,0);const D=m.getTime();for(T.getColumnWidth();E.getTime()<=D;){const I=Tt(E),M=n.has(I),R=!t.has(E.getUTCDay());if(M||R){const $=T.dateToX(E),x=new Date(E.getTime()+Ae),N=T.dateToX(x)-$;if(r.fillStyle=$a,r.fillRect($,y-k,N,f+k),R&&!M){r.save(),r.beginPath(),r.rect($,y,N,f),r.clip(),r.strokeStyle=Na,r.lineWidth=1;const Y=8,W=f;for(let K=-W;K<N+W;K+=Y)r.beginPath(),r.moveTo($+K,y),r.lineTo($+K+W,y+W),r.stroke();r.restore()}}if(M){const $=T.dateToX(E),x=new Date(E.getTime()+Ae),O=T.dateToX(x),N=($+O)/2;r.save(),r.setTransform(S,0,0,S,0,0),r.translate(-w,0);const Y=y-yt-3;r.beginPath(),r.moveTo(N,Y-yt),r.lineTo(N+yt,Y),r.lineTo(N,Y+yt),r.lineTo(N-yt,Y),r.closePath(),r.fillStyle=Oa,r.fill(),r.restore()}E.setTime(E.getTime()+Ae)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...d)=>{const g=d[0],b=d[1],y=d[2],f=l(g,b);y&&y(f)}),r.on("calendar:workDaysBetween",(...d)=>{const g=d[0],b=d[1],y=d[2],f=u(g,b);y&&y(f)}),r.on("calendar:isWorkDay",(...d)=>{const g=d[0],b=d[1],y=o(g);b&&b(y)}),r.on("calendar:nextWorkDay",(...d)=>{const g=d[0],b=d[1],y=a(g);b&&b(y)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function xa(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Ba(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function Fa(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=xa(),a=[],l=Date.now();let u=null,c=null,h=!1,p=[];const r=[];function d(m,w){if(h)return;const k={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:w};a.push(k),o&&o(k)}function g(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function b(){c===null&&(c=setInterval(()=>{g()},s))}function y(){c!==null&&(clearInterval(c),c=null)}const f=Ba(()=>{if(!u)return;const m=u.getState();d("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let T=0;function v(m,w){switch(m.type){case"SET_ZOOM":{const k=u?u.getState().zoomLevel:"unknown";w(m),d("gantt.zoom",{oldLevel:k,newLevel:m.level});return}case"TASK_MOVE":{const k=T>0?Date.now()-T:0;w(m),d("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:k}),T=0;return}case"TASK_RESIZE":{w(m),d("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{T=Date.now(),w(m);return}case"SELECT_TASK":{w(m),d("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{w(m),f();return}case"TOGGLE_EXPAND":{const k=u?u.getState().expandedIds.has(m.taskId):!1;w(m),d(k?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{w(m),d("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{w(m),d("gantt.collapse",{all:!0});return}default:w(m);return}}return{name:"TelemetryPlugin",install(m){u=m,b();const w=m.getState();d("gantt.init",{taskCount:w.tasks.size,dependencyCount:w.dependencies.size,zoomLevel:w.zoomLevel}),setTimeout(()=>{h||d("gantt.feature.used",{plugins:p})},0);const k=m.on("taskClick",(...S)=>{const E=S[0];E&&d("gantt.task.click",{taskId:E.id})});r.push(k)},middleware:v,destroy(){h=!0;const m=Date.now()-l;d("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),g(),y();for(const w of r)w();r.length=0,u=null}}}const Hs=5,yn=.15,Tn=.85,Ya=2,xs=30,xe=["day","week","month","quarter"];function Bs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function Ua(e,t,n){return Math.max(t,Math.min(n,e))}function Wa(e){const t=Ua((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,c=0,h=0,p=0,r=null,d=null,g=null,b=null,y=null,f=null,T=0,v=0,m=0,w=!1;function k(O,N,Y){m=O,T=N,v=Y,w=!0,r===null&&(r=O)}function S(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(b=O=>{u||O.alpha==null||O.beta==null||O.gamma==null||k(O.alpha,O.beta,O.gamma)},window.addEventListener("deviceorientation",b),!0)}function E(){b&&(window.removeEventListener("deviceorientation",b),b=null)}function D(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function I(O){try{const N=JSON.parse(O);N.type==="orientation"?k(N.alpha,N.beta,N.gamma):N.type==="gesture"&&M(N.gesture)}catch{}}function M(O){if(!l)return;const N=l.getState();switch(O){case"tap":{N.selectedIds.size===0&&N.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:N.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const Y=xe.indexOf(N.zoomLevel);Y<xe.length-1&&l.dispatch({type:"SET_ZOOM",level:xe[Y+1]});break}case"swipe-right":{const Y=xe.indexOf(N.zoomLevel);Y>0&&l.dispatch({type:"SET_ZOOM",level:xe[Y-1]});break}}}function R(){if(u||typeof WebSocket>"u")return;const O=D();try{y=new WebSocket(O),y.onmessage=N=>{typeof N.data=="string"&&I(N.data)},y.onclose=()=>{y=null,u||(f=setTimeout(R,3e3))},y.onerror=()=>{y&&y.close()}}catch{u||(f=setTimeout(R,3e3))}}function $(){f!==null&&(clearTimeout(f),f=null),y&&(y.onmessage=null,y.onclose=null,y.onerror=null,y.close(),y=null)}function x(){if(!(u||!l)){if(w){c=c*Tn+T*yn,h=h*Tn+v*yn,p=p*Tn+m*yn;const O=l.getState(),N=Ya*a;if(n){const Y=Bs(h,Hs);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const Y=Bs(c,Hs);if(Y!==0){const W=Y*N,K=Math.max(0,O.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=xe.indexOf(O.zoomLevel);if(W>xs&&K>0){const q=xe[K-1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}else if(W<-xs&&K<xe.length-1){const q=xe[K+1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}}}g=requestAnimationFrame(x)}}return{name:"MotionControlPlugin",install(O){l=O,d=O.getState().zoomLevel,(!S()||i)&&R(),g=requestAnimationFrame(x)},destroy(){u=!0,g!==null&&(cancelAnimationFrame(g),g=null),E(),$(),l=null}}}const bt="http://schemas.microsoft.com/project",Xa=8,Fs=4800,Ga={0:"FF",1:"FS",2:"SF",3:"SS"},za={FF:0,FS:1,SF:2,SS:3};function Ys(e){return e?e.substring(0,10):""}function Us(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function De(e,t){var s;let n=e.getElementsByTagNameNS(bt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function Va(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function Ka(e){return`PT${e*Xa}H0M0S`}function vt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function bn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(bt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let f=0;f<l.length;f++){const T=l[f],v=De(T,"UID"),m=De(T,"Name");v&&m&&i.set(v,m)}const u=new Map,c=o.getElementsByTagNameNS(bt,"Assignment"),h=c.length>0?c:o.getElementsByTagName("Assignment");for(let f=0;f<h.length;f++){const T=h[f],v=De(T,"TaskUID"),m=De(T,"ResourceUID");if(v&&m){const w=i.get(m);w&&u.set(v,w)}}const p=[],r=[],d=o.getElementsByTagNameNS(bt,"Task"),g=d.length>0?d:o.getElementsByTagName("Task"),b=[];let y=1;for(let f=0;f<g.length;f++){const T=g[f],v=De(T,"UID"),m=De(T,"Name"),w=De(T,"Start"),k=De(T,"Finish"),S=De(T,"PercentComplete"),E=De(T,"Summary")==="1",D=De(T,"Milestone")==="1",I=parseInt(De(T,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const M=`msp-${v}`,R=Ys(w),$=Ys(k);if(!R&&!D)continue;let x;I>0&&b[I-1]&&(x=b[I-1]),b[I]=M,b.length=I+1;const O={id:M,name:m||`Task ${v}`,startDate:R||$,endDate:$||R,progress:S?parseInt(S,10)/100:0,isMilestone:D,parentId:x,sortOrder:f},N=u.get(v);N&&(O.assignee=N),E&&(O.metadata={...O.metadata,isSummary:!0}),p.push(O);const Y=T.getElementsByTagNameNS(bt,"PredecessorLink"),W=Y.length>0?Y:T.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],U=De(q,"PredecessorUID"),C=parseInt(De(q,"Type")||"1",10),P=De(q,"LinkLag"),A=P?parseInt(P,10):0;if(!U||U==="0")continue;const _={id:`msp-dep-${y++}`,source:`msp-${U}`,target:M,type:Ga[C]??"FS",lag:A!==0?A/Fs:void 0};r.push(_)}}return{tasks:p,dependencies:r}}function vn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(v){let m=1,w=v;for(;w!=null&&w.parentId;)m++,w=e.tasks.get(w.parentId);return m}const c=new Map,h=new Map;for(const v of a){const m=v.parentId??"__root__",w=(c.get(m)??0)+1;if(c.set(m,w),!v.parentId)h.set(v.id,String(w));else{const k=h.get(v.parentId)??"0";h.set(v.id,`${k}.${w}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const d=new Map;for(const v of l){const m=d.get(v.target)??[];m.push(v),d.set(v.target,m)}const g=new Set;for(const v of a)v.assignee&&g.add(v.assignee);const b=Array.from(g),y=new Map;b.forEach((v,m)=>{y.set(v,m+1)});const f=[];f.push('<?xml version="1.0" encoding="UTF-8"?>'),f.push('<Project xmlns="http://schemas.microsoft.com/project">'),f.push(`  <Name>${vt(n)}</Name>`),f.push(`  <Author>${vt(s)}</Author>`),f.push(`  <CreationDate>${o}</CreationDate>`),f.push("  <CalendarUID>1</CalendarUID>"),f.push("  <Calendars>"),f.push("    <Calendar>"),f.push("      <UID>1</UID>"),f.push(`      <Name>${vt(i)}</Name>`),f.push("      <IsBaseCalendar>1</IsBaseCalendar>"),f.push("    </Calendar>"),f.push("  </Calendars>"),f.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,w=u(v),k=h.get(v.id)??"1",S=p.has(v.id),E=v.isMilestone??!1,D=Us(v.startDate),I=Us(v.endDate),M=Va(D,I),R=Ka(M),$=Math.round((v.progress??0)*100);f.push("    <Task>"),f.push(`      <UID>${m}</UID>`),f.push(`      <ID>${m}</ID>`),f.push(`      <Name>${vt(v.name)}</Name>`),f.push(`      <Start>${v.startDate}T08:00:00</Start>`),f.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),f.push(`      <Duration>${R}</Duration>`),f.push(`      <PercentComplete>${$}</PercentComplete>`),f.push(`      <Summary>${S?"1":"0"}</Summary>`),f.push(`      <Milestone>${E?"1":"0"}</Milestone>`),f.push(`      <OutlineLevel>${w}</OutlineLevel>`),f.push(`      <OutlineNumber>${k}</OutlineNumber>`);const x=d.get(v.id);if(x)for(const O of x){const N=r.get(O.source)??0;if(N===0)continue;const Y=za[O.type??"FS"]??1,W=Math.round((O.lag??0)*Fs);f.push("      <PredecessorLink>"),f.push(`        <PredecessorUID>${N}</PredecessorUID>`),f.push(`        <Type>${Y}</Type>`),f.push(`        <LinkLag>${W}</LinkLag>`),f.push("      </PredecessorLink>")}f.push("    </Task>")}f.push("  </Tasks>"),f.push("  <Resources>");for(const v of b){const m=y.get(v)??0;f.push("    <Resource>"),f.push(`      <UID>${m}</UID>`),f.push(`      <Name>${vt(v)}</Name>`),f.push("    </Resource>")}f.push("  </Resources>"),f.push("  <Assignments>");let T=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,w=y.get(v.assignee)??0;m===0||w===0||(f.push("    <Assignment>"),f.push(`      <UID>${T++}</UID>`),f.push(`      <TaskUID>${m}</TaskUID>`),f.push(`      <ResourceUID>${w}</ResourceUID>`),f.push("    </Assignment>"))}return f.push("  </Assignments>"),f.push("</Project>"),f.join(`
`)}function ja(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var c;const u=(c=l.target)==null?void 0:c.result;if(!(!u||!e))try{const h=bn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=bn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),c=vn(u,a);l&&l(c)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),c=vn(u,a),h=new Blob([c],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const qa=[4,3],Za=1.5,Ja=.5,Qa=.06,er=4,tr=8,nr=.35,sr=1,Ws=.2,St=6,Xs=864e5;function $e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Gs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Sn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function wn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function or(e){let t=0;for(const n of e){const s=$e(n.startDate).getTime(),o=$e(n.endDate).getTime();t+=Math.max(o-s,Xs)}return t}function ir(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=$e(l.startDate).getTime(),h=$e(s.startDate).getTime()-u,p=i.segments.map(r=>{const d=new Date($e(r.startDate).getTime()+h),g=new Date($e(r.endDate).getTime()+h);return{startDate:Gs(d),endDate:Gs(g)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,c=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==c){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:c,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),d=c.barBorderRadius,g=h;s.save(),s.beginPath(),s.rect(0,g,s.canvas.width,s.canvas.height-g),s.clip(),s.translate(-l,0);for(const b of i){if(b.isMilestone)continue;const y=t.get(b.taskId);if(!y||y.segments.length===0)continue;const f=b.barY-u,T=b.barHeight,v=f+T/2;if(f+T<g||f>s.canvas.height)continue;const m=[];for(const I of y.segments){const M=r.dateToX($e(I.startDate)),R=r.dateToX($e(I.endDate)),$=Math.max(R-M,4);m.push({startX:M,endX:M+$,width:$})}s.save(),s.fillStyle=c.timelineBg,s.fillRect(b.x-1,f-1,b.width+2,T+2),s.restore();for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX,$=R-M;if(!($<=0)){s.save(),s.globalAlpha=Qa,s.strokeStyle=b.color,s.lineWidth=er,s.beginPath(),s.rect(M,f,$,T),s.clip();for(let x=M-T;x<R+T;x+=tr)s.beginPath(),s.moveTo(x,f+T),s.lineTo(x+T,f),s.stroke();s.restore()}}for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX;s.save(),s.globalAlpha=Ja,s.strokeStyle=Sn(b.color,Ws),s.lineWidth=Za,s.setLineDash(qa),s.beginPath(),s.moveTo(M,v),s.lineTo(R,v),s.stroke(),s.setLineDash([]),s.restore()}const w=o.tasks.get(b.taskId),k=(w==null?void 0:w.progress)??0,S=or(y.segments);let D=k*S;for(let I=0;I<m.length;I++){const M=m[I],R=Math.max($e(y.segments[I].endDate).getTime()-$e(y.segments[I].startDate).getTime(),Xs);if(s.save(),wn(s,M.startX,f,M.width,T,d),s.fillStyle=b.color,s.fill(),s.strokeStyle=Sn(b.color,Ws),s.lineWidth=sr,s.stroke(),s.restore(),D>0&&a.showProgress){const $=Math.min(D,R),x=$/R,O=M.width*x;s.save(),wn(s,M.startX,f,M.width,T,d),s.clip(),s.globalAlpha=nr,s.fillStyle=Sn(b.color,.3),s.fillRect(M.startX,f,O,T),s.restore(),D-=$}}if(b.label){const I=m[0],M=m[m.length-1],R=M.endX-I.startX;s.save(),s.font=`${c.fontSize}px ${c.fontFamily}`;const x=s.measureText(b.label).width;s.textBaseline="middle",s.textAlign="left",x+St*2<=I.width?(s.fillStyle=b.textColor,wn(s,I.startX,f,I.width,T,d),s.clip(),s.fillText(b.label,I.startX+St,v)):x+St<=R?(s.fillStyle=b.textColor,s.fillText(b.label,I.startX+St,v)):(s.fillStyle=c.gridTextColor,s.fillText(b.label,M.endX+St,v)),s.restore()}}s.restore()},destroy(){n=null}}}const Dn=864e5,zs=1e3,_t=4,ar=.6,rr="#E53E3E",lr="#48BB78",cr="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function lt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function $t(e,t){return Math.round((t.getTime()-e.getTime())/Dn)}function Vs(e,t){return new Date(e.getTime()+t*Dn)}function ze(e,t){return lt(Vs(he(e),t))}function Be(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(lt(n)),o;for(;i.getTime()<s.getTime();)o.push(lt(i)),i.setTime(i.getTime()+Dn);return o}class En{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const c of s){const p=(i.get(c)??0)-o;p<=0?i.delete(c):i.set(c,p),(l=a.get(c))==null||l.delete(n),((u=a.get(c))==null?void 0:u.size)===0&&a.delete(c)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const c of s){let h=(a==null?void 0:a.get(c))??0;if((u=l==null?void 0:l.get(c))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Nt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function dr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const c=parseInt(l,10);isNaN(c)||(u=c)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Ks(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function ur(e,t,n,s,o){const i=new Map;for(const f of s)e.has(f.taskId)&&n.has(f.resourceId)&&(i.has(f.taskId)||i.set(f.taskId,[]),i.get(f.taskId).push({resourceId:f.resourceId,units:f.units||1}));const a=new Map,l=new Map;for(const f of e.keys())a.set(f,[]),l.set(f,[]);for(const f of t.values()){if((f.type||"FS")!=="FS"||!e.has(f.source)||!e.has(f.target))continue;const v=f.lag||0;a.get(f.source).push({target:f.target,lag:v}),l.get(f.target).push({source:f.source,lag:v})}const u=new Map;for(const[f,T]of e){const v=he(T.startDate),m=he(T.endDate);u.set(f,{taskId:f,startDate:T.startDate,endDate:T.endDate,duration:Math.max($t(v,m),0)})}const c=new En;function h(){c.clear();for(const[f,T]of u){const v=i.get(f);if(!v)continue;const m=Be(T.startDate,T.endDate);for(const w of v)c.allocate(w.resourceId,f,m,w.units)}}function p(f,T){const v=u.get(f);if(!v)return new Set;const m=new Set,w=v.startDate;if(T===w||he(T).getTime()<he(w).getTime())return m;const k=i.get(f);if(k){const S=Be(v.startDate,v.endDate);for(const E of k)c.deallocate(E.resourceId,f,S,E.units)}if(v.startDate=T,v.endDate=ze(T,v.duration),m.add(f),k){const S=Be(v.startDate,v.endDate);for(const E of k)c.allocate(E.resourceId,f,S,E.units)}return m}function r(f){const T=new Set,v=u.get(f);if(!v)return T;const m=a.get(f)??[];for(const{target:w,lag:k}of m){const S=u.get(w);if(!S)continue;const E=ze(v.endDate,k);if(he(S.startDate).getTime()<he(E).getTime()){const D=p(w,E);for(const I of D){T.add(I);const M=r(I);for(const R of M)T.add(R)}}}return T}function d(f){const T=l.get(f)??[];let v=u.get(f).startDate;v=e.get(f).startDate;for(const{source:w,lag:k}of T){const S=u.get(w);if(!S)continue;const E=ze(S.endDate,k);he(E).getTime()>he(v).getTime()&&(v=E)}return v}h();for(let f=0;f<zs;f++){const T=Nt(c,n);if(T.length===0)break;let v=!1;const m=T[0],w=m.taskIds.map(k=>o.get(k)).filter(k=>k!==void 0).sort(Ks);if(!(w.length<2))for(let k=1;k<w.length;k++){const S=w[k],E=u.get(S.taskId);if(!E)continue;const D=u.get(w[0].taskId);if(!D)continue;const I=D.endDate,M=d(S.taskId),R=he(I).getTime()>he(M).getTime()?I:M;he(R).getTime()>he(E.startDate).getTime()&&(p(S.taskId,R),r(S.taskId),v=!0);const $=c.getLoad(m.resourceId,m.date),x=n.get(m.resourceId).maxUnits;if($<=x)break}}const g=new Map;let b=0;for(const[f,T]of u){const v=e.get(f),m=$t(he(v.startDate),he(T.startDate));m!==0&&(g.set(f,{startDate:T.startDate,endDate:T.endDate,delayDays:m}),b+=m)}const y=Nt(c,n);return{adjustedTasks:g,totalDelay:b,conflicts:y,resolved:y.length===0}}function gr(e,t,n,s,o){const i=new Map;for(const T of s)e.has(T.taskId)&&n.has(T.resourceId)&&(i.has(T.taskId)||i.set(T.taskId,[]),i.get(T.taskId).push({resourceId:T.resourceId,units:T.units||1}));const a=new Map;for(const T of e.keys())a.set(T,[]);for(const T of t.values())(T.type||"FS")==="FS"&&(!e.has(T.source)||!e.has(T.target)||a.get(T.target).push({source:T.source,lag:T.lag||0}));const l=Array.from(e.keys()).map(T=>o.get(T)).filter(T=>T!==void 0).sort(Ks),u=new Map,c=new En,h=new Set,p=new Map;for(const[T,v]of e)p.set(T,Math.max($t(he(v.startDate),he(v.endDate)),0));function r(T){let m=e.get(T).startDate;const w=a.get(T)??[];for(const{source:k,lag:S}of w){const E=u.get(k);if(!E)continue;const D=ze(E.endDate,S);he(D).getTime()>he(m).getTime()&&(m=D)}return m}function d(T,v,m){const w=i.get(T);if(!w||w.length===0)return v;let k=v;const S=365*5;for(let E=0;E<S;E++){const D=ze(k,m),I=Be(k,D);let M=!0;for(const R of w){const $=n.get(R.resourceId);if(!$||$.maxUnits===0)continue;const x=$.calendar?new Set($.calendar):null;if(x&&I.some(N=>x.has(N))){M=!1;break}if(!c.canFit(R.resourceId,T,I,R.units,$.maxUnits)){M=!1;break}}if(M)return k;k=ze(k,1)}return v}const g=new Set(l.map(T=>T.taskId));for(let T=0;T<zs&&g.size>0;T++){let v=!1;for(const m of l){if(!g.has(m.taskId)||!(a.get(m.taskId)??[]).every($=>h.has($.source)))continue;const S=m.taskId,E=p.get(S)??0,D=r(S),I=d(S,D,E),M=ze(I,E);u.set(S,{taskId:S,startDate:I,endDate:M,duration:E});const R=i.get(S);if(R){const $=Be(I,M);for(const x of R)c.allocate(x.resourceId,S,$,x.units)}h.add(S),g.delete(S),v=!0}if(!v){for(const m of g){const w=e.get(m),k=p.get(m)??0;u.set(m,{taskId:m,startDate:w.startDate,endDate:w.endDate,duration:k});const S=i.get(m);if(S){const E=Be(w.startDate,w.endDate);for(const D of S)c.allocate(D.resourceId,m,E,D.units)}h.add(m)}g.clear()}}const b=new Map;let y=0;for(const[T,v]of u){const m=e.get(T),w=$t(he(m.startDate),he(v.startDate));w!==0&&(b.set(T,{startDate:v.startDate,endDate:v.endDate,delayDays:w}),y+=w)}const f=Nt(c,n);return{adjustedTasks:b,totalDelay:y,conflicts:f,resolved:f.length===0}}function hr(e,t,n,s){const o=[],i=Be(n,ze(s,1)),a=i.length;for(const[l,u]of t){const c=new Map;let h=0,p=0;for(const g of i){const b=e.getLoad(l,g);c.set(g,b),h+=b,b>p&&(p=b)}const r=u.maxUnits===0?1:u.maxUnits,d=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:c,overallUtilization:Math.min(d,1),peakUtilization:p})}return o}function js(e,t,n,s){const o=new En,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const c=s.get(a),h=(c==null?void 0:c.startDate)??l.startDate,p=(c==null?void 0:c.endDate)??l.endDate,r=Be(h,p);for(const d of u)o.allocate(d.resourceId,a,r,d.units)}return o}function fr(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function c(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:d,dependencies:g}=r;if(d.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const b=u(),y=dr(d,b,n);s==="parallel"?i=gr(d,g,t,e.assignments,y):i=ur(d,g,t,e.assignments,y);const f=h(d,i.adjustedTasks),T=js(d,t,e.assignments,i.adjustedTasks);return a=hr(T,t,f.start,f.end),i}function h(r,d){let g=1/0,b=-1/0;for(const[y,f]of r){const T=d.get(y),v=he((T==null?void 0:T.startDate)??f.startDate).getTime(),m=he((T==null?void 0:T.endDate)??f.endDate).getTime();v<g&&(g=v),m>b&&(b=m)}if(g===1/0){const y=lt(new Date);return{start:y,end:y}}return{start:lt(new Date(g)),end:lt(new Date(b))}}function p(r){const d=[];for(const g of e.assignments)g.taskId===r&&d.push(g.resourceId);return d}return{name:"ResourceLevelingPlugin",install(r){o=r,c(),l.push(r.on("resourceLeveling:run",(...d)=>{const g=d[0],b=c();g&&g(b)})),l.push(r.on("resourceLeveling:result",(...d)=>{const g=d[0];g&&g(i)})),l.push(r.on("resourceLeveling:utilization",(...d)=>{const g=d[0];g&&g(a)})),l.push(r.on("resourceLeveling:conflicts",(...d)=>{const g=d[0];if(!g)return;const b=r.getState(),y=js(b.tasks,t,e.assignments,new Map);g(Nt(y,t))}))},middleware(r,d){d(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&c()},renderCanvas(r,d,g){if(!i||a.length===0)return;const{config:b}=d,{headerHeight:y,rowHeight:f}=b,T=d.scrollX,v=d.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,y,r.canvas.width,r.canvas.height-y),r.clip(),r.translate(-T,0);const w=new Map;for(const k of a)w.set(k.resourceId,k);for(const k of g){const S=p(k.taskId);if(S.length===0)continue;const E=w.get(S[0]);if(!E)continue;const D=t.get(S[0]);if(!D)continue;const I=D.maxUnits===0?1:D.maxUnits,R=k.barY+k.barHeight-v+1;if(R+_t<y||R>r.canvas.height)continue;const $=d.tasks.get(k.taskId);if(!$)continue;const x=i.adjustedTasks.get(k.taskId),O=(x==null?void 0:x.startDate)??$.startDate,N=(x==null?void 0:x.endDate)??$.endDate,Y=m.dateToX(he(O)),K=m.dateToX(he(N))-Y;if(K<2)continue;r.fillStyle=cr,r.fillRect(Y,R,K,_t);const q=Be(O,N);for(const U of q){const C=E.dailyLoad.get(U)??0;if(C===0)continue;const P=m.dateToX(he(U)),_=m.dateToX(Vs(he(U),1))-P,Q=Math.min(C/I,2)/2*_t,Z=C>I;r.globalAlpha=ar,r.fillStyle=Z?rr:lr,r.fillRect(P,R+_t-Q,_,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const pr=864e5,mr=75,yr=50,qs=25,Ot=.3,Ht=.25,Zs=.2,kn=.15,xt=.1,Tr=.3,Js=.5,br=20,Qs=40,vr=3,Sr=5,wr=30,eo=.25,to=4,Dr=2,Er=5,Cn=5,no=4,so=.4,kr=.003,Ve=260,ct=260,oo=16,Fe=14,Cr="rgba(30, 30, 46, 0.92)",In="#e0e0e0",Ir=10,Bt=32,Mr=6,Ft="#EF4444",Yt="#F97316",Ut="#EAB308",Wt="#22C55E";function ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ke(e,t){return Math.round((t.getTime()-e.getTime())/pr)}function Ee(e,t,n){return Math.max(t,Math.min(n,e))}function Ar(e){return e>=mr?"critical":e>=yr?"high":e>=qs?"medium":"low"}function Lr(e){switch(e){case"critical":return Ft;case"high":return Yt;case"medium":return Ut;case"low":return Wt}}function Xt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Rr(e,t){const n=new Map,s=new Map;for(const f of e.keys())n.set(f,[]),s.set(f,[]);for(const f of t.values())!e.has(f.source)||!e.has(f.target)||(n.get(f.source).push(f.target),s.get(f.target).push(f.source));const o=new Map,i=new Set;function a(f){if(o.has(f))return o.get(f);if(i.has(f))return 0;i.add(f);let T=0;for(const v of n.get(f)||[])T+=1+a(v);return o.set(f,T),T}for(const f of e.keys())a(f);const l=new Map;for(const[f,T]of e){const v=ve(T.startDate),m=ve(T.endDate);l.set(f,Math.max(ke(v,m),0))}const u=new Map,c=new Map,h=new Map;for(const f of e.keys())h.set(f,(s.get(f)||[]).length),u.set(f,l.get(f)||0),c.set(f,null);const p=[],r=new Map(h);for(const[f,T]of r)T===0&&p.push(f);for(;p.length>0;){const f=p.shift();for(const T of n.get(f)||[]){const v=u.get(f)+(l.get(T)||0);v>u.get(T)&&(u.set(T,v),c.set(T,f));const m=r.get(T)-1;r.set(T,m),m===0&&p.push(T)}}const d=new Set;let g=0,b=null;for(const[f,T]of u)T>g&&(g=T,b=f);let y=b;for(;y!==null;)d.add(y),y=c.get(y)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:d}}function Pr(e){const t=Xt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ve(o.startDate),a=ve(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function _r(e,t,n){const s=[],o=Xt(),i=ve(e.startDate),a=ve(e.endDate),l=Math.max(ke(i,a),1),u=Math.max(ke(i,o),0),c=Math.max(ke(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const E=ke(a,o);p=Ee(80+E*2,80,100),s.push({type:"time-pressure",description:`Task is ${E} day${E===1?"":"s"} past its end date`,impact:Math.round(p*Ot)})}else{const E=c/l;E<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(E*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*Ot)})):(p=Ee(Math.round((1-E)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(E*100)}% of scheduled time remaining`,impact:Math.round(p*Ot)}))}let d=0;const g=Ee(u/l,0,1),b=g-h;b>Js?(d=Ee(Math.round(b*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Ht)})):b>Tr?(d=Ee(Math.round(b*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Ht)})):b>.1&&(d=Ee(Math.round(b*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(g*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(d*Ht)}));let y=0;const f=t.downstreamCount.get(e.id)||0,T=t.criticalPathIds.has(e.id);if(f>0){y=Ee(Math.round(Math.log2(f+1)*20),0,70),T&&(y=Ee(Math.round(y*1.5),0,100));const E=T?" (on critical path)":"";s.push({type:"dependency-chain",description:`${f} downstream dependent${f===1?"":"s"}${E}`,impact:Math.round(y*Zs)})}let v=0;l>Qs?(v=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(v*kn)})):l>br&&(v=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(v*kn)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*xt)});else{const E=n.activeTasks.get(e.assignee)||[];E.length>Sr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*xt)})):E.length>vr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*xt)}))}const w=Ee(Math.round(p*Ot+d*Ht+y*Zs+v*kn+m*xt),0,100),k=Ar(w);let S;return r&&h===0?S="Task is overdue with no progress — escalate immediately":r?S="Task is past its deadline — review scope or extend timeline":b>Js?S="Task is significantly behind schedule — investigate blockers":l>Qs&&h<eo?S="Large task with little progress — consider splitting into smaller work items":(k==="high"||k==="critical")&&(S="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:k,riskScore:w,factors:s,suggestion:S}}function $r(e,t,n,s,o){const i=Xt();let a=0,l=0,u=0;for(const[T,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;l++;const m=ve(v.startDate),w=ve(v.endDate),k=Math.max(ke(m,w),1),S=Math.max(ke(m,i),0),E=Ee(S/k,0,1);(v.progress??0)>=E-.1&&a++;const I=t.get(T);I&&(I.riskLevel==="high"||I.riskLevel==="critical")&&u++}const c=l>0?a/l:1;let h=0;for(const T of n.criticalPathIds){const v=e.get(T);if(!v||v.isCompleted)continue;const m=ve(v.endDate);i.getTime()>m.getTime()&&(h+=ke(m,i))}const p=[],r=[];for(const[T,v]of s.activeTasks)p.push(v.length),v.length>to&&r.push(T);let d=100;if(p.length>1){const T=p.reduce((v,m)=>v+m,0)/p.length;if(T>0){const v=p.reduce((w,k)=>w+(k-T)**2,0)/p.length,m=Math.sqrt(v)/T;d=Ee(Math.round(100-m*50),0,100)}}let g=100;if(l>0){let T=0,v=0,m=0;for(const w of e.values()){if(w.isCompleted)continue;const k=ve(w.startDate),S=ve(w.endDate),E=Math.max(ke(k,S),1),D=Math.max(ke(k,i),0),I=Ee(D/E,0,2);T+=w.progress??0,v+=I,m++}if(m>0){const w=T/m,k=v/m;if(k>0){const S=w/k;g=Ee(Math.round(S*100),0,100)}}}const b=c*100,y=Ee(100-h*10,0,100);return{overallScore:Ee(Math.round(b*.25+y*.25+d*.25+g*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function Nr(e,t,n,s){const o=[],i=Xt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const d=ve(r.endDate),g=ke(d,i),b=r.progress??0;g>Er&&b===0&&o.push({type:"escalate",description:`"${r.name}" is ${g} days overdue with zero progress — flag for management`,impact:`Prevents further ${g}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const d=ve(r.startDate),g=ve(r.endDate),b=ke(d,g),y=r.progress??0;if(b>wr&&y<eo){const f=Math.ceil(b/15);o.push({type:"split",description:`"${r.name}" spans ${b} days — split into ${f} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>to?l.push({assignee:p,taskIds:r}):r.length<Dr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const d=r.filter(g=>!t.criticalPathIds.has(g));d.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:d,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const d=ve(r.endDate),g=ke(i,d);if(g>=0&&g<=5){const b=s.get(p);b&&b.riskScore>=qs&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${g} day${g===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${g}-day slip`,taskIds:[p],priority:a++})}}const c=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ve(p.startDate).getTime()-ve(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const d of r)h.add(`${d}->${p}`);for(let p=0;p<c.length;p++)for(let r=p+1;r<c.length;r++){const d=c[p],g=c[r],b=ve(d.endDate),y=ve(g.startDate);if(b.getTime()<=y.getTime()&&!(h.has(`${d.id}->${g.id}`)||h.has(`${g.id}->${d.id}`))){const T=ke(b,y);T>0&&o.push({type:"parallel",description:`"${d.name}" and "${g.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${T} days on the critical path`,taskIds:[d.id,g.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function Or(e,t,n,s,o,i,a){if(e.save(),i){const l=so+(1-so)*(.5+.5*Math.sin(a*kr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function Hr(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,c=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Wt:i>=50?Ut:i>=25?Yt:Ft;e.beginPath(),e.arc(t,n,s,a,c),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=In,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function xr(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Ft,label:"Critical"},{count:o.high,color:Yt,label:"High"},{count:o.medium,color:Ut,label:"Medium"},{count:o.low,color:Wt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const c=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+c),e.closePath(),e.fillStyle=u.color,e.fill(),l+=c}}function Br(e,t,n,s,o){const i=t-Ve-oo,a=n+oo;e.save(),e.beginPath();const l=Ir;e.moveTo(i+l,a),e.lineTo(i+Ve-l,a),e.arcTo(i+Ve,a,i+Ve,a+l,l),e.lineTo(i+Ve,a+ct-l),e.arcTo(i+Ve,a+ct,i+Ve-l,a+ct,l),e.lineTo(i+l,a+ct),e.arcTo(i,a+ct,i,a+ct-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Cr,e.fill(),e.fillStyle=In,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Fe,a+Fe);const u=i+Fe+Bt+4,c=a+Fe+20+Bt+8;Hr(e,u,c,Bt,Mr,s.overallScore);const h=24,p=i+Ve-Fe-h-4,r=c;xr(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const d=r+h+8,g=[{count:o.critical,color:Ft,label:"C"},{count:o.high,color:Yt,label:"H"},{count:o.medium,color:Ut,label:"M"},{count:o.low,color:Wt,label:"L"}],b=28,y=p-g.length*b/2+b/2;for(let m=0;m<g.length;m++){const w=g[m],k=y+m*b;e.fillStyle=w.color,e.fillText(`${w.label}:${w.count}`,k,d)}const f=c+Bt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Fe,f);const T=f+18;e.font="10px sans-serif",e.fillStyle=In,e.fillText("Recommendations:",i+Fe,T);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const w=v[m],k=T+14+m*16,S=w.type==="escalate"?"⚠":w.type==="split"?"✂":w.type==="reassign"?"⇄":w.type==="parallel"?"⇉":w.type==="add-buffer"?"⏱":"ℹ",E=34,D=w.description.length>E?w.description.substring(0,E-1)+"…":w.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${S} ${D}`,i+Fe,k)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Fe,T+14)),e.restore()}function Fr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:c,dependencies:h}=u;if(c.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=Rr(c,h),r=Pr(c),d=new Map;for(const[g,b]of c)d.set(g,_r(b,p,r));n=d,o=Nr(c,p,r,n),s=$r(c,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",c=>{typeof c=="function"&&c(n)})),t.push(e.on("risk:health",c=>{typeof c=="function"&&c(s)})),t.push(e.on("risk:recommendations",c=>{typeof c=="function"&&c(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,c){c(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,c,h){if(n.size===0)return;const{headerHeight:p}=c.config,r=c.scrollX,d=c.scrollY,g=p,b=Date.now()-a;u.save(),u.beginPath(),u.rect(0,g,u.canvas.width,u.canvas.height-g),u.clip(),u.translate(-r,0);for(const y of h){const f=n.get(y.taskId);if(!f||f.riskLevel==="low")continue;const T=y.x,v=y.barY-d,m=y.width,w=y.barHeight;if(v+w<g||v>u.canvas.height||T+m<0)continue;const k=T+m-Cn-no,S=v+Cn+no,E=Lr(f.riskLevel),D=f.riskLevel==="critical";Or(u,k,S,Cn,E,D,b)}if(u.restore(),i){const y={critical:0,high:0,medium:0,low:0};for(const f of n.values())y[f.riskLevel]++;u.save(),Br(u,u.canvas.width,p,s,y),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Le=160,Ke=80,Mn=8,Yr=240,Ur=160,Wr=100,Xr=200,Gt=8,io=.1,ao=3,Gr=.001,zr=500,Vr=5,Kr=864e5,jr={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function ro(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function qr(e,t){return Math.round((t.getTime()-e.getTime())/Kr)}function lo(e,t,n){return e+(t-e)*n}function zt(e,t,n){return Math.max(t,Math.min(n,e))}function An(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function Zr(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const c of s.get(l)){const h=n.get(c),p=u+1;(h===void 0||p>h)&&n.set(c,p);const r=i.get(c)-1;i.set(c,r),r===0&&a.push(c)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function Jr(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Qr(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<Vr;a++){for(let l=1;l<e.length;l++){const u=e[l],c=new Map;for(const h of u){const p=o.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let l=e.length-2;l>=0;l--){const u=e[l],c=new Map;for(const h of u){const p=s.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function el(e,t){const n=new Map;if(t==="radial")return tl(e);const s=t==="lr",o=s?Yr:Ur,i=s?Wr:Xr;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],d=h+p*i;s?n.set(r,{x:a*o,y:d}):n.set(r,{x:d,y:a*o})}}return n}function tl(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function wt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function nl(e,t){return e.color?e.color:e.status&&(t[e.status]||jr[e.status])||"#94A3B8"}function sl(e){const t=ro(e.startDate),n=ro(e.endDate);return Math.max(qr(t,n),0)}function ol(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,c=new Map,h=[],p=null,r=0,d=0,g=1,b=!1,y=0,f=0,T=0,v=0,m=null,w=0,k=0,S=null,E=null,D=new Set,I=!1,M=0,R=0,$=0,x=0;function O(X,L){return{x:(X-r)/g,y:(L-d)/g}}function N(X,L){const{x:H,y:G}=O(X,L);for(const z of c.values()){const V=z.x,te=z.y;if(H>=V&&H<=V+Le&&G>=te&&G<=te+Ke)return z}return null}function Y(){const X=e.getState(),{tasks:L,dependencies:H,config:G}=X;if(L.size===0){c=new Map,h=[];return}p=un(L,H);const z=Zr(L,H),V=Jr(z);Qr(V,H,L);const te=el(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:we}of te.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Le),le=Math.min(le,we),pe=Math.max(pe,we+Ke);const be=(oe+ae)/2,Ce=(le+pe)/2,Ie=c;c=new Map;for(const[ue,we]of L){const Me=te.get(ue);if(!Me)continue;const We=Me.x-be,Je=Me.y-Ce,Ne=Ie.get(ue);c.set(ue,{id:ue,task:we,layer:z.get(ue)??0,orderInLayer:0,x:Ne?Ne.x:We,y:Ne?Ne.y:Je,targetX:We,targetY:Je,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let we=0;we<ue.length;we++){const Me=c.get(ue[we]);Me&&(Me.orderInLayer=we)}h=[];for(const ue of H.values())!L.has(ue.source)||!L.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const L=e.getState(),H=new Set;H.add(X);const G=new Map,z=new Map;for(const oe of L.tasks.keys())G.set(oe,[]),z.set(oe,[]);for(const oe of L.dependencies.values())!L.tasks.has(oe.source)||!L.tasks.has(oe.target)||(G.get(oe.source).push(oe.target),z.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of z.get(oe)||[])H.has(ae)||(H.add(ae),V.push(ae))}const te=[X];for(;te.length>0;){const oe=te.shift();for(const ae of G.get(oe)||[])H.has(ae)||(H.add(ae),te.push(ae))}return H}function K(){I&&cancelAnimationFrame(R),I=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,L=zt(X/zr,0,1),H=1-Math.pow(1-L,3);let G=!1;for(const z of c.values()){if(z.isDragging)continue;const V=Math.abs(z.x-z.targetX),te=Math.abs(z.y-z.targetY);V>.5||te>.5?(z.x=lo(z.x,z.targetX,H),z.y=lo(z.y,z.targetY,H),G=!0):(z.x=z.targetX,z.y=z.targetY)}if(U(),G&&L<1)R=requestAnimationFrame(q);else{I=!1;for(const z of c.values())z.isDragging||(z.x=z.targetX,z.y=z.targetY);U()}}function U(){if(!i||!o)return;const X=e.getState(),{config:L}=X,H=L.theme,G=L.colorMap,z=H.timelineBg==="#1A202C"||H.gridBg==="#1A202C"||H.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(H.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=z?"#1A202C":"#F7F8FA",i.fillRect(0,0,$,x),i.save(),i.translate(r,d),i.scale(g,g);for(const V of h){const te=c.get(V.sourceId),oe=c.get(V.targetId);if(!te||!oe)continue;const ae=D.has(V.sourceId)&&D.has(V.targetId),le=S===V.sourceId||S===V.targetId,pe=S!==null&&!le||E!==null&&!ae,be=te.x+Le,Ce=te.y+Ke/2,Ie=oe.x,ue=oe.y+Ke/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=H.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?z?"#A0AEC0":"#4A5568":z?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const we=(be+Ie)/2;i.beginPath(),i.moveTo(be,Ce),i.quadraticCurveTo(we,Ce,(be+Ie)/2,(Ce+ue)/2),i.quadraticCurveTo(we,ue,Ie,ue),i.stroke();const Me=Math.atan2(ue-(Ce+ue)/2,Ie-we);i.beginPath(),i.moveTo(Ie,ue),i.lineTo(Ie-Gt*Math.cos(Me-Math.PI/6),ue-Gt*Math.sin(Me-Math.PI/6)),i.lineTo(Ie-Gt*Math.cos(Me+Math.PI/6),ue-Gt*Math.sin(Me+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const We=V.dep.type||"FS",Je=V.dep.lag||0,Ne=Je!==0?`${We} +${Je}d`:We!=="FS"?We:"";if(Ne&&!pe){const kt=(be+Ie)/2,zn=(Ce+ue)/2-8;i.font=`10px ${H.fontFamily}`,i.fillStyle=z?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ne,kt,zn)}i.restore()}for(const V of c.values()){const te=S!==null&&S!==V.id&&!P(S,V.id)||E!==null&&!D.has(V.id),oe=S===V.id,ae=E===V.id,le=nl(V.task,G),pe=V.x,be=V.y;i.save(),te&&(i.globalAlpha=.25),V.isCritical&&!te&&(i.save(),i.shadowColor=H.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,wt(i,pe,be,Le,Ke,Mn),i.fillStyle="transparent",i.fill(),i.restore()),wt(i,pe,be,Le,Ke,Mn),i.fillStyle=z?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=H.selectionColor||"#3182CE",i.lineWidth=2,wt(i,pe-2,be-2,Le+4,Ke+4,Mn+2),i.stroke()),i.font=`600 12px ${H.fontFamily}`,i.fillStyle=z?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ce=An(i,V.task.name,Le-20);i.fillText(Ce,pe+10,be+8);const Ie=be+26;i.beginPath(),i.arc(pe+16,Ie+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${H.fontFamily}`,i.fillStyle=z?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(An(i,ue,Le-40),pe+24,Ie);const we=sl(V.task),Me=we===1?"1 day":`${we} days`;i.font=`10px ${H.fontFamily}`,i.fillStyle=z?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Me,pe+10,be+42),V.task.assignee&&(i.font=`10px ${H.fontFamily}`,i.fillStyle=z?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(An(i,V.task.assignee,Le/2-10),pe+Le-10,be+42));const We=V.task.progress??0,Je=be+Ke-6,Ne=Le-20,kt=3;if(wt(i,pe+10,Je,Ne,kt,1.5),i.fillStyle=z?"#4A5568":"#E2E8F0",i.fill(),We>0){const zn=Math.max(kt,Ne*zt(We,0,1));wt(i,pe+10,Je,zn,kt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),C(z,H.fontFamily)}function C(X,L){if(!i)return;const H={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${H[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(g*100)}%`,$-12,12),i.restore()}function P(X,L){for(const H of h)if(H.sourceId===X&&H.targetId===L||H.sourceId===L&&H.targetId===X)return!0;return!1}function A(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;u=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const H=o.getContext("2d");H&&(i=H,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",me),o.addEventListener("mouseup",F),o.addEventListener("mouseleave",ee),o.addEventListener("dblclick",j),o.addEventListener("wheel",J,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",ye))}function _(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&($=X.clientWidth,x=X.clientHeight,o.width=Math.round($*a),o.height=Math.round(x*a),o.style.width=`${$}px`,o.style.height=`${x}px`)}function B(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),_(),Z(),Y();for(const X of c.values())X.x=X.targetX,X.y=X.targetY;U()}}function Q(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),S=null,E=null,D=new Set)}function Z(){r=$/2,d=x/2,g=1}function re(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function ge(X){const{x:L,y:H}=re(X),G=N(L,H);G?(m=G,G.isDragging=!0,w=O(L,H).x-G.x,k=O(L,H).y-G.y,E=G.id,D=W(G.id),e.dispatch({type:"SELECT_TASK",taskId:G.id}),U()):(b=!0,y=L,f=H,T=r,v=d,E&&(E=null,D=new Set,e.dispatch({type:"DESELECT_ALL"}),U()))}function me(X){if(!o)return;const{x:L,y:H}=re(X);if(m){const V=O(L,H);m.x=V.x-w,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U();return}if(b){const V=L-y,te=H-f;r=T+V,d=v+te,U();return}const G=N(L,H),z=G?G.id:null;z!==S&&(S=z,o.style.cursor=S?"pointer":"default",U())}function F(X){m&&(m.isDragging=!1,m=null),b=!1}function ee(X){m&&(m.isDragging=!1,m=null),b=!1,S&&(S=null,U())}function j(X){const{x:L,y:H}=re(X),G=N(L,H);if(G){const z=e.getState();z.tasks.get(G.id)&&z.config&&e.dispatch({type:"SELECT_TASK",taskId:G.id})}}function J(X){if(X.preventDefault(),!o)return;const{x:L,y:H}=re(X),G=O(L,H),z=-X.deltaY*Gr;g=zt(g+z*g,io,ao);const V=O(L,H);r+=(V.x-G.x)*g,d+=(V.y-G.y)*g,U()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],H=o.getBoundingClientRect(),G=L.clientX-H.left,z=L.clientY-H.top,V=N(G,z);V?(m=V,V.isDragging=!0,w=O(G,z).x-V.x,k=O(G,z).y-V.y,E=V.id,D=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(b=!0,y=G,f=z,T=r,v=d),U()}else if(X.touches.length===2){b=!1,m&&(m.isDragging=!1,m=null);const L=X.touches[0],H=X.touches[1];se=Math.hypot(H.clientX-L.clientX,H.clientY-L.clientY),de=(L.clientX+H.clientX)/2,ie=(L.clientY+H.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const H=X.touches[0],G=H.clientX-L.left,z=H.clientY-L.top;if(m){const V=O(G,z);m.x=V.x-w,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U()}else if(b){const V=G-y,te=z-f;r=T+V,d=v+te,U()}}else if(X.touches.length===2){const H=X.touches[0],G=X.touches[1],z=Math.hypot(G.clientX-H.clientX,G.clientY-H.clientY),V=(H.clientX+G.clientX)/2,te=(H.clientY+G.clientY)/2,oe=V-L.left,ae=te-L.top;if(se>0){const le=z/se,pe=O(oe,ae);g=zt(g*le,io,ao);const be=O(oe,ae);r+=(be.x-pe.x)*g,d+=(be.y-pe.y)*g}r+=V-de,d+=te-ie,se=z,de=V,ie=te,U()}}function ye(X){m&&(m.isDragging=!1,m=null),b=!1,se=0}function Te(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",me),o.removeEventListener("mouseup",F),o.removeEventListener("mouseleave",ee),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",J),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",ye),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),I&&(cancelAnimationFrame(R),I=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():B()})),t.push(e.on("networkGraph:layout",(...L)=>{const H=L[0];H!==s&&(s=H,n&&(Y(),K()))})),t.push(e.on("stateChange",()=>{n&&(Y(),K())}))},renderDOM(X,L){o||A(X),n&&(_(),U())},destroy(){for(const X of t)X();t=[],Te(),c=new Map,h=[],p=null,n=!1}}}const co=300,uo="nimbus-gantt-config-panel",Ln="nimbus-gantt-config-panel-styles",go=300,Rn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],il=`
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
`;function al(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(uo);return e?JSON.parse(e):{}}catch{return{}}}function rl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(uo,JSON.stringify(e))}catch{}}function ho(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Vt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ll(){if(typeof document>"u"||document.getElementById(Ln))return;const e=document.createElement("style");e.id=Ln,e.textContent=il,document.head.appendChild(e)}function cl(){if(typeof document>"u")return;const e=document.getElementById(Ln);e&&e.remove()}function Kt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const c=document.createElement("span");return c.className="ng-config-slider-value",c.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);c.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(u),a.appendChild(c),a}function Dt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function jt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=fo(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function fo(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function dl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const S=e.getState();e.dispatch({type:"SET_SCROLL",x:S.scrollX,y:S.scrollY})}function c(S){Object.assign(t,S),rl(t)}function h(S,E,D){S[E]=D}function p(S,E){if(!e)return;const D=e.getState();h(D.config,S,E),c({[S]:E}),u()}function r(S,E){if(!e)return;const D=e.getState();h(D.config.theme,S,E),u()}function d(S){if(!e)return;const E=Rn.find(I=>I.name===S);if(!E)return;const D=e.getState();Object.assign(D.config.theme,E.values),c({themePreset:S}),u()}function g(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function b(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function y(S,E){var X;const{config:D}=E;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?b():g()}),S.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",b),S.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",S.appendChild(o)),o.innerHTML="";const I=document.createElement("div");I.className="ng-config-panel-header",I.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",b),I.appendChild(M),o.appendChild(I);const R=f("Display Settings");R.appendChild(Kt("Row height",24,60,D.rowHeight,2,L=>p("rowHeight",L))),R.appendChild(Kt("Bar height",16,40,D.barHeight,2,L=>p("barHeight",L))),R.appendChild(Kt("Grid width",0,500,D.gridWidth,10,L=>p("gridWidth",L))),R.appendChild(Kt("Font size",10,16,D.theme.fontSize,1,L=>{h(E.config.theme,"fontSize",L),c({fontSize:L}),u()})),R.appendChild(Dt("Today marker",D.showToday,L=>{h(E.config,"showToday",L),c({showToday:L}),u()})),R.appendChild(Dt("Weekends",D.showWeekends,L=>{h(E.config,"showWeekends",L),c({showWeekends:L}),u()})),R.appendChild(Dt("Progress bars",D.showProgress,L=>{h(E.config,"showProgress",L),c({showProgress:L}),u()})),R.appendChild(Dt("Dependency arrows",a,L=>{a=L,c({showDependencies:L}),u()})),R.appendChild(Dt("Labels on bars",t.showBarLabels!==!1,L=>{c({showBarLabels:L}),u()})),o.appendChild(R);const $=f("Color Theme"),x=document.createElement("div");x.className="ng-config-row";const O=document.createElement("span");O.className="ng-config-label",O.textContent="Preset";const N=document.createElement("select");N.className="ng-config-select";const Y=document.createElement("option");Y.value="",Y.textContent="Custom",N.appendChild(Y);for(const L of Rn){const H=document.createElement("option");H.value=L.name,H.textContent=L.name,t.themePreset===L.name&&(H.selected=!0),N.appendChild(H)}N.addEventListener("change",()=>{N.value&&d(N.value)}),x.appendChild(O),x.appendChild(N),$.appendChild(x),$.appendChild(jt("Bar default",D.theme.barDefaultColor,L=>{r("barDefaultColor",L),c({customColors:{...t.customColors,barDefault:L}})})),$.appendChild(jt("Today line",D.theme.todayLineColor,L=>{r("todayLineColor",L),c({customColors:{...t.customColors,todayLine:L}})})),$.appendChild(jt("Grid lines",D.theme.timelineGridColor,L=>{r("timelineGridColor",L),c({customColors:{...t.customColors,gridLines:L}})})),$.appendChild(jt("Background",D.theme.timelineBg,L=>{r("timelineBg",L),c({customColors:{...t.customColors,background:L}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",$.appendChild(W);const K={...D.colorMap,...t.statusColorMap},q=document.createElement("div");function U(){q.innerHTML="";const L=Object.entries(K);for(const[G,z]of L){const V=document.createElement("div");V.className="ng-config-color-map-entry";const te=document.createElement("input");te.className="ng-config-color-map-status",te.value=G,te.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=fo(z),oe.addEventListener("input",()=>{K[G]=oe.value,D.colorMap[G]=oe.value,c({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[G],delete D.colorMap[G],c({statusColorMap:{...K}}),U(),u()}),V.appendChild(te),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const H=document.createElement("button");H.className="ng-config-color-map-add",H.textContent="+ Add status color",H.addEventListener("click",()=>{const G=prompt("Status name:");!G||G.trim()===""||(K[G.trim()]="#3b82f6",D.colorMap[G.trim()]="#3b82f6",c({statusColorMap:{...K}}),U(),u())}),q.appendChild(H)}U(),$.appendChild(q),o.appendChild($);const C=f("Zoom & Time"),P=document.createElement("div");P.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const _=document.createElement("div");_.className="ng-config-zoom-group";const B=["day","week","month","quarter"];for(const L of B){const H=document.createElement("button");H.className="ng-config-zoom-btn"+(E.zoomLevel===L?" ng-active":""),H.textContent=L.charAt(0).toUpperCase()+L.slice(1),H.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),c({zoomLevel:L}),_.querySelectorAll(".ng-config-zoom-btn").forEach(G=>G.classList.toggle("ng-active",G===H)))}),_.appendChild(H)}P.appendChild(A),P.appendChild(_),C.appendChild(P);const Q=document.createElement("div");Q.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=ho(E.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const L=Vt(re.value),H=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),c({dateRangeStart:re.value})}),Q.appendChild(Z),Q.appendChild(re),C.appendChild(Q);const ge=document.createElement("div");ge.className="ng-config-row";const me=document.createElement("span");me.className="ng-config-label",me.textContent="End date";const F=document.createElement("input");F.type="date",F.className="ng-config-date-input",F.value=ho(E.dateRange.end),F.addEventListener("change",()=>{if(!e||!F.value)return;const L=e.getState().dateRange.start,H=Vt(F.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),c({dateRangeEnd:F.value})}),ge.appendChild(me),ge.appendChild(F),C.appendChild(ge);const ee=document.createElement("div");ee.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),ee.appendChild(j),C.appendChild(ee),o.appendChild(C);const J=f("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:E.scrollX,y:E.scrollY}),T("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>T("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&w(e.getState())}),se.appendChild(ce),J.appendChild(se),o.appendChild(J);const ye=f("Plugin Toggles"),Te=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of Te){const H=document.createElement("div");H.className="ng-config-plugin-row";const G=document.createElement("span");G.className="ng-config-plugin-name",G.textContent=L.label;const z=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(z?" ng-active-status":""),V.textContent=z?"Active":"Inactive";const te=document.createElement("div");te.className="ng-config-toggle"+(z?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",te.appendChild(oe);let ae=z;te.addEventListener("click",()=>{ae=!ae,te.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[L.key]:ae};c({pluginToggles:pe}),T(L.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(G),le.appendChild(V),H.appendChild(le),H.appendChild(te),ye.appendChild(H)}o.appendChild(ye)}function f(S){const E=document.createElement("div");E.className="ng-config-section";const D=document.createElement("div");return D.className="ng-config-section-title",D.textContent=S,E.appendChild(D),E}function T(S){e&&v.forEach(E=>E(S))}const v=[];function m(S){const E=Array.from(S.tasks.values());if(E.length===0)return;const D=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],I=E.map(O=>[O.id,`"${(O.name||"").replace(/"/g,'""')}"`,O.startDate,O.endDate,String(Math.round((O.progress??0)*100))+"%",O.status||"",O.assignee||"",O.priority||"",O.groupName||""]),M=[D.join(","),...I.map(O=>O.join(","))].join(`
`),R=new Blob([M],{type:"text/csv;charset=utf-8;"}),$=URL.createObjectURL(R),x=document.createElement("a");x.href=$,x.download="gantt-tasks.csv",document.body.appendChild(x),x.click(),document.body.removeChild(x),URL.revokeObjectURL($)}function w(S){const E=Array.from(S.tasks.values());if(E.length===0)return;const D=["Name","Start","End","Progress","Status","Assignee"],I=E.map($=>[$.name,$.startDate,$.endDate,Math.round(($.progress??0)*100)+"%",$.status||"",$.assignee||""]),R=[D.join("	"),...I.map($=>$.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(R).catch(()=>{})}function k(S){const E=t;if(E.rowHeight!==void 0&&h(S.config,"rowHeight",E.rowHeight),E.barHeight!==void 0&&h(S.config,"barHeight",E.barHeight),E.gridWidth!==void 0&&h(S.config,"gridWidth",E.gridWidth),E.fontSize!==void 0&&h(S.config.theme,"fontSize",E.fontSize),E.showToday!==void 0&&h(S.config,"showToday",E.showToday),E.showWeekends!==void 0&&h(S.config,"showWeekends",E.showWeekends),E.showProgress!==void 0&&h(S.config,"showProgress",E.showProgress),E.showDependencies!==void 0&&(a=E.showDependencies),E.themePreset){const D=Rn.find(I=>I.name===E.themePreset);D&&Object.assign(S.config.theme,D.values)}E.customColors&&(E.customColors.barDefault&&h(S.config.theme,"barDefaultColor",E.customColors.barDefault),E.customColors.todayLine&&h(S.config.theme,"todayLineColor",E.customColors.todayLine),E.customColors.gridLines&&h(S.config.theme,"timelineGridColor",E.customColors.gridLines),E.customColors.background&&h(S.config.theme,"timelineBg",E.customColors.background)),E.statusColorMap&&Object.assign(S.config.colorMap,E.statusColorMap),E.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:E.zoomLevel})),E.dateRangeStart&&E.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:Vt(E.dateRangeStart),end:Vt(E.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(S){e=S,ll(),t=al();const E=S.on("render",()=>{E(),k(S.getState()),u()});l.push(E);const D=S.on("config:open",()=>g()),I=S.on("config:close",()=>b()),M=S.on("config:toggle",()=>{i?b():g()});l.push(D,I,M)},renderDOM(S,E){y(S,E)},destroy(){l.forEach(S=>S()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),cl(),e=null,i=!1}}}const po=864e5,Pn="nimbus-gantt-heatmap-styles",Se=28,Re=2,je=48,Pe=160,ul=3,mo="#1e1e2e",yo="#166534",To="#a16207",bo="#b91c1c",gl=`
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
`;function vo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function hl(e){return String(e.getUTCDate())}function fl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function pl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function So(e,t){return Math.round((t.getTime()-e.getTime())/po)}function wo(e,t){return new Date(e.getTime()+t*po)}function dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function ml(e,t){return e===0?mo:e===1?yo:e===2?To:bo}function yl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Tl(){if(typeof document>"u"||document.getElementById(Pn))return;const e=document.createElement("style");e.id=Pn,e.textContent=gl,document.head.appendChild(e)}function bl(){if(typeof document>"u")return;const e=document.getElementById(Pn);e&&e.remove()}function vl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=So(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(wo(o,h));const u=new Map;let c=0;for(const h of s)for(const p of l){const r=`${h}|${dt(p)}`;u.set(r,{assignee:h,date:p,dateKey:dt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=vo(h.startDate),d=vo(h.endDate),g=So(r,d)+1;for(let b=0;b<g;b++){const y=wo(r,b),f=`${p}|${dt(y)}`,T=u.get(f);T&&(T.tasks.push(h),T.count++,T.count>c&&(c=T.count))}}return{assignees:s,dates:l,cells:u,maxCount:c}}function Sl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&c(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&c(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function c(p){if(!t||!s)return;const r=vl(p);let d=t.querySelector(".ng-heatmap-grid-wrapper");d||(d=document.createElement("div"),d.className="ng-heatmap-grid-wrapper",t.appendChild(d)),d.innerHTML="";const g=document.createElement("canvas"),b=Pe+r.dates.length*(Se+Re),y=je+r.assignees.length*(Se+Re),f=window.devicePixelRatio||1;g.width=b*f,g.height=y*f,g.style.width=b+"px",g.style.height=y+"px",g.style.cursor="pointer";const T=g.getContext("2d");T.scale(f,f),T.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',T.textAlign="center",T.textBaseline="middle";let v="",m=Pe;for(let w=0;w<r.dates.length;w++){const k=r.dates[w],S=fl(k),E=Pe+w*(Se+Re);if(S!==v){if(v&&w>0){const D=(m+E)/2;T.fillStyle="#94a3b8",T.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',T.fillText(v,D,12)}m=E,v=S}}if(v){const w=Pe+r.dates.length*(Se+Re),k=(m+w)/2;T.fillStyle="#94a3b8",T.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',T.fillText(v,k,12)}T.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let w=0;w<r.dates.length;w++){const k=r.dates[w],S=Pe+w*(Se+Re)+Se/2,E=k.getUTCDay()===0||k.getUTCDay()===6;T.fillStyle=E?"#475569":"#64748b",T.fillText(hl(k),S,32)}T.beginPath(),T.strokeStyle="#1e293b",T.lineWidth=1,T.moveTo(0,je-.5),T.lineTo(b,je-.5),T.stroke();for(let w=0;w<r.assignees.length;w++){const k=r.assignees[w],S=je+w*(Se+Re);T.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',T.textAlign="left",T.textBaseline="middle",T.fillStyle="#cbd5e1",T.save(),T.beginPath(),T.rect(0,S,Pe-8,Se),T.clip(),T.fillText(k,8,S+Se/2),T.restore();for(let E=0;E<r.dates.length;E++){const D=r.dates[E],I=`${k}|${dt(D)}`,M=r.cells.get(I),R=(M==null?void 0:M.count)??0,$=Pe+E*(Se+Re),x=ml(R),O=yl(R,r.maxCount);T.globalAlpha=O,T.fillStyle=x,h(T,$,S,Se,Se,ul),T.fill(),R>=2&&(T.globalAlpha=1,T.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',T.textAlign="center",T.textBaseline="middle",T.fillStyle="#fff",T.fillText(String(R),$+Se/2,S+Se/2)),T.globalAlpha=1}}d.appendChild(g),g.addEventListener("mousemove",w=>{if(!n)return;const k=g.getBoundingClientRect(),S=w.clientX-k.left,E=w.clientY-k.top,D=Math.floor((S-Pe)/(Se+Re)),I=Math.floor((E-je)/(Se+Re));if(D<0||D>=r.dates.length||I<0||I>=r.assignees.length||S<Pe||E<je){n.classList.remove("ng-visible");return}const M=r.dates[D],R=r.assignees[I],$=`${R}|${dt(M)}`,x=r.cells.get($);if(!x||x.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const O=document.createElement("div");O.className="ng-heatmap-tooltip-date",O.textContent=`${R} - ${pl(M)}`,n.appendChild(O);for(const W of x.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const N=w.clientX+12,Y=w.clientY+12;n.style.left=N+"px",n.style.top=Y+"px"}),g.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),g.addEventListener("click",w=>{if(!e)return;const k=g.getBoundingClientRect(),S=w.clientX-k.left,E=w.clientY-k.top,D=Math.floor((S-Pe)/(Se+Re)),I=Math.floor((E-je)/(Se+Re));if(D<0||D>=r.dates.length||I<0||I>=r.assignees.length||S<Pe||E<je)return;const M=r.dates[D],$=`${r.assignees[I]}|${dt(M)}`,x=r.cells.get($);if(!(!x||x.count===0)){u();for(const O of x.tasks)e.dispatch({type:"SELECT_TASK",taskId:O.id,multi:!0})}})}function h(p,r,d,g,b,y){p.beginPath(),p.moveTo(r+y,d),p.lineTo(r+g-y,d),p.quadraticCurveTo(r+g,d,r+g,d+y),p.lineTo(r+g,d+b-y),p.quadraticCurveTo(r+g,d+b,r+g-y,d+b),p.lineTo(r+y,d+b),p.quadraticCurveTo(r,d+b,r,d+b-y),p.lineTo(r,d+y),p.quadraticCurveTo(r,d,r+y,d),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Tl();const r=p.on("heatmap:toggle",()=>a()),d=p.on("heatmap:show",()=>l()),g=p.on("heatmap:hide",()=>u());i.push(r,d,g)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const d=document.createElement("div");d.className="ng-heatmap-header-bar";const g=document.createElement("span");g.className="ng-heatmap-title",g.textContent="Resource Heatmap",d.appendChild(g);const b=document.createElement("div");b.className="ng-heatmap-legend";const y=[{color:mo,label:"None"},{color:yo,label:"1 task"},{color:To,label:"2 tasks"},{color:bo,label:"3+ tasks"}];for(const T of y){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=T.color,b.appendChild(v);const m=document.createElement("span");m.textContent=T.label,b.appendChild(m)}d.appendChild(b);const f=document.createElement("button");f.className="ng-heatmap-close",f.textContent="Back to Gantt",f.addEventListener("click",u),d.appendChild(f),t.appendChild(d),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&c(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),bl(),e=null,s=!1,o=null}}}const qe=200,Ze=80,Do=12,Eo=6,wl="rgba(255, 255, 255, 0.95)",Dl="#cbd5e1",El="rgba(59, 130, 246, 0.3)",kl="rgba(59, 130, 246, 0.7)",Cl=1.5,Il=2,Ml=1,_n="nimbus-gantt-minimap-styles",Al=864e5,Ll=`
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
`;function Rl(){if(typeof document>"u"||document.getElementById(_n))return;const e=document.createElement("style");e.id=_n,e.textContent=Ll,document.head.appendChild(e)}function Pl(){if(typeof document>"u")return;const e=document.getElementById(_n);e&&e.remove()}function _l(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,c=0,h=0,p=0,r=0;function d(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function g(){o=!0,t&&t.classList.remove("ng-hidden")}function b(){o=!1,t&&t.classList.add("ng-hidden")}function y(w,k){const S=w/l-p/2,E=k/u-r/2;return{x:Math.max(0,Math.min(S,c-p)),y:Math.max(0,Math.min(E,h-r))}}function f(w){if(!e||!n)return;w.preventDefault(),i=!0;const k=n.getBoundingClientRect(),S=w.clientX-k.left,E=w.clientY-k.top,D=y(S,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function T(w){if(!i||!e||!n)return;w.preventDefault();const k=n.getBoundingClientRect(),S=Math.max(0,Math.min(w.clientX-k.left,qe)),E=Math.max(0,Math.min(w.clientY-k.top,Ze)),D=y(S,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function v(){i=!1}function m(w,k){if(!s||!n||!o)return;const S=window.devicePixelRatio||1;n.width=qe*S,n.height=Ze*S,n.style.width=qe+"px",n.style.height=Ze+"px",s.scale(S,S);const{config:E,scrollX:D,scrollY:I,dateRange:M}=w,R=e.getTimeScale(),$=Math.round((M.end.getTime()-M.start.getTime())/Al),x=R.getColumnWidth();if(c=Math.max($*x,1),h=Math.max(w.flatVisibleIds.length*E.rowHeight,1),p=c>0?Math.min(c,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const A=t.parentElement;p=A.clientWidth-E.gridWidth,r=A.clientHeight-E.headerHeight}l=qe/Math.max(c,1),u=Ze/Math.max(h,1),s.fillStyle=wl,s.fillRect(0,0,qe,Ze);const O=new Map;for(const A of k)O.has(A.rowIndex)||O.set(A.rowIndex,[]),O.get(A.rowIndex).push(A);for(const A of k){const _=A.x*l,B=Math.max(A.width*l,1),Q=A.rowIndex*E.rowHeight*u;s.fillStyle=A.color||E.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(_,Q,B,Math.max(Il,E.rowHeight*u-Ml))}s.globalAlpha=1;const N=D*l,Y=I*u,W=p*l,K=r*u,q=Math.max(0,Math.min(N,qe-1)),U=Math.max(0,Math.min(Y,Ze-1)),C=Math.min(W,qe-q),P=Math.min(K,Ze-U);s.fillStyle=El,s.fillRect(q,U,C,P),s.strokeStyle=kl,s.lineWidth=Cl,s.strokeRect(q,U,C,P)}return{name:"MiniMapPlugin",install(w){e=w,Rl();const k=w.on("minimap:toggle",()=>d()),S=w.on("minimap:show",()=>g()),E=w.on("minimap:hide",()=>b());a.push(k,S,E),typeof document<"u"&&(document.addEventListener("mousemove",T),document.addEventListener("mouseup",v))},renderDOM(w,k){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",f),t.appendChild(n),w.appendChild(t));const S=(e==null?void 0:e.getLayouts())??[];m(k,S)},destroy(){a.forEach(w=>w()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",T),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,Pl(),e=null,o=!0,i=!1}}}const $l="#f59e0b",Nl=[6,4],Ol=1,et=16,Hl=4,xl="rgba(15, 23, 42, 0.95)",Bl="#e2e8f0",Fl="#334155",Yl=6,tt=10,ko=220,Co=12,Io=13;function Ul(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Et(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Wl(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Et(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function Xl(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const c=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(h)*c,r=n+Math.sin(h)*c;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke()}function Gl(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function zl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Vl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Et(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Mo={flag:Wl,star:Xl,warning:Gl,info:zl,deadline:Vl};function Kl(e,t,n,s,o){e.save();const i=`${Co}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Io}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let c=0;if(t.description){const y=t.description.split(" ");let f="";for(const T of y){const v=f?f+" "+T:T;e.measureText(v).width>ko-tt*2&&f?(u.push(f),c=Math.max(c,e.measureText(f).width),f=T):f=v}f&&(u.push(f),c=Math.max(c,e.measureText(f).width))}const h=Math.min(ko,Math.max(l,c)+tt*2),p=Co+4,r=Io+4,d=tt*2+r+(u.length>0?4+u.length*p:0);let g=n-h/2;const b=s-d-8;if(g<4&&(g=4),g+h>o-4&&(g=o-h-4),e.beginPath(),jl(e,g,b,h,d,Yl),e.fillStyle=xl,e.fill(),e.strokeStyle=Fl,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Bl,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,g+tt,b+tt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let y=b+tt+r+4;for(const f of u)e.fillText(f,g+tt,y),y+=p}e.restore()}function jl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function ql(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,c=null;function h(f){return n.find(T=>T.id===f)}function p(f){n.push(f),b()}function r(f){n=n.filter(T=>T.id!==f),b()}function d(f,T){const v=h(f);v&&(Object.assign(v,T),b())}function g(){return[...n]}function b(){if(!t)return;const f=t.getState();t.dispatch({type:"SET_SCROLL",x:f.scrollX,y:f.scrollY})}function y(f){const T=f.canvas;c!==T&&(c&&u&&c.removeEventListener("mousemove",u),c=T,u=v=>{const m=T.getBoundingClientRect();a=v.clientX-m.left,l=v.clientY-m.top;let w=null;for(const k of o){const S=a-k.x,E=l-k.y;if(Math.sqrt(S*S+E*E)<=k.size){w=k.note.id;break}}w!==s&&(s=w,T.style.cursor=s?"pointer":"",b())},T.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(f){t=f;const T=f.on("notes:add",(...k)=>{const S=k[0];S&&S.id&&S.date&&S.label&&p(S)}),v=f.on("notes:remove",(...k)=>{const S=k[0];S&&r(S)}),m=f.on("notes:update",(...k)=>{const S=k[0];if(S&&S.id){const{id:E,...D}=S;d(E,D)}}),w=f.on("notes:list",(...k)=>{const S=k[0];typeof S=="function"&&S(g())});i.push(T,v,m,w)},renderCanvas(f,T,v){if(!t||n.length===0)return;const{config:m,scrollX:w,scrollY:k,dateRange:S}=T,{theme:E}=m,D=m.headerHeight,I=t.getTimeScale();y(f);const M=f.canvas.width/(window.devicePixelRatio||1),R=f.canvas.height/(window.devicePixelRatio||1),$=D,x=R-$;o=[],f.save();for(const O of n){const N=Ul(O.date);if(N<S.start||N>S.end)continue;const Y=O.color||$l,W=O.icon||"flag",K=I.dateToX(N)-w;if(K<-et||K>M+et)continue;f.save(),f.beginPath(),f.setLineDash(Nl),f.strokeStyle=Y,f.globalAlpha=.5,f.lineWidth=Ol,f.moveTo(K,$),f.lineTo(K,$+x),f.stroke(),f.setLineDash([]),f.globalAlpha=1,f.restore();const q=K,U=$+Hl+et/2,C=Mo[W]||Mo.flag;f.save(),f.beginPath(),f.arc(q,U,et/2+3,0,Math.PI*2),f.fillStyle="rgba(0, 0, 0, 0.4)",f.fill(),f.restore(),f.save(),C(f,q,U,et,Y),f.restore(),o.push({note:O,x:q,y:U,size:et/2+4}),s===O.id&&Kl(f,O,q,U-et/2-4,M)}f.restore()},destroy(){i.forEach(f=>f()),i.length=0,c&&u&&c.removeEventListener("mousemove",u),t=null,c=null,u=null,s=null,o=[]}}}const Zl=500,Jl=40,Ao=7,Lo=3,Ro=5,Ql=500,$n="nimbus-gantt-timetravel-styles",Po={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},ec=`
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
`;function tc(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function nc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function sc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function oc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function ic(){if(typeof document>"u"||document.getElementById($n))return;const e=document.createElement("style");e.id=$n,e.textContent=ec,document.head.appendChild(e)}function ac(){if(typeof document>"u")return;const e=document.getElementById($n);e&&e.remove()}const _o=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),qt=[.5,1,2,4];function rc(e){const t=(e==null?void 0:e.maxSnapshots)??Zl,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,c=1;const h=[];let p=null,r=null,d=null,g=null,b=null,y=null,f=null,T=!1;function v(U){if(!s||a)return;const C=s.getState(),P=sc(C,U);i<o.length-1&&(o.length=i+1),o.push(P),o.length>t&&o.shift(),i=o.length-1}function m(U){if(!s||o.length===0)return;const C=Math.max(0,Math.min(U,o.length-1));i=C;const P=o[C];a=!0;const A=P.tasks.map(B=>({id:B.id,name:B.name,startDate:B.startDate,endDate:B.endDate,progress:B.progress,status:B.status})),_=P.dependencies.map(B=>({id:B.id,source:B.source,target:B.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:_}),a=!1,$()}function w(){o.length>0&&m(o.length-1),S()}function k(){if(l||o.length<=1)return;l=!0;const U=qt[c],C=Ql/U;u=setInterval(()=>{if(i>=o.length-1){S();return}m(i+1)},C),$()}function S(){l=!1,u!==null&&(clearInterval(u),u=null),$()}function E(){l?S():k()}function D(){c=(c+1)%qt.length,l&&(S(),k()),$()}function I(){S(),i>0&&m(i-1)}function M(){S(),i<o.length-1&&m(i+1)}function R(){S(),o.length=0,i=-1,a=!1,$()}function $(){if(p){if(g){const U=o.length,C=U>0?i+1:0;g.textContent=`${C} / ${U}`}b&&(b.textContent=l?"⏸":"▶",b.classList.toggle("ng-active",l)),y&&(y.textContent=`${qt[c]}x`),x(),O()}}function x(){if(!d||!r||o.length===0){d&&(d.style.display="none");return}d.style.display="block";const U=o.length<=1?50:i/(o.length-1)*100;d.style.left=`${U}%`}function O(){if(!f||!r||(f.innerHTML="",o.length===0))return;const U=200,C=o.length>U?Math.ceil(o.length/U):1;for(let P=0;P<o.length;P+=C){const A=o[P],_=o.length<=1?50:P/(o.length-1)*100,B=tc(A.action.split(" ")[0]==="Loaded"?"SET_DATA":N(A.action)),Q=Po[B]||Po.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${_}%`,Z.style.background=Q;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${oc(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=P;Z.addEventListener("click",me=>{me.stopPropagation(),S(),m(ge)}),f.appendChild(Z)}}function N(U){return U.startsWith("Moved")?"TASK_MOVE":U.startsWith("Resized")?"TASK_RESIZE":U.startsWith("Added task")?"ADD_TASK":U.startsWith("Added dependency")?"ADD_DEPENDENCY":U.startsWith("Removed task")?"REMOVE_TASK":U.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":U.startsWith("Updated")?"UPDATE_TASK":(U.startsWith("Loaded"),"SET_DATA")}function Y(U){if(!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));S(),m(A)}function W(U){U.preventDefault(),U.stopPropagation(),T=!0,d&&d.classList.add("ng-dragging"),S()}function K(U){if(!T||!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));m(A)}function q(){T&&(T=!1,d&&d.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(U){s=U,ic(),h.push(U.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),U.on("timeTravel:scrub",(...C)=>{const P=C[0];S(),m(P)}),U.on("timeTravel:play",()=>k()),U.on("timeTravel:pause",()=>S()),U.on("timeTravel:present",()=>w()),U.on("timeTravel:clear",()=>R()),U.on("timeTravel:history",(...C)=>{const P=C[0];typeof P=="function"&&P([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(U,C){let P="";n&&_o.has(U.type)&&s&&!a&&(P=nc(U,s.getState())),C(U),n&&_o.has(U.type)&&!a&&P&&v(P)},renderDOM(U,C){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const P=document.createElement("button");P.className="ng-timetravel-btn",P.textContent="◀",P.title="Step backward",P.addEventListener("click",()=>I()),p.appendChild(P),b=document.createElement("button"),b.className="ng-timetravel-btn",b.textContent="▶",b.title="Play / Pause",b.addEventListener("click",()=>E()),p.appendChild(b);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>M()),p.appendChild(A),y=document.createElement("span"),y.className="ng-timetravel-speed ng-timetravel-btn",y.textContent=`${qt[c]}x`,y.title="Click to cycle speed",y.addEventListener("click",()=>D()),p.appendChild(y),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",Y);const _=document.createElement("div");_.className="ng-timetravel-rail",r.appendChild(_),f=document.createElement("div"),f.style.position="absolute",f.style.inset="0",r.appendChild(f),d=document.createElement("div"),d.className="ng-timetravel-playhead",d.addEventListener("mousedown",W),r.appendChild(d),p.appendChild(r),g=document.createElement("span"),g.className="ng-timetravel-counter",p.appendChild(g);const B=document.createElement("button");B.className="ng-timetravel-btn ng-present",B.textContent="Present",B.title="Return to latest state",B.addEventListener("click",()=>w()),p.appendChild(B),U.appendChild(p)}$()},destroy(){S();for(const U of h)U();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,d=null,g=null,b=null,y=null,f=null,ac(),o.length=0,i=-1,a=!1,l=!1,T=!1,s=null}}}const $o=864e5,lc=60,cc=2,No=[6,4],Nn="nimbus-gantt-montecarlo-styles",Oo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},dc=.08,uc=`
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
`;function On(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Zt(e,t){return Math.round((t.getTime()-e.getTime())/$o)}function nt(e,t){return new Date(e.getTime()+t*$o)}function Ho(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function xo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function gc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function hc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function fc(e,t){return e+Math.random()*(t-e)}function pc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const c=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(l),r=[];for(let b=0;b<u;b++)p[b]===0&&(r.push(b),c[b]=o[b],h[b]=o[b]+s[b]);let d=0;for(;d<r.length;){const b=r[d++],y=h[b],f=i[b];for(let T=0;T<f.length;T++){const v=f[T];y>c[v]&&(c[v]=y,h[v]=y+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let b=0;b<u;b++)h[b]===0&&s[b]>0&&(c[b]=o[b],h[b]=o[b]+s[b]);let g=0;for(let b=0;b<u;b++)h[b]>g&&(g=h[b]);return g}function mc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),c=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let y=0;y<e;y++)h[y]===0&&(r.push(y),a[y]=n[y],l[y]=n[y]+t[y]);let d=0;for(;d<r.length;){const y=r[d++];p.push(y);const f=l[y];for(const T of s[y])f>a[T]&&(a[T]=f,l[T]=f+t[T]),h[T]--,h[T]===0&&r.push(T)}for(let y=0;y<e;y++)l[y]===0&&t[y]>0&&(a[y]=n[y],l[y]=n[y]+t[y],p.push(y));let g=0;for(let y=0;y<e;y++)l[y]>g&&(g=l[y]);for(let y=0;y<e;y++)s[y].length===0?(c[y]=g,u[y]=g-t[y]):(c[y]=1/0,u[y]=1/0);for(let y=p.length-1;y>=0;y--){const f=p[y];if(c[f]===1/0){let T=1/0;for(const v of s[f])u[v]<T&&(T=u[v]);T===1/0?c[f]=g:c[f]=T,u[f]=c[f]-t[f]}}const b=new Set;for(let y=0;y<e;y++){const f=u[y]-a[y];Math.abs(f)<.5&&b.add(y)}return b}function yc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const _ of e.keys())u.set(_,l.length),l.push(_);const c=l.length;if(c===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(c),p=new Float64Array(c);let r=1/0;for(const _ of e.values()){const B=On(_.startDate).getTime();B<r&&(r=B)}const d=new Date(r);for(let _=0;_<c;_++){const B=e.get(l[_]),Q=On(B.startDate),Z=On(B.endDate);h[_]=Math.max(Zt(Q,Z),1),p[_]=Zt(d,Q)}const g=Array.from({length:c},()=>[]),b=Array.from({length:c},()=>[]),y=new Int32Array(c);for(const _ of t.values()){if((_.type||"FS")!=="FS")continue;const Q=u.get(_.source),Z=u.get(_.target);Q===void 0||Z===void 0||(g[Q].push(Z),b[Z].push(Q),y[Z]++)}const f=g.map(_=>new Int32Array(_)),T=b.map(_=>new Int32Array(_)),v=new Float64Array(s),m=new Float64Array(c),w=new Float64Array(c),k=new Float64Array(c),S=new Float64Array(c),E=new Float64Array(c),D=Math.max(1,Math.floor(s/100));for(let _=0;_<s;_++){for(let B=0;B<c;B++){const Q=h[B];let Z;switch(i){case"triangular":{const re=Q*(1-o),ge=Q,me=Q*(1+o*1.5);Z=gc(re,ge,me);break}case"normal":{Z=hc(Q,Q*o);break}case"uniform":{Z=fc(Q*(1-o),Q*(1+o));break}}m[B]=Math.max(.5,Z),w[B]+=m[B],k[B]+=m[B]*m[B],m[B]>h[B]&&S[B]++}if(v[_]=pc(l,u,h,m,p,f,T,y),_%D===0){const B=mc(c,m,p,f,T,y);for(const Q of B)E[Q]++}}const I=Array.from(v).sort((_,B)=>_-B),M=I.map(_=>nt(d,_)),R=new Map;for(const _ of a){const B=Math.min(Math.floor(_*I.length),I.length-1);R.set(_,nt(d,I[B]))}let $=0;for(let _=0;_<s;_++)$+=I[_];const x=$/s,O=nt(d,x),N=Math.floor(s/2),Y=nt(d,I[N]);let W=0;for(let _=0;_<s;_++){const B=I[_]-x;W+=B*B}const K=Math.sqrt(W/s),q=nt(d,I[0]),U=nt(d,I[I.length-1]),C=new Map;for(let _=0;_<c;_++){const B=w[_]/s,Q=k[_]/s-B*B;C.set(l[_],{meanDuration:B,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:S[_]/s})}const P=Math.floor(s/D),A=new Map;for(let _=0;_<c;_++)E[_]>0&&A.set(l[_],E[_]/P);return{iterations:s,finishDates:M,percentiles:R,meanFinishDate:O,medianFinishDate:Y,earliestFinish:q,latestFinish:U,standardDeviation:K,taskRisk:C,criticalPathFrequency:A}}function Tc(){if(typeof document>"u"||document.getElementById(Nn))return;const e=document.createElement("style");e.id=Nn,e.textContent=uc,document.head.appendChild(e)}function bc(){if(typeof document>"u")return;const e=document.getElementById(Nn);e&&e.remove()}function vc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const d={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},g=n.getState();s=yc(g.tasks,g.dependencies,d),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function c(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",d=0;for(const[f,T]of s.criticalPathFrequency)T>d&&(d=T,r=f);let g=r;if(n){const f=n.getState().tasks.get(r);f&&(g=f.name)}let b=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const f of t.confidenceLevels){const T=s.percentiles.get(f);if(!T)continue;const v=Math.round(f*100),m=Oo[f]||"#94A3B8";b+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${xo(T)}</span>
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
    `,r&&d>0){const f=Math.round(d*100);b+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${g} (on critical path ${f}% of runs)
        </div>
      `}a.innerHTML=b;const y=a.querySelector(".ng-montecarlo-close");y&&y.addEventListener("click",()=>u())}function p(r,d){if(!s||!n||s.finishDates.length===0)return;const g=n.getTimeScale(),{headerHeight:b}=d.config,y=d.scrollX,f=r.canvas.width/(window.devicePixelRatio||1),T=r.canvas.height/(window.devicePixelRatio||1),v=b,m=T-v,w=s.earliestFinish,k=s.latestFinish,S=Math.max(Zt(w,k),1),E=g.getColumnWidth(),D=Math.max(E,cc),I=Math.max(Math.ceil(S),1),M=new Uint32Array(I);for(const N of s.finishDates){const Y=Zt(w,N),W=Math.min(Math.max(Math.floor(Y),0),I-1);M[W]++}let R=0;for(let N=0;N<I;N++)M[N]>R&&(R=M[N]);if(R===0)return;r.save(),r.beginPath(),r.rect(0,v,f,m),r.clip(),r.translate(-y,0);const $=s.finishDates[Math.floor(s.finishDates.length*.1)],x=s.finishDates[Math.floor(s.finishDates.length*.9)];if($&&x){const N=g.dateToX($),Y=g.dateToX(x),W=r.createLinearGradient(N,0,Y,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=dc*5,r.fillRect(N,v,Y-N,m),r.globalAlpha=1}const O=T-8;for(let N=0;N<I;N++){if(M[N]===0)continue;const Y=nt(w,N),W=g.dateToX(Y),K=M[N]/R*lc,q=I>1?N/(I-1):.5;let U,C,P;if(q<.5){const A=q*2;U=Math.round(34+200*A),C=Math.round(197+-18*A),P=Math.round(94+-86*A)}else{const A=(q-.5)*2;U=Math.round(234+5*A),C=Math.round(179+-111*A),P=Math.round(8+60*A)}r.fillStyle=`rgba(${U}, ${C}, ${P}, 0.6)`,r.fillRect(W,O-K,Math.max(D-1,1),K)}r.setLineDash(No),r.lineWidth=1.5;for(const[N,Y]of s.percentiles){const W=g.dateToX(Y),K=Oo[N]||"#94A3B8",q=`P${Math.round(N*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,v),r.lineTo(W,T),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const U=r.measureText(`${q}: ${Ho(Y)}`).width,C=`${q}: ${Ho(Y)}`,P=U+8,A=16,_=W-P/2,B=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(_+3,B),r.lineTo(_+P-3,B),r.arcTo(_+P,B,_+P,B+3,3),r.lineTo(_+P,B+A-3),r.arcTo(_+P,B+A,_+P-3,B+A,3),r.lineTo(_+3,B+A),r.arcTo(_,B+A,_,B+A-3,3),r.lineTo(_,B+3),r.arcTo(_,B,_+3,B,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(C,W,B+3),r.setLineDash(No)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Tc(),i.push(r.on("montecarlo:run",(...d)=>{const g=d[0];l(g)}),r.on("montecarlo:result",(...d)=>{const g=d[0];typeof g=="function"&&g(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...d)=>{const g=d[0];g&&c(g)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,d){d(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,d,g){!o||!s||p(r,d)},renderDOM(r,d){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),bc(),s=null,n=null}}}const Jt=864e5,Bo=400,Hn="nimbus-gantt-narrative-styles",Fo=300;function Ye(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function xn(e,t){return Math.round((t.getTime()-e.getTime())/Jt)}function Yo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Uo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*Jt)}function Wo(e,t){return new Date(e.getTime()+t*Jt)}function Sc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const D of n){const I=Ye(D.startDate).getTime(),M=Ye(D.endDate).getTime();I<s&&(s=I),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=xn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const c=new Map,h=new Map;for(const D of t.values())!e.has(D.source)||!e.has(D.target)||(c.has(D.source)||c.set(D.source,[]),c.get(D.source).push(D.target),h.has(D.target)||h.set(D.target,[]),h.get(D.target).push(D.source));const p=kc(n,t),r=Uo(i),d=Uo(a),g=[];let b=r;for(;b.getTime()<=d.getTime();)g.push({start:new Date(b),end:Wo(b,6)}),b=Wo(b,7);const y=[];for(let D=0;D<g.length;D++){const I=g[D],M=I.start,R=I.end,$=[],x=[],O=[],N=[],Y=[],W=[],K=[];for(const A of n){const _=Ye(A.startDate),B=Ye(A.endDate);_>=M&&_<=R&&($.push(A),A.isMilestone?(W.push(A),K.push(`Milestone: ${A.name}`)):K.push(`Started: ${A.name}`)),B>=M&&B<=R&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(x.push(A),K.push(`Completed: ${A.name}`)),_<=R&&B>=M&&(Y.push(A),_<M&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&O.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&N.push(A))}for(const A of n)if(A.isMilestone){const _=Ye(A.startDate);_>=M&&_<=R&&!W.includes(A)&&(W.push(A),K.push(`Milestone: ${A.name}`))}const q=Y.filter(A=>p.has(A.id)),U=wc($,x,O,Y,q),C=Dc($,x,O,N,Y,q,W,c,e),P=`Week ${D+1} (${Yo(M)}–${Yo(R)})`;y.push({weekLabel:P,headline:U,body:C,metrics:{started:$.length,completed:x.length,delayed:O.length,onTrack:N.length},events:K})}const f=n.length,T=n.filter(D=>D.isCompleted||D.progress!==void 0&&D.progress>=1).length,v=n.filter(D=>!D.isCompleted&&D.progress!==void 0&&D.progress>0&&D.progress<1).length,m=f-T-v,w=f>0?Math.round(T/f*100):0,k=w>=75?"strong":w>=50?"moderate":w>=25?"early-stage":"just getting started",S=`This project spans ${l} days across ${g.length} weeks with ${f} tasks. Progress is ${k} at ${w}% completion (${T} done, ${v} in progress, ${m} not started).`,E=Ec(n,p,c,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:S,chapters:y,insights:E}}function wc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Dc(e,t,n,s,o,i,a,l,u){const c=[];if(e.length>0)if(e.length<=3){const r=e.map(d=>d.name).join(", ");c.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(d=>d.name).join(", ");c.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(d=>d.name).join(", ");c.push(`${r} ${t.length===1?"was":"were"} completed.`)}else c.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&c.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(d=>d.name).join(", ");c.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const d=n.map(g=>g.name).join(", ");c.push(`${d} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else c.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const d of n){const g=l.get(d.id);if(g)for(const b of g){const y=u.get(b);y&&!r.includes(y.name)&&r.push(y.name)}}if(r.length>0){const d=r.slice(0,3).join(", ");c.push(`This puts downstream work at risk, including ${d}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&c.length<4){const r=i.slice(0,2).map(d=>d.name).join(" and ");c.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,d)=>d[1]-r[1]);return p.length>0&&p[0][1]>=3&&c.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),c.length===0&&c.push("No significant activity scheduled for this week."),c.join(" ")}function Ec(e,t,n,s,o,i,a){const l=[];if(t.size>0){const y=e.filter(v=>t.has(v.id)),f=y.slice(0,4).map(v=>v.name).join(", "),T=y.length>4?` and ${y.length-4} more`:"";l.push(`The critical path runs through ${f}${T} — any delay here pushes the project finish.`)}const u=new Map;for(const y of e)y.assignee&&!y.isCompleted&&u.set(y.assignee,(u.get(y.assignee)||0)+1);const c=Array.from(u.entries()).sort((y,f)=>f[1]-y[1]);c.length>0&&c[0][1]>=2&&l.push(`${c[0][0]} is carrying the heaviest load with ${c[0][1]} concurrent tasks.`);const h=e.filter(y=>y.isCompleted?!1:Ye(y.startDate)<a&&(y.progress===void 0||y.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=xn(o,i),r=xn(o,a);if(r>0&&p>0){const y=Math.round(r/p*100),f=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,T=Math.round(f/e.length*100),v=T-y;Math.abs(v)>=5?v>0?l.push(`Project is running ahead: ${T}% of tasks completed with ${y}% of time elapsed.`):l.push(`Project is running behind: only ${T}% of tasks completed with ${y}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${T}% complete at ${y}% of elapsed time.`)}const d=e.filter(y=>{if(y.isCompleted||y.progress!==void 0&&y.progress>0)return!1;const f=s.get(y.id);return!f||f.length===0});d.length>0&&d.length<=e.length*.5&&l.push(`${d.length} task${d.length>1?"s are":" is"} unblocked and ready to start.`);let g=0,b="";for(const y of e){const f=n.get(y.id);f&&f.length>g&&(g=f.length,b=y.name)}return g>=3&&l.push(`"${b}" is a bottleneck with ${g} downstream tasks depending on it.`),l}function kc(e,t){const n=new Map;for(const d of e)n.set(d.id,d);const s=new Map,o=new Map;for(const d of e)s.set(d.id,[]),o.set(d.id,0);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||(s.get(d.source).push({target:d.target,lag:d.lag||0}),o.set(d.target,(o.get(d.target)||0)+1)));const i=new Map,a=[];for(const d of e)o.get(d.id)===0&&a.push(d.id);for(const d of e){const g=Ye(d.endDate).getTime();i.set(d.id,g)}const l=new Map(o);for(;a.length>0;){const d=a.shift(),g=i.get(d);for(const b of s.get(d)){const y=n.get(b.target),f=Ye(y.endDate).getTime()-Ye(y.startDate).getTime(),T=g+b.lag*Jt+f;T>i.get(b.target)&&i.set(b.target,T);const v=l.get(b.target)-1;l.set(b.target,v),v===0&&a.push(b.target)}}let u=-1/0,c="";for(const[d,g]of i)g>u&&(u=g,c=d);if(!c)return new Set;const h=new Set,p=new Map;for(const d of e)p.set(d.id,[]);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||p.get(d.target).push({source:d.source,lag:d.lag||0}));let r=c;for(;r;){h.add(r);const d=p.get(r);if(!d||d.length===0)break;let g="",b=-1/0;for(const y of d){const f=i.get(y.source)||0;f>b&&(b=f,g=y.source)}if(!g||h.has(g))break;r=g}return h}const Cc=`
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
`;function Ic(){if(typeof document>"u"||document.getElementById(Hn))return;const e=document.createElement("style");e.id=Hn,e.textContent=Cc,document.head.appendChild(e)}function Mc(){if(typeof document>"u")return;const e=document.getElementById(Hn);e&&e.remove()}function Ac(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Lc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=Sc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function c(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const d=document.createElement("div");d.className="ng-narrative-header-left";const g=document.createElement("span");g.textContent="📖",d.appendChild(g);const b=document.createElement("span");b.textContent="Project Story",d.appendChild(b),r.appendChild(d);const y=document.createElement("div");y.style.display="flex",y.style.alignItems="center",y.style.gap="4px";const f=document.createElement("button");f.className="ng-narrative-refresh",f.innerHTML="↻",f.title="Regenerate",f.addEventListener("click",()=>{l(),h()}),y.appendChild(f);const T=document.createElement("button");T.className="ng-narrative-close",T.innerHTML="×",T.addEventListener("click",c),y.appendChild(T),r.appendChild(y),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const k=document.createElement("div");k.className="ng-narrative-empty",k.textContent="No weekly chapters to display.",a.appendChild(k)}else for(const k of t.chapters){const S=document.createElement("div");S.className="ng-narrative-chapter";const E=Ac(k),D=document.createElement("div");D.className=`ng-narrative-chapter-header ng-${E}`;const I=document.createElement("div");I.className="ng-narrative-week-label",I.textContent=k.weekLabel,D.appendChild(I);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=k.headline,D.appendChild(M),S.appendChild(D);const R=document.createElement("div");if(R.className="ng-narrative-metrics",k.metrics.started>0&&R.appendChild(p("started",`${k.metrics.started} started`)),k.metrics.completed>0&&R.appendChild(p("completed",`${k.metrics.completed} done`)),k.metrics.delayed>0&&R.appendChild(p("delayed",`${k.metrics.delayed} delayed`)),k.metrics.onTrack>0&&R.appendChild(p("ontrack",`${k.metrics.onTrack} on track`)),R.children.length>0&&S.appendChild(R),k.body){const $=document.createElement("div");$.className="ng-narrative-body",$.textContent=k.body,S.appendChild($)}a.appendChild(S)}if(t.insights.length>0){const k=document.createElement("div");k.className="ng-narrative-insights";const S=document.createElement("div");S.className="ng-narrative-insights-title",S.innerHTML="<span>💡</span> Key Insights",k.appendChild(S);for(const E of t.insights){const D=document.createElement("div");D.className="ng-narrative-insight";const I=document.createElement("span");I.className="ng-narrative-insight-icon",I.textContent="•",D.appendChild(I);const M=document.createElement("span");M.textContent=E,D.appendChild(M),k.appendChild(D)}a.appendChild(k)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const w=new Date(t.generatedAt);m.textContent=`Generated ${w.toLocaleString()}`,a.appendChild(m)}function p(r,d){const g=document.createElement("span");return g.className=`ng-narrative-badge ng-${r}`,g.textContent=d,g}return{name:"NarrativePlugin",install(r){e=r,Ic(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>c()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,d){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?c():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",c),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),Mc(),e=null,t=null,n=!1}}}const Rc=864e5,Pc=10,Bn="nimbus-gantt-whatif-styles",Xo=.25,_c=.6,Qt=6,Go="#38A169",zo="#E53E3E",Vo="#A0AEC0",Fn=36,$c="#F6AD55",Ko="#1a202c",Nc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Fn}px;
    background: ${$c};
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
    color: ${Go};
  }
  .ng-whatif-summary-value--worsened {
    color: ${zo};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${Vo};
  }
`;function Ue(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function jo(e){const t=Ue(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function en(e,t){return Math.round((t.getTime()-e.getTime())/Rc)}function qo(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function Oc(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function Hc(e){return{...e}}function xc(){if(typeof document>"u"||document.getElementById(Bn))return;const e=document.createElement("style");e.id=Bn,e.textContent=Nc,document.head.appendChild(e)}function Bc(){if(typeof document>"u")return;const e=document.getElementById(Bn);e&&e.remove()}function Fc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,Oc(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,Hc(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function Zo(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function Yc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,c=null,h=null,p=null,r=null,d=null,g=null;function b(){t||!e||(o=Fc(e.getState()),i=[],t=!0,n=!1,E())}function y(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],E(),M(),$())}function f(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,D(),M())}function T(C){if(!t||!e||!o)return;a.length>=Pc&&a.shift();const P=e.getState(),A=Zo(P.tasks),_=Ue(o.projectFinish),B=Ue(A),Q=en(_,B);let Z=0;for(const[ge,me]of o.tasks){const F=P.tasks.get(ge);if(!F){Z++;continue}(F.startDate!==me.startDate||F.endDate!==me.endDate||F.assignee!==me.assignee)&&Z++}for(const ge of P.tasks.keys())o.tasks.has(ge)||Z++;const re={id:qo(),name:C,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:Q,tasksAffected:Z}};a.push(re),Y()}function v(C){if(!e||!o)return;const P=a.find(A=>A.id===C);if(P){t||b(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of P.changes)w(A);i=[...P.changes],D()}}function m(C){a=a.filter(P=>P.id!==C),Y()}function w(C){if(e)switch(C.type){case"move":case"resize":C.taskId&&C.after&&C.after.startDate&&C.after.endDate&&e.dispatch({type:C.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:C.taskId,startDate:C.after.startDate,endDate:C.after.endDate});break;case"add":C.after&&e.dispatch({type:"ADD_TASK",task:C.after});break;case"remove":C.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:C.taskId});break;case"reassign":C.taskId&&C.after&&e.dispatch({type:"UPDATE_TASK",taskId:C.taskId,changes:C.after});break;case"add-dependency":C.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:C.dependencyId||qo(),source:C.dependency.source,target:C.dependency.target,type:C.dependency.type||"FS"}});break;case"remove-dependency":C.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:C.dependencyId});break}}function k(){t&&(n=!n,n?I():M())}function S(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const C=e.getState(),P=Zo(C.tasks),A=Ue(o.projectFinish),_=Ue(P),B=en(A,_);let Q=0;for(const[Z,re]of o.tasks){const ge=C.tasks.get(Z);if(!ge){Q++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&Q++}for(const Z of C.tasks.keys())o.tasks.has(Z)||Q++;return{baselineFinish:o.projectFinish,sandboxFinish:P,deltaDays:B,tasksAffected:Q}}function E(){u&&u.classList.toggle("ng-hidden",!t)}function D(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function I(){if(!h)return;const C=S();let P="ng-whatif-summary-value--unchanged",A="No change";C.deltaDays<0?(P="ng-whatif-summary-value--improved",A=`${Math.abs(C.deltaDays)} day${Math.abs(C.deltaDays)!==1?"s":""} earlier`):C.deltaDays>0&&(P="ng-whatif-summary-value--worsened",A=`${C.deltaDays} day${C.deltaDays!==1?"s":""} later`),h.innerHTML=`
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
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function R(){s=!s,c&&c.classList.toggle("ng-open",s),s&&Y()}function $(){s=!1,c&&c.classList.remove("ng-open")}function x(){r&&(r.classList.add("ng-active"),d==null||d.focus())}function O(){r&&r.classList.remove("ng-active"),d&&(d.value="")}function N(){if(!d)return;const C=d.value.trim();C&&(T(C),O())}function Y(){if(g){if(a.length===0){g.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}g.innerHTML=a.map(C=>{var B;const P=new Date(C.createdAt).toLocaleDateString(),A=((B=C.result)==null?void 0:B.criticalPathDelta)??0;let _="No impact";return A<0?_=`${Math.abs(A)}d earlier`:A>0&&(_=`${A}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${C.id}">
            <div class="ng-whatif-scenario-name">${W(C.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${P}</span>
              <span>${C.changes.length} changes</span>
              <span>${_}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${C.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${C.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${C.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(C){const P=document.createElement("div");return P.textContent=C,P.innerHTML}function K(C){const P=C.target,A=P.getAttribute("data-action"),_=P.getAttribute("data-id");if(!(!A||!_))switch(A){case"load":v(_),$();break;case"compare":v(_),n=!0,I(),$();break;case"delete":m(_);break}}function q(C,P){switch(C.type){case"TASK_MOVE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"move",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"TASK_RESIZE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"resize",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:C.task.id,after:{...C.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:C.taskId,before:P.tasks.get(C.taskId)?{...P.tasks.get(C.taskId)}:void 0});break;case"UPDATE_TASK":{const A=P.tasks.get(C.taskId);A&&i.push({type:"reassign",taskId:C.taskId,before:{...A},after:C.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:C.dependency.id,dependency:{source:C.dependency.source,target:C.dependency.target,type:C.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:C.dependencyId});break}D()}function U(C,P,A,_,B,Q){const Z=Math.min(Q,_/2,B/2);C.beginPath(),C.moveTo(P+Z,A),C.lineTo(P+_-Z,A),C.arcTo(P+_,A,P+_,A+Z,Z),C.lineTo(P+_,A+B-Z),C.arcTo(P+_,A+B,P+_-Z,A+B,Z),C.lineTo(P+Z,A+B),C.arcTo(P,A+B,P,A+B-Z,Z),C.lineTo(P,A+Z),C.arcTo(P,A,P+Z,A,Z),C.closePath()}return{name:"WhatIfPlugin",install(C){e=C,xc(),l.push(C.on("whatif:enter",()=>b())),l.push(C.on("whatif:exit",()=>y())),l.push(C.on("whatif:compare",()=>k())),l.push(C.on("whatif:discard",()=>f())),l.push(C.on("whatif:save",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?T(A):x()})),l.push(C.on("whatif:load",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?v(A):R()})),l.push(C.on("whatif:list-scenarios",(...P)=>{const A=typeof P[0]=="function"?P[0]:void 0;A?A([...a]):R()})),l.push(C.on("whatif:delete-scenario",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A&&m(A)}))},middleware(C,P){if(!t){P(C);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(C.type)&&e){const _=e.getState();q(C,_)}P(C)},renderCanvas(C,P,A){if(!t||!e)return;const{theme:_,headerHeight:B,barHeight:Q}=P.config,Z=P.scrollX,re=P.scrollY,ge=B,me=e.getTimeScale(),F=_.barBorderRadius;if(C.save(),C.beginPath(),C.rect(0,ge,C.canvas.width,C.canvas.height-ge),C.clip(),C.translate(-Z,0),o){const ee=new Set;for(const j of A){const J=o.tasks.get(j.taskId),se=P.tasks.get(j.taskId);(!J&&se||J&&se&&(J.startDate!==se.startDate||J.endDate!==se.endDate||J.assignee!==se.assignee))&&ee.add(j.taskId)}for(const j of A){if(!ee.has(j.taskId))continue;const J=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>C.canvas.height||(C.save(),C.setLineDash([4,3]),C.strokeStyle="#F6AD55",C.lineWidth=2,U(C,J,se,de,ie,F),C.stroke(),C.restore())}}if(n&&o){const ee=Q*_c;for(const j of A){if(j.isMilestone)continue;const J=o.tasks.get(j.taskId);if(!J)continue;const se=P.tasks.get(j.taskId);if(!se)continue;const de=Ue(J.startDate),ie=Ue(J.endDate),fe=Ue(se.startDate),ce=Ue(se.endDate),ye=en(de,fe),Te=en(ie,ce);if(ye===0&&Te===0)continue;let X=Vo;Te<0?X=Go:Te>0&&(X=zo);const L=me.dateToX(de),H=me.dateToX(ie),G=Math.max(H-L,2),z=j.barY-re,V=z+Q+2;C.save(),C.globalAlpha=Xo,C.fillStyle=X,U(C,L,V,G,ee,F),C.fill(),C.globalAlpha=Xo*2,C.strokeStyle=X,C.lineWidth=1,C.stroke(),C.restore();const te=L+G/2,oe=V+ee/2,ae=j.x+j.width/2,le=z+Q/2;C.save(),C.globalAlpha=.6,C.strokeStyle=X,C.lineWidth=1.5,C.setLineDash([3,2]),C.beginPath(),C.moveTo(te,oe),C.lineTo(ae,le),C.stroke();const pe=Math.atan2(le-oe,ae-te),be=ae,Ce=le;C.setLineDash([]),C.beginPath(),C.moveTo(be,Ce),C.lineTo(be-Qt*Math.cos(pe-Math.PI/6),Ce-Qt*Math.sin(pe-Math.PI/6)),C.lineTo(be-Qt*Math.cos(pe+Math.PI/6),Ce-Qt*Math.sin(pe+Math.PI/6)),C.closePath(),C.fillStyle=X,C.fill(),C.restore()}}C.restore()},renderDOM(C,P){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const _=document.createElement("span");_.className="ng-whatif-badge",_.textContent="What-If Mode",A.appendChild(_);const B=document.createElement("span");B.textContent="Changes are hypothetical",B.style.fontSize="12px",B.style.opacity="0.7",A.appendChild(B);const Q=document.createElement("span");Q.textContent="·",Q.style.opacity="0.4",A.appendChild(Q),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",A.appendChild(p),u.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",d=document.createElement("input"),d.type="text",d.placeholder="Scenario name...",d.addEventListener("keydown",se=>{se.key==="Enter"&&N(),se.key==="Escape"&&O()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",N);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>O()),r.appendChild(d),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const me=document.createElement("button");me.className="ng-whatif-btn",me.textContent="Scenarios",me.addEventListener("click",()=>R()),Z.appendChild(me);const F=document.createElement("button");F.className="ng-whatif-btn ng-whatif-btn--primary",F.textContent="Compare with Baseline",F.addEventListener("click",()=>k()),Z.appendChild(F);const ee=document.createElement("button");ee.className="ng-whatif-btn",ee.textContent="Save Scenario",ee.addEventListener("click",()=>x()),Z.appendChild(ee);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>f()),Z.appendChild(j);const J=document.createElement("button");J.className="ng-whatif-btn ng-whatif-btn--danger",J.textContent="Exit",J.addEventListener("click",()=>y()),Z.appendChild(J),u.appendChild(Z),C.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",C.appendChild(h)),!c){c=document.createElement("div"),c.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const _=document.createElement("span");_.textContent="Saved Scenarios",A.appendChild(_);const B=document.createElement("button");B.className="ng-whatif-panel-close",B.textContent="×",B.addEventListener("click",()=>$()),A.appendChild(B),c.appendChild(A),g=document.createElement("div"),g.addEventListener("click",K),c.appendChild(g),C.appendChild(c),Y()}E(),n&&I()},destroy(){for(const C of l)C();l.length=0,u&&(u.remove(),u=null),c&&(c.remove(),c=null),h&&(h.remove(),h=null),p=null,r=null,d=null,g=null,Bc(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Yn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},Uc=261.63;function Wc(e){return Uc*Math.pow(2,e/12)}function Xc(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return Wc(n?a+12:a)}const Un="nimbus-gantt-sonification-styles",Wn=64,tn=64,Jo=.05,Gc=.1,zc=.7,Qo=.2,Xn="#F6AD55",Vc=2,Kc="rgba(246, 173, 85, 0.35)",ei=12,jc=`
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
`;function Gn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function qc(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=jc,document.head.appendChild(e)}function Zc(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function Jc(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,c=null,h=null;const p=new Map;let r="stopped",d=0,g=0,b=0,y=0,f=0,T=0,v=0,m=null,w=null,k=null,S=null,E=null,D=null;const I=[];let M=[],R=[];function $(){if(l)return;const F=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;F&&(l=new F,u=l.createGain(),u.gain.value=i,c=l.createAnalyser(),c.fftSize=256,h=new Uint8Array(c.frequencyBinCount),u.connect(c),c.connect(l.destination))}function x(){l&&l.state==="suspended"&&l.resume()}function O(){if(!a)return;const F=a.getState(),ee=Date.now();let j=1/0,J=-1/0;const se=[],de=new Set,ie=F.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,ye]of F.tasks){const Te=Gn(ye.startDate).getTime(),X=Gn(ye.endDate).getTime();Te<j&&(j=Te),X>J&&(J=X);const L=ye.groupId||"__default__";de.add(L);const H=fe.get(ce)??0,G=!ye.isCompleted&&X<ee&&(ye.progress??0)<1;se.push({id:ce,startMs:Te,endMs:X,rowIndex:H,progress:ye.progress??0,groupId:L,isCritical:!1,isOverdue:G})}M=se,R=Array.from(de),f=j===1/0?0:j,T=J===-1/0?0:J,v=Math.max(T-f,1)}function N(F){if(!l||!u||p.has(F.id))return;const ee=Yn[n]||Yn.major,j=Xc(F.rowIndex,ee,F.isCritical),J=l.createOscillator();J.type=s,J.frequency.value=j,F.isOverdue&&(J.detune.value=25);const se=.3+F.progress*.7,de=F.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+Jo),fe.gain.linearRampToValueAtTime(ie*zc,l.currentTime+Jo+Gc);const ce=l.createStereoPanner();if(R.length<=1)ce.pan.value=0;else{const ye=R.indexOf(F.groupId);ce.pan.value=R.length>1?ye/(R.length-1)*2-1:0}J.connect(fe),fe.connect(ce),ce.connect(u),J.start(),p.set(F.id,{taskId:F.id,oscillator:J,gainNode:fe,panNode:ce})}function Y(F){const ee=p.get(F);if(!ee||!l)return;const j=l.currentTime;ee.gainNode.gain.cancelScheduledValues(j),ee.gainNode.gain.setValueAtTime(ee.gainNode.gain.value,j),ee.gainNode.gain.linearRampToValueAtTime(0,j+Qo),ee.oscillator.stop(j+Qo+.05),p.delete(F)}function W(){for(const F of Array.from(p.keys()))Y(F)}function K(){if(r!=="playing"||!l)return;const F=l.currentTime-d;if(g=Math.min(F/o,1),g>=1){C();return}const ee=f+g*v;for(const j of M){const J=ee>=j.startMs&&ee<j.endMs,se=p.has(j.id);J&&!se?N(j):!J&&se&&Y(j.id)}Z(),y=requestAnimationFrame(K)}function q(){$(),x(),l&&(O(),r==="paused"?d=l.currentTime-b*o:(d=l.currentTime,g=0),r="playing",_(),B(),y=requestAnimationFrame(K))}function U(){r==="playing"&&(r="paused",b=g,W(),cancelAnimationFrame(y),_())}function C(){r="stopped",g=0,b=0,W(),cancelAnimationFrame(y),_(),Q()}function P(){r==="playing"?U():q()}function A(F){const ee=Gn(F).getTime(),j=Math.max(0,Math.min((ee-f)/v,1));r==="playing"&&l?d=l.currentTime-j*o:(b=j,g=j)}function _(){E&&(r==="playing"?(E.innerHTML=ge(),E.classList.add("ng-son-btn--active")):(E.innerHTML=re(),E.classList.remove("ng-son-btn--active")))}function B(){w&&w.classList.remove("ng-hidden")}function Q(){w&&w.classList.add("ng-hidden")}function Z(){if(!c||!h||!S||!k)return;c.getByteFrequencyData(h);const F=k.width,ee=k.height;S.clearRect(0,0,F,ee);const j=S.createLinearGradient(0,0,0,ee);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),S.fillStyle=j,S.fillRect(0,0,F,ee);const J=F/tn*.8,se=F/tn*.2,de=Math.floor(h.length/tn);for(let ie=0;ie<tn;ie++){let fe=0;for(let G=0;G<de;G++)fe+=h[ie*de+G]??0;const ce=fe/de,ye=ce/255*ee*.85,Te=ie*(J+se),X=ee-ye,L=30+ce/255*15,H=55+ce/255*15;S.fillStyle=`hsl(${L}, 90%, ${H}%)`,S.fillRect(Te,X,J,ye)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function me(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(F){a=F,qc(),I.push(F.on("sonification:play",()=>q())),I.push(F.on("sonification:pause",()=>U())),I.push(F.on("sonification:stop",()=>C())),I.push(F.on("sonification:scrub",(...ee)=>{const j=typeof ee[0]=="string"?ee[0]:void 0;j&&A(j)})),I.push(F.on("sonification:configure",(...ee)=>{const j=ee[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(F,ee,j){if(r==="stopped"||!a)return;const{headerHeight:J}=ee.config,se=ee.scrollX,de=ee.scrollY,ie=J,fe=a.getTimeScale(),ce=f+g*v,ye=new Date(ce),Te=fe.dateToX(ye);F.save(),F.beginPath(),F.rect(0,ie,F.canvas.width,F.canvas.height-ie),F.clip(),F.translate(-se,0),F.save(),F.shadowColor=Xn,F.shadowBlur=ei,F.strokeStyle=Xn,F.lineWidth=Vc,F.beginPath(),F.moveTo(Te,ie),F.lineTo(Te,F.canvas.height+de),F.stroke(),F.restore();const X=new Map;for(const L of j)X.set(L.taskId,L);for(const L of p.values()){const H=X.get(L.taskId);if(!H)continue;const G=H.x,z=H.barY-de,V=H.width,te=H.barHeight;if(z+te<ie||z>F.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);F.save(),F.globalAlpha=ae,F.shadowColor=Kc,F.shadowBlur=ei,F.fillStyle=Xn;const le=Math.min(ee.config.theme.barBorderRadius,V/2,te/2);F.beginPath(),F.moveTo(G+le,z),F.lineTo(G+V-le,z),F.arcTo(G+V,z,G+V,z+le,le),F.lineTo(G+V,z+te-le),F.arcTo(G+V,z+te,G+V-le,z+te,le),F.lineTo(G+le,z+te),F.arcTo(G,z+te,G,z+te-le,le),F.lineTo(G,z+le),F.arcTo(G,z,G+le,z,le),F.closePath(),F.fill(),F.restore()}F.restore()},renderDOM(F,ee){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=re(),E.title="Play / Pause",E.addEventListener("click",()=>P()),m.appendChild(E),D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=me(),D.title="Stop",D.addEventListener("click",()=>C()),m.appendChild(D);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const J=document.createElement("div");J.style.display="flex",J.style.flexDirection="column",J.style.alignItems="center",J.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",J.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),J.appendChild(de),m.appendChild(J);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const H of Object.keys(Yn)){const G=document.createElement("option");G.value=H,G.textContent=H.charAt(0).toUpperCase()+H.slice(1),H===n&&(G.selected=!0),ce.appendChild(G)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const ye=document.createElement("div");ye.className="ng-son-sep",m.appendChild(ye);const Te=document.createElement("div");Te.style.display="flex",Te.style.flexDirection="column",Te.style.alignItems="center",Te.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",Te.appendChild(X);const L=document.createElement("input");L.type="range",L.className="ng-son-slider",L.min="0",L.max="100",L.value=String(Math.round(i*100)),L.addEventListener("input",()=>{i=Number(L.value)/100,u&&(u.gain.value=i)}),Te.appendChild(L),m.appendChild(Te),F.appendChild(m)}if(!w){w=document.createElement("div"),w.className="ng-sonification-waveform ng-hidden",k=document.createElement("canvas"),S=k.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,J=F.getBoundingClientRect();k.width=J.width*j,k.height=Wn*j,k.style.width="100%",k.style.height=Wn+"px",S&&S.scale(j,j),w.appendChild(k),F.appendChild(w)}},destroy(){for(const F of I)F();I.length=0,C(),W(),l&&(l.close(),l=null),u=null,c=null,h=null,m&&(m.remove(),m=null),w&&(w.remove(),w=null),k=null,S=null,E=null,D=null,Zc(),a=null,M=[],R=[]}}}return ne.BaselinePlugin=ya,ne.CLOUD_NIMBUS_PRIORITY_BUCKETS=ea,ne.ConfigPanelPlugin=dl,ne.CriticalPathPlugin=ra,ne.DARK_THEME=cs,ne.DarkThemePlugin=Pa,ne.DependencyRenderer=as,ne.EventBus=Kn,ne.ExportPlugin=ka,ne.GroupingPlugin=qi,ne.HeatmapViewPlugin=Sl,ne.HitTest=os,ne.KeyboardPlugin=Pi,ne.LIGHT_THEME=rn,ne.LayoutEngine=Qn,ne.MSProjectPlugin=ja,ne.MilestonePlugin=Bi,ne.MiniMapPlugin=_l,ne.MonteCarloPlugin=vc,ne.MotionControlPlugin=Wa,ne.NarrativePlugin=Lc,ne.NetworkGraphPlugin=ol,ne.NimbusGantt=Ii,ne.PriorityGroupingPlugin=Qi,ne.ResourceLevelingPlugin=fr,ne.RiskAnalysisPlugin=Fr,ne.SonificationPlugin=Jc,ne.SplitTaskPlugin=ir,ne.TelemetryPlugin=Fa,ne.TimeScale=Zn,ne.TimeTravelPlugin=rc,ne.TimelineNotesPlugin=ql,ne.TooltipManager=ls,ne.UndoRedoPlugin=Li,ne.VirtualScrollPlugin=Sa,ne.WhatIfPlugin=Yc,ne.WorkCalendarPlugin=Ha,ne.computeCPM=un,ne.exportMSProjectXML=vn,ne.getAllParentIds=gs,ne.getDescendantIds=hs,ne.hoursWeightedProgress=ta,ne.importMSProjectXML=bn,ne.parseDate=gt,ne.resolveConfig=ds,ne.rollupHoursDeduped=Mi,Object.defineProperty(ne,Symbol.toStringTag,{value:"Module"}),ne})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
