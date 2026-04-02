var NimbusGantt=(function(se){"use strict";function We(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(u);d||(d=[],n.set(u,d)),d.push(l)}const s=[];function o(l,u){const d=l.sortOrder??Number.MAX_SAFE_INTEGER,g=u.sortOrder??Number.MAX_SAFE_INTEGER;return d!==g?d-g:l.name.localeCompare(u.name)}function i(l,u,d){const g=n.get(l);return g?(g.sort(o),g.map(p=>{const c=n.has(p.id)&&t.has(p.id),f=d,y={task:p,children:[],depth:u,expanded:c,visible:f,rowIndex:-1};return f&&(y.rowIndex=s.length,s.push(p.id)),y.children=i(p.id,u+1,f&&c),y})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function dt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class Gn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Zo(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Zo(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=We(n,e.expandedIds),a=dt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=We(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=We(n,e.expandedIds),i=dt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=We(n,e.expandedIds),i=dt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=We(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=We(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=We(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=dt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}class Vn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const en=864e5,Jo=en*7,Qo={day:40,week:120,month:180,quarter:200},jn=["January","February","March","April","May","June","July","August","September","October","November","December"],Kn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class qn{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=Qo[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/en)}countWeeks(){return Math.ceil(this.totalMs/Jo)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=Zn(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=tn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${jn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=Zn(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${Kn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=tn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),d=this.dateToX(l);t.push({label:`${jn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:d-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:Kn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=tn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),g=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:g-d,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=ei(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),g=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:g-d,date:new Date(l)}),i=a}return[t,n]}}function Zn(e,t){return new Date(e.getTime()+t*en)}function ei(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function tn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class Jn{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const d=nn(u.startDate),g=nn(u.endDate),p=s.dateToX(d),r=s.dateToX(g)-p,c=Math.max(r,o.minBarWidth),f=a*o.rowHeight,y=f+(o.rowHeight-o.barHeight)/2,T=c*(u.progress||0),h=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:f,width:c,barY:y,barHeight:o.barHeight,progressWidth:T,color:h,textColor:o.theme.barTextColor,label:u.name,isMilestone:u.isMilestone||!1})}return i}}function nn(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const sn=864e5,Qn=1,ti=2,ni=.5,si=2,es=8,oi=6,ts=2;class ii{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:d}=u,g=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=u.headerHeight,f=a-c;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,f),o.clip(),o.translate(-g,0),u.showWeekends&&this.renderWeekendShading(t,s,c,f,d),this.renderGridLines(s,c,f,d,g),this.renderAltRows(t,n,c,d,g,p);const y=this.getTodayX(t,u,s);u.showToday&&y!==null&&this.renderTodayBackground(y,s,c,f,d),this.renderTaskBars(t,n,u,d,g,p,c,f),u.showToday&&y!==null&&this.renderTodayLine(y,c,f,d),o.restore(),this.renderHeader(s,u,d,g)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const d=l.getTime();for(;u.getTime()<=d;){const g=u.getUTCDay();if(g===0||g===6){const p=n.dateToX(u),r=new Date(u.getTime()+sn),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}u.setTime(u.getTime()+sn)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=ni;for(const u of l){const d=this.snapToPixel(u);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,d=t.config.rowHeight,g=t.flatVisibleIds.length;for(let p=0;p<g;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+sn),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:d}=this,g=o.barBorderRadius;for(const p of n){const r=p.x,c=p.barY-a+l,f=p.width,y=p.barHeight;if(!(c+y<l||c>l+u)){if(p.isMilestone){this.renderMilestone(r,c,y,p.color,o,t.selectedIds.has(p.taskId));continue}if(this.fillRoundedRect(r,c,f,y,g,p.color),s.showProgress&&p.progressWidth>0){const T=this.darkenColor(p.color,.2);d.save(),d.beginPath(),this.roundedRectPath(r,c,f,y,g),d.clip(),d.fillStyle=T,d.fillRect(r,c,p.progressWidth,y),d.restore()}t.selectedIds.has(p.taskId)&&this.strokeRoundedRect(r,c,f,y,g,o.barSelectedBorder,ts),this.renderBarLabel(p,r,c,f,y,o)}}}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-si*2)/2,d=n+s/2;l.save(),l.beginPath(),l.moveTo(t,d-u),l.lineTo(t+u,d),l.lineTo(t,d+u),l.lineTo(t-u,d),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=ts,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const d=l.measureText(t.label).width,g=s+i/2;d+es*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+es,g)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+oi,g)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=ti,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const d=u.length||2,g=l/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<u.length;c++){const f=u[c],y=c*g;for(const T of f){const h=T.x-o,b=T.width;if(h+b<0||h>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=Qn;const v=this.snapToPixelRaw(h+b);i.moveTo(v,y),i.lineTo(v,y+g),i.stroke(),i.save(),i.beginPath(),i.rect(h,y,b,g),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(T.label,h+b/2,y+g/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=Qn,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const ns="ng-tree-grid-styles";function ai(e,t){const n=e.querySelector(`#${ns}`);n&&n.remove();const s=document.createElement("style");s.id=ns,s.textContent=`
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
  `,e.prepend(s)}function ri(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Dt(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class li{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;ai(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=ri(n),u=l.map(d=>d.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,u.appendChild(d);const g=document.createElement("span");g.className="ng-resize-handle",u.appendChild(g),this.attachResizeListener(g,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=d=>{const g=d.clientX-o,p=Math.max(a,i+g);this.columnWidths[n]=p;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),c[n]&&(c[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const d of t)l.set(d.task.id,d);for(const[d,g]of this.rows)a.has(d)||(g.remove(),this.rows.delete(d));let u=null;for(let d=0;d<t.length;d++){const g=t[d],p=g.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,g,d,s):(r=this.createRow(g,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const d=this.createCell(t,u,s);l.appendChild(d)}return l}createCell(t,n,s){const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const i=t.depth*20+8;if(o.style.paddingLeft=`${i}px`,t.children.length>0){const l=document.createElement("span");l.className="ng-expand-icon",t.expanded&&l.classList.add("ng-expanded"),l.innerHTML="&#9654;",l.setAttribute("data-expand",t.task.id),o.appendChild(l)}else{const l=document.createElement("span");l.className="ng-expand-spacer",o.appendChild(l)}const a=document.createElement("span");a.className="ng-grid-cell-text",a.textContent=Dt(t.task,n),o.appendChild(a)}else o.textContent=Dt(t.task,n);return o}updateRowContent(t,n,s,o){const{config:i}=o,{columns:a}=i;s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt"),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let u=0;u<a.length;u++){const d=a[u],g=l[u];if(!g){const p=this.createCell(n,d,o);t.appendChild(p);continue}if(d.tree){const p=n.depth*20+8;g.style.paddingLeft=`${p}px`;const r=g.querySelector(".ng-expand-icon"),c=g.querySelector(".ng-expand-spacer");if(n.children.length>0)if(r)n.expanded?r.classList.add("ng-expanded"):r.classList.remove("ng-expanded");else{c&&c.remove();const y=document.createElement("span");y.className="ng-expand-icon",n.expanded&&y.classList.add("ng-expanded"),y.innerHTML="&#9654;",y.setAttribute("data-expand",n.task.id),g.insertBefore(y,g.firstChild)}else if(r){r.remove();const y=document.createElement("span");y.className="ng-expand-spacer",g.insertBefore(y,g.firstChild)}const f=g.querySelector(".ng-grid-cell-text");if(f){const y=Dt(n.task,d);f.textContent!==y&&(f.textContent=y)}}else{const p=Dt(n.task,d);g.textContent!==p&&(g.textContent=p)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class ci{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class ss{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const os=864e5;function on(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/os)}function ut(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function st(e,t){const n=ut(e),s=new Date(n.getTime()+t*os),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function di(e,t,n){return Math.max(t,Math.min(n,e))}const ui=3,gi=300;class hi{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=t,this.options=n,this.hitTest=new ss,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none")return;t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l&&(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(t.pointerId),this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly)){const u=fi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s})}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<ui?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<gi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var l,u,d,g,p,r,c,f;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale();n.config;const i=this.dragHit.type,a=t.clientX-this.dragStartX;switch(i){case"bar":{const y=on(a,o),T=st(this.dragOriginalStartDate,y),h=st(this.dragOriginalEndDate,y);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:T,endDate:h}),(u=(l=this.options).onTaskMove)==null||u.call(l,s,T,h);break}case"bar-left-edge":{const y=on(a,o),T=st(this.dragOriginalStartDate,y),h=ut(this.dragOriginalEndDate),v=ut(T).getTime()>=h.getTime()?st(this.dragOriginalEndDate,-1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:v,endDate:this.dragOriginalEndDate}),(g=(d=this.options).onTaskResize)==null||g.call(d,s,v,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=on(a,o),T=st(this.dragOriginalEndDate,y),h=ut(this.dragOriginalStartDate),v=ut(T).getTime()<=h.getTime()?st(this.dragOriginalStartDate,1):T;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:v}),(r=(p=this.options).onTaskResize)==null||r.call(p,s,this.dragOriginalStartDate,v);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:T}=this.toCanvasCoords(t),h=T-y.x,b=di(h/y.width,0,1),v=Math.round(b*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:v}}),(f=(c=this.options).onTaskProgressChange)==null||f.call(c,s,v);break}}this.options.dispatch({type:"DRAG_END"})}}function fi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const ot=12,kt=6,Ct=4,pi=3;class is{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const g=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,g,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const c=d.get(r.source),f=d.get(r.target);if(!c||!f)continue;const y=r.type||"FS",{sourceX:T,sourceY:h,targetX:b,targetY:v}=this.getConnectionPoints(y,c,f,a,l);this.drawRoutedPath(t,y,T,h,b,v,o),this.drawArrowhead(t,y,b,v,o),this.drawConnectionDot(t,T,h,o),this.drawConnectionDot(t,b,v,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",d=n==="FS"||n==="SS",g=u?s+ot:s-ot,p=d?i-ot:i+ot;if(u?d?p>=g:i+ot>=g:d?i-ot<=g:p<=g)t.lineTo(g,o),t.lineTo(g,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(g,o),t.lineTo(g,c),t.lineTo(p,c),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-kt,o-Ct),t.lineTo(s-kt,o+Ct)):(t.moveTo(s,o),t.lineTo(s+kt,o-Ct),t.lineTo(s+kt,o+Ct)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,pi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Mt=12,mi=100,Ti=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],yi=`
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
`;function it(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function as(e){const t=e.split("-");if(t.length!==3)return it(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?it(e):`${Ti[n]} ${s}`}function gt(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${it(e)}</span><span class="ng-tooltip-value">${it(t)}</span></div>`}function bi(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=gt("Status",e.status||"None"),i+=gt("Assignee",e.assignee||"Unassigned"),i+=gt("Dates",`${as(e.startDate)} → ${as(e.endDate)}`),n>0&&(i+=gt("Progress",`${n}%`)),s!=null&&(i+=gt("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${it(t)}"><span class="ng-tooltip-name">${it(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class rs{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=yi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const d=this.customRenderer(t);typeof d=="string"?this.tooltipEl.innerHTML=d:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(d))}else this.tooltipEl.innerHTML=bi(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+Mt,u=s+Mt;l+i.width>a.width&&(l=n-Mt-i.width),u+i.height>a.height&&(u=s-Mt-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},mi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const an={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},ls={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},vi=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function cs(e){const t=wi(e.theme);return{columns:e.columns??vi,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function wi(e){return!e||e==="light"?{...an}:e==="dark"?{...ls}:{...an,...e}}const ds="nimbus-gantt-root-styles";function Si(){if(typeof document>"u"||document.getElementById(ds))return;const e=document.createElement("style");e.id=ds,e.textContent=`
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
  `,document.head.appendChild(e)}class Ei{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.renderScheduled=!1,this.destroyed=!1,this.container=t,this.config=cs(n),Si(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const g of n.tasks)s.set(g.id,g);const o=new Map;if(n.dependencies)for(const g of n.dependencies)o.set(g.id,g);const i=new Set,{tree:a,flatIds:l}=We(s,i),u=dt(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new Vn,this.store=new Gn(d),this.layoutEngine=new Jn,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new ii(this.timelinePanel),this.treeGrid=new li(this.gridPanel),this.scrollManager=new ci(this.timelinePanel,(g,p)=>{this.store.dispatch({type:"SET_SCROLL",x:g,y:p})}),this.dependencyRenderer=new is,this.tooltipManager=new rs(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const g=this.timelinePanel.querySelector("canvas");g&&(this.dragManager=new hi(g,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,c,f)=>{p?this.tooltipManager.show(p,r,c,f):this.tooltipManager.hide()},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight}))}this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((g,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:g,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(g))}),this.treeGrid.onRowDblClick(g=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(g))}),this.treeGrid.onExpandToggle(g=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:g})}),this.wireCallbacks(n),this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container),this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const d=u.getContext("2d");d&&l.renderCanvas(d,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){this.destroyed=!0,this.resizeObserver.disconnect(),this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new qn(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()})}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new Gn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}const Di=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function rn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function ki(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function d(c){s.push(c),s.length>t&&s.shift()}function g(){if(!n||s.length===0)return;const c=rn(n.getState()),f=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const c=rn(n.getState()),f=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),p()):(c.preventDefault(),g()))}return{name:"UndoRedoPlugin",install(c){n=c,u=c.on("render",()=>{if(l)return;const f=document.querySelector(".nimbus-gantt");f&&(l=f.parentElement??f,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,f){if(i){f(c);return}if(Di.has(c.type)&&n){const y=rn(n.getState());d(y),o=[]}f(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const ht=["day","week","month","quarter"];function Ci(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function ln(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Mi(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=Ci(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d>0&&e.dispatch({type:"SELECT_TASK",taskId:l[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[d+1]})}break}case"ArrowRight":{if(u)if(ln(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(u)if(ln(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!u)return;i.preventDefault();const d=a.tasks.get(u);if(d&&n){const g=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(g)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const g=a.tasks.get(u);if(g&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:g,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const d=l[l.length-1],g=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,g-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=ht.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:ht[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=ht.indexOf(a.zoomLevel);d<ht.length-1&&e.dispatch({type:"SET_ZOOM",level:ht[d+1]});break}case" ":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;ln(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const us="#D4A017",Ii="rgba(212, 160, 23, 0.25)",Ai=[6,4],Li=1,Ri=2,Pi=4,gs=8,hs=10,fs=16,$i=6;function _i(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const g=u,p=t.canvas.height/(window.devicePixelRatio||1)-g;t.beginPath(),t.rect(0,g,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const c=r.x,f=r.barY-a,y=r.barHeight,T=f+y/2,h=r.color===l.barDefaultColor?us:r.color||us;t.save(),t.beginPath(),t.strokeStyle=Ii,t.lineWidth=Li,t.setLineDash(Ai),t.moveTo(c,g),t.lineTo(c,g+p),t.stroke(),t.setLineDash([]),t.restore();const b=(y-Ri*2)/2;t.save(),t.beginPath(),t.moveTo(c,T-b),t.lineTo(c+b,T),t.lineTo(c,T+b),t.lineTo(c-b,T),t.closePath(),t.fillStyle=h,t.fill(),t.strokeStyle=ps(h,.25),t.lineWidth=1,t.stroke(),t.restore();const v=c+b+Pi,m=T-fs/2;if(t.save(),t.beginPath(),t.strokeStyle=ps(h,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+fs),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+gs,m+hs/2),t.lineTo(v,m+hs),t.closePath(),t.fillStyle=h,t.fill(),t.restore(),r.label){const D=v+gs+$i,k=T;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,D,k),t.restore()}}t.restore()},destroy(){e=null}}}function ps(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Ni="rgba(100, 116, 139, 0.12)",Oi="rgba(100, 116, 139, 0.25)",ms="#334155",Hi="rgba(100, 116, 139, 0.2)",xi="#475569",Bi=8,Fi=6,Yi=2,Xe=5,Ui=12,Wi=28,Xi=8;function zi(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(g){const p=new Map,r=[];for(const c of g.flatVisibleIds){const f=g.tasks.get(c);if(f)if(f.groupId){let y=p.get(f.groupId);y||(y={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,y)),y.taskIds.push(c)}else r.push(c)}n=Array.from(p.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const f=o.length,y=`__group_header__${c.groupId}`;if(o.push(y),s.set(f,c),!c.collapsed)for(const T of c.taskIds)o.push(T)}}function d(g){if(t.has(g)?t.delete(g):t.add(g),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(g){e=g,l=g.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const c=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const y=f.getBoundingClientRect(),T=r.clientY-y.top,h=c.config.headerHeight;if(T<h)return;const b=T-h+c.scrollY,v=Math.floor(b/c.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),d(m.groupId))},a.addEventListener("click",i))})},middleware(g,p){if(p(g),!e)return;const r=e.getState();let c=!1;for(const f of r.tasks.values())if(f.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const f=new Set;for(const y of n)if(y.collapsed)for(const T of y.taskIds)f.add(T);if(f.size>0){const y=r.flatVisibleIds.filter(T=>!f.has(T));if(y.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const T of y)r.flatVisibleIds.push(T)}}}},renderCanvas(g,p,r){if(!e||n.length===0)return;const{config:c,scrollX:f,scrollY:y}=p,{theme:T}=c,h=c.headerHeight,b=c.rowHeight,v=g.canvas.width/(window.devicePixelRatio||1),m=g.canvas.height/(window.devicePixelRatio||1)-h;g.save(),g.beginPath(),g.rect(0,h,v,m),g.clip();let D=0;const k=[];for(const w of p.flatVisibleIds){const E=p.tasks.get(w);E&&!E.groupId&&k.push(w)}D=k.length;for(const w of n){const E=h+D*b-y;if(E+b>=h&&E<h+m){g.fillStyle=Ni,g.fillRect(0,E,v,b),g.beginPath(),g.strokeStyle=Oi,g.lineWidth=1,g.moveTo(0,Math.round(E+b)+.5),g.lineTo(v,Math.round(E+b)+.5),g.stroke();const S=Ui,M=E+b/2;g.save(),g.beginPath(),g.fillStyle=ms,w.collapsed?(g.moveTo(S,M-Xe),g.lineTo(S+Xe,M),g.lineTo(S,M+Xe)):(g.moveTo(S-Xe/2,M-Xe/2),g.lineTo(S+Xe/2,M-Xe/2),g.lineTo(S,M+Xe/2)),g.closePath(),g.fill(),g.restore(),g.save(),g.font=`600 ${T.fontSize}px ${T.fontFamily}`,g.textBaseline="middle",g.textAlign="left",g.fillStyle=ms;const I=Wi,R=E+b/2;g.fillText(w.groupName,I,R);const _=g.measureText(w.groupName).width;g.restore();const x=`${w.taskIds.length}`;g.save(),g.font=`${T.fontSize-1}px ${T.fontFamily}`;const N=g.measureText(x).width+Fi*2,Y=T.fontSize+Yi*2,W=I+_+Xi,j=R-Y/2;g.beginPath();const q=Bi;g.moveTo(W+q,j),g.lineTo(W+N-q,j),g.arcTo(W+N,j,W+N,j+q,q),g.lineTo(W+N,j+Y-q),g.arcTo(W+N,j+Y,W+N-q,j+Y,q),g.lineTo(W+q,j+Y),g.arcTo(W,j+Y,W,j+Y-q,q),g.lineTo(W,j+q),g.arcTo(W,j,W+q,j,q),g.closePath(),g.fillStyle=Hi,g.fill(),g.fillStyle=xi,g.textBaseline="middle",g.textAlign="center",g.fillText(x,W+N/2,R),g.restore()}D+=1,w.collapsed||(D+=w.taskIds.length)}g.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const Ts=864e5,Gi=6,Vi=2,ji=2,Ki=.18,qi=.4;function ys(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function cn(e,t){return Math.round((t.getTime()-e.getTime())/Ts)}function at(e,t){return new Date(e.getTime()+t*Ts)}function dn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const S of n)s.set(S,[]),o.set(S,[]),i.set(S,0);for(const S of t.values()){if((S.type||"FS")!=="FS"||!e.has(S.source)||!e.has(S.target))continue;const I=S.lag||0;s.get(S.source).push({target:S.target,lag:I,depId:S.id}),o.get(S.target).push({source:S.source,lag:I,depId:S.id}),i.set(S.target,(i.get(S.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[S,M]of e){const I=ys(M.startDate),R=ys(M.endDate);l.set(S,I),u.set(S,R),a.set(S,Math.max(cn(I,R),0))}const d=new Map,g=new Map,p=[],r=[],c=new Map(i);for(const S of n)c.get(S)===0&&(r.push(S),d.set(S,l.get(S)),g.set(S,u.get(S)));for(;r.length>0;){const S=r.shift();p.push(S),d.get(S);const M=g.get(S);for(const I of s.get(S)){const{target:R,lag:_}=I,x=at(M,_),O=d.get(R);(!O||x.getTime()>O.getTime())&&(d.set(R,x),g.set(R,at(x,a.get(R))));const N=c.get(R)-1;c.set(R,N),N===0&&r.push(R)}}for(const S of n)d.has(S)||(d.set(S,l.get(S)),g.set(S,u.get(S)),p.push(S));let f=-1/0;for(const S of g.values())S.getTime()>f&&(f=S.getTime());const y=new Date(f);let T=1/0;for(const S of d.values())S.getTime()<T&&(T=S.getTime());const h=new Date(T),b=cn(h,y),v=new Map,m=new Map;for(const S of n)s.get(S).length===0&&(m.set(S,y),v.set(S,at(y,-a.get(S))));for(let S=p.length-1;S>=0;S--){const M=p[S];if(!m.has(M)){let I=1/0;for(const R of s.get(M)){const _=v.get(R.target);if(_){const x=at(_,-R.lag);x.getTime()<I&&(I=x.getTime())}}I===1/0?m.set(M,y):m.set(M,new Date(I)),v.set(M,at(m.get(M),-a.get(M)))}}for(const S of n)m.has(S)||(m.set(S,y),v.set(S,at(y,-a.get(S))));const D=.5,k=new Set,w=new Map;for(const S of n){const M=d.get(S),I=g.get(S),R=v.get(S),_=m.get(S),x=cn(M,R),O=Math.abs(x)<D;O&&k.add(S),w.set(S,{earlyStart:M,earlyFinish:I,lateStart:R,lateFinish:_,totalFloat:x,isCritical:O})}const E=new Set;for(const S of t.values())(S.type||"FS")==="FS"&&k.has(S.source)&&k.has(S.target)&&E.add(S.id);return{criticalTaskIds:k,criticalDependencyIds:E,taskAnalysis:w,projectDuration:b}}function Zi(){let e,t=null,n=[];function s(){const o=e.getState();t=dn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:d,barHeight:g}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,f=u,y=e.getTimeScale(),T=new Map;for(const m of a)T.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const m of a){const D=t.taskAnalysis.get(m.taskId);if(!D||D.isCritical||D.totalFloat<=0)continue;const k=m.barY-c,w=g*qi,E=m.x+m.width,M=y.dateToX(D.lateFinish)-E;M>1&&(o.fillStyle=m.color,o.globalAlpha=Ki,o.fillRect(E,k+g-w,M,w),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const D=m.x,k=m.barY-c,w=m.width,E=m.barHeight;if(!(k+E<f||k>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Gi;for(let S=0;S<Vi;S++){o.strokeStyle=p,o.lineWidth=ji,o.beginPath();const M=l.barBorderRadius,I=Math.min(M,w/2,E/2);o.moveTo(D+I,k),o.lineTo(D+w-I,k),o.arcTo(D+w,k,D+w,k+I,I),o.lineTo(D+w,k+E-I),o.arcTo(D+w,k+E,D+w-I,k+E,I),o.lineTo(D+I,k+E),o.arcTo(D,k+E,D,k+E-I,I),o.lineTo(D,k+I),o.arcTo(D,k,D+I,k,I),o.closePath(),o.stroke()}o.restore()}}const h=6,b=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const D=T.get(m.source),k=T.get(m.target);if(!D||!k)continue;const w=D.x+D.width,E=D.barY+D.barHeight/2-c,S=k.x,M=k.barY+k.barHeight/2-c;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const I=w+v,R=S-v;if(o.moveTo(w,E),R>=I)o.lineTo(I,E),o.lineTo(I,M),o.lineTo(S,M);else{const _=(E+M)/2;o.lineTo(I,E),o.lineTo(I,_),o.lineTo(R,_),o.lineTo(R,M),o.lineTo(S,M)}o.stroke(),o.beginPath(),o.moveTo(S,M),o.lineTo(S-h,M-b),o.lineTo(S-h,M+b),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Ji=864e5,Qi=.6,bs=.25,ea="#38A169",ta="#E53E3E",na="#A0AEC0",sa=10,oa=4,ze=16,ia=3;function It(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function aa(e,t){return Math.round((t.getTime()-e.getTime())/Ji)}function ra(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:It(s.startDate),end:It(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var y,T;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,d=o.scrollX,g=o.scrollY,p=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const f=u*Qi;for(const h of i){if(h.isMilestone)continue;const b=t.get(h.taskId);if(!b)continue;const v=h.barY-g;if(v+u+f<p||v>s.canvas.height)continue;const m=r.dateToX(b.start),D=r.dateToX(b.end),k=Math.max(D-m,2),w=v+u+1;It(((y=o.tasks.get(h.taskId))==null?void 0:y.startDate)||"");const E=It(((T=o.tasks.get(h.taskId))==null?void 0:T.endDate)||""),S=aa(b.end,E);let M;S<0?M=ea:S>0?M=ta:M=na,s.save(),s.globalAlpha=bs,s.fillStyle=M;const I=Math.min(c,k/2,f/2);if(s.beginPath(),s.moveTo(m+I,w),s.lineTo(m+k-I,w),s.arcTo(m+k,w,m+k,w+I,I),s.lineTo(m+k,w+f-I),s.arcTo(m+k,w+f,m+k-I,w+f,I),s.lineTo(m+I,w+f),s.arcTo(m,w+f,m,w+f-I,I),s.lineTo(m,w+I),s.arcTo(m,w,m+I,w,I),s.closePath(),s.fill(),s.globalAlpha=bs*2,s.strokeStyle=M,s.lineWidth=1,s.stroke(),s.restore(),S!==0){const R=S>0?`+${S}d`:`${S}d`;s.save(),s.font=`600 ${sa}px ${a.fontFamily}`;const O=s.measureText(R).width+oa*2,N=h.x+h.width+4,Y=w+(f-ze)/2;s.globalAlpha=.85,s.fillStyle=M;const W=ia;s.beginPath(),s.moveTo(N+W,Y),s.lineTo(N+O-W,Y),s.arcTo(N+O,Y,N+O,Y+W,W),s.lineTo(N+O,Y+ze-W),s.arcTo(N+O,Y+ze,N+O-W,Y+ze,W),s.lineTo(N+W,Y+ze),s.arcTo(N,Y+ze,N,Y+ze-W,W),s.lineTo(N,Y+W),s.arcTo(N,Y,N+W,Y,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(R,N+O/2,Y+ze/2),s.restore()}}s.restore()},destroy(){}}}const vs=5,la=5,ca=.3,da=15;function ua(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:g,headerHeight:p}=d.config,r=d.scrollY,c=d.flatVisibleIds.length,f=a(d),y=Math.floor(r/g),T=Math.ceil((r+f)/g);let h=Math.max(0,y-vs),b=Math.min(c,T+vs);if(Math.abs(s)>0){const m=Math.min(da,Math.ceil(Math.abs(s*ca)/g));s>0?b=Math.min(c,b+m):h=Math.max(0,h-m)}const v=new Set;for(let m=h;m<b&&m<d.flatVisibleIds.length;m++)v.add(d.flatVisibleIds[m]);return{startRow:h,endRow:b,totalRows:c,visibleTaskIds:v}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function l(d){const g=performance.now();for(o.push({y:d,time:g});o.length>la;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],c=(r.time-p.time)/1e3;c>0&&(s=(r.y-p.y)/c)}n=d}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(l(d.scrollY),t=i(d)),t},filterLayouts(d){const g=u.getVisibleRange();return g.totalRows===0?[]:d.filter(p=>g.visibleTaskIds.has(p.taskId))},isVisible(d){return u.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,g){if(g(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const Oe=864e5,un=1,ws=2,Ss=.5,Es=2,At=8,Ds=6,ks=2,Lt=1e4;function gn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Cs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Qe(e){return Math.round(e)+.5}function Ms(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Is(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const c=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,c,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const g=t.flatVisibleIds;for(let p=0;p<g.length;p++){const r=t.tasks.get(g[p]);if(!r)continue;const c=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const y of a){const T=y.width??120,h=Ms(r,y.field);e.save(),e.beginPath(),e.rect(f,c,T,l),e.clip(),e.textBaseline="middle";const b=y.tree?8:0;e.textAlign=y.align==="right"?"right":y.align==="center"?"center":"left";const v=y.align==="right"?f+T-8:y.align==="center"?f+T/2:f+8+b;e.fillText(h,v,c+l/2),e.restore(),f+=T}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function As(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,d=s.getTotalWidth(),g=t.flatVisibleIds.length*u,p=l+g;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:f,end:y}=t.dateRange,T=new Date(f);T.setUTCHours(0,0,0,0);const h=y.getTime();for(;T.getTime()<=h;){const b=T.getUTCDay();if(b===0||b===6){const v=o+s.dateToX(T),m=new Date(T.getTime()+Oe),D=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,l,D-v,g)}T.setTime(T.getTime()+Oe)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Ss;for(const f of r){const y=Qe(o+f);e.moveTo(y,l),e.lineTo(y,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+f*u,d,u));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:y,end:T}=t.dateRange;if(f.getTime()>=y.getTime()&&f.getTime()<=T.getTime()){const h=o+s.dateToX(f),b=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(h,l,b,g),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=ws,e.moveTo(Qe(h),l),e.lineTo(Qe(h),p),e.stroke()}}const c=a.barBorderRadius;for(const f of n){const y=o+f.x,T=f.barY,h=f.width,b=f.barHeight;if(f.isMilestone){const v=(b-Es*2)/2,m=T+b/2;e.beginPath(),e.moveTo(y,m-v),e.lineTo(y+v,m),e.lineTo(y,m+v),e.lineTo(y-v,m),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(hn(e,y,T,h,b,c),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const v=Cs(f.color,.2);e.save(),e.beginPath(),hn(e,y,T,h,b,c),e.clip(),e.fillStyle=v,e.fillRect(y,T,f.progressWidth,b),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),hn(e,y,T,h,b,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=ks,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(f.label).width,m=T+b/2;v+At*2<=h?(e.beginPath(),e.rect(y,T,h,b),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,y+At,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,y+h+Ds,m)),e.restore()}}ga(e,t,n,a,o),ha(e,s,i,a,o)}function ga(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,l=6,u=4;e.save();for(const d of t.dependencies.values()){const g=i.get(d.source),p=i.get(d.target);if(!g||!p)continue;const r=d.type||"FS",c=g.barY+g.barHeight/2,f=p.barY+p.barHeight/2;let y,T;const h=r==="FS"||r==="FF",b=r==="FS"||r==="SS";switch(r){case"FS":y=o+g.x+g.width,T=o+p.x;break;case"SS":y=o+g.x,T=o+p.x;break;case"FF":y=o+g.x+g.width,T=o+p.x+p.width;break;case"SF":y=o+g.x,T=o+p.x+p.width;break}const v=h?y+a:y-a,m=b?T-a:T+a,D=h?b?m>=v:T+a>=v:b?T-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(y,c),D)e.lineTo(v,c),e.lineTo(v,f),e.lineTo(T,f);else{const k=(c+f)/2;e.lineTo(v,c),e.lineTo(v,k),e.lineTo(m,k),e.lineTo(m,f),e.lineTo(T,f)}e.stroke(),e.beginPath(),b?(e.moveTo(T,f),e.lineTo(T-l,f-u),e.lineTo(T-l,f+u)):(e.moveTo(T,f),e.lineTo(T+l,f-u),e.lineTo(T+l,f+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function ha(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let d=0;d<a.length;d++){const g=a[d],p=d*u;for(const r of g){const c=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=un,e.moveTo(Qe(c+f),p),e.lineTo(Qe(c+f),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(c,p,f,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+f/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=un,e.moveTo(o,Qe(i)),e.lineTo(o+t.getTotalWidth(),Qe(i)),e.stroke()}function hn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function ft(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function fa(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),d=s+u,g=e.flatVisibleIds.length*l,p=a+g,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),c.push(`<style>text { font-family: ${ft(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const m of o.columns){const D=m.width??120;c.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${ft(m.header)}</text>`),c.push(`<line x1="${f+D}" y1="0" x2="${f+D}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=D}for(let m=0;m<e.flatVisibleIds.length;m++){const D=e.tasks.get(e.flatVisibleIds[m]);if(!D)continue;const k=a+m*l;m%2===1&&c.push(`<rect x="0" y="${k}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let w=0;for(const E of o.columns){const S=E.width??120,M=Ms(D,E.field),I=E.tree?8:0;c.push(`<text x="${w+8+I}" y="${k+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${M}]]></text>`),w+=S}c.push(`<line x1="0" y1="${k+l}" x2="${s}" y2="${k+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const y=n.getHeaderRows(),T=y.length||2,h=a/T;for(let m=0;m<y.length;m++){const D=y[m],k=m*h;for(const w of D){const E=s+w.x+w.width/2,S=k+h/2,M=m===0?' font-weight="600"':"";c.push(`<text x="${E}" y="${S}" text-anchor="middle" dominant-baseline="central"${M} fill="${i.timelineHeaderText}">${ft(w.label)}</text>`),c.push(`<line x1="${s+w.x+w.width}" y1="${k}" x2="${s+w.x+w.width}" y2="${k+h}" stroke="${i.timelineGridColor}" stroke-width="${un}" />`)}}const b=n.getGridLines();for(const m of b)c.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Ss}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&c.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:D}=e.dateRange,k=new Date(m);for(k.setUTCHours(0,0,0,0);k.getTime()<=D.getTime();){if(k.getUTCDay()===0||k.getUTCDay()===6){const w=s+n.dateToX(k),E=new Date(k.getTime()+Oe),S=s+n.dateToX(E);c.push(`<rect x="${w}" y="${a}" width="${S-w}" height="${g}" fill="${i.timelineWeekendBg}" />`)}k.setTime(k.getTime()+Oe)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:D,end:k}=e.dateRange;if(m.getTime()>=D.getTime()&&m.getTime()<=k.getTime()){const w=s+n.dateToX(m),E=n.getColumnWidth();c.push(`<rect x="${w}" y="${a}" width="${E}" height="${g}" fill="${i.todayBg}" />`),c.push(`<line x1="${w}" y1="${a}" x2="${w}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${ws}" />`)}}for(const m of t){const D=s+m.x,k=m.barY,w=m.width,E=m.barHeight;if(m.isMilestone){const S=(E-Es*2)/2,M=k+E/2;c.push(`<polygon points="${D},${M-S} ${D+S},${M} ${D},${M+S} ${D-S},${M}" fill="${m.color}" />`);continue}if(c.push(`<rect x="${D}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const S=Cs(m.color,.2);c.push(`<clipPath id="clip-${m.taskId}"><rect x="${D}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${D}" y="${k}" width="${m.progressWidth}" height="${E}" fill="${S}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&c.push(`<rect x="${D}" y="${k}" width="${w}" height="${E}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${ks}" />`),m.label){const S=k+E/2;i.fontSize*.6*m.label.length+At*2<=w?c.push(`<text x="${D+At}" y="${S}" dominant-baseline="central" fill="${m.textColor}">${ft(m.label)}</text>`):c.push(`<text x="${D+w+Ds}" y="${S}" dominant-baseline="central" fill="${i.gridTextColor}">${ft(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const D=v.get(m.source),k=v.get(m.target);if(!D||!k)continue;const w=m.type||"FS",E=D.barY+D.barHeight/2,S=k.barY+k.barHeight/2;let M,I;const R=w==="FS"||w==="FF",_=w==="FS"||w==="SS";switch(w){case"FS":M=s+D.x+D.width,I=s+k.x;break;case"SS":M=s+D.x,I=s+k.x;break;case"FF":M=s+D.x+D.width,I=s+k.x+k.width;break;case"SF":M=s+D.x,I=s+k.x+k.width;break}const x=12,O=6,N=4,Y=R?M+x:M-x,W=_?I-x:I+x,j=R?_?W>=Y:I+x>=Y:_?I-x<=Y:W<=Y;let q;if(j)q=`M${M},${E} L${Y},${E} L${Y},${S} L${I},${S}`;else{const U=(E+S)/2;q=`M${M},${E} L${Y},${E} L${Y},${U} L${W},${U} L${W},${S} L${I},${S}`}c.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),_?c.push(`<polygon points="${I},${S} ${I-O},${S-N} ${I-O},${S+N}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${I},${S} ${I+O},${S-N} ${I+O},${S+N}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function pa(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:d,end:g}=l.dateRange,p=g.getTime()-d.getTime(),r=u.getColumnWidth(),c=l.zoomLevel;let f;switch(c){case"day":f=Math.round(p/Oe);break;case"week":f=Math.ceil(p/(Oe*7));break;case"month":{const T=d.getUTCFullYear(),h=d.getUTCMonth(),b=g.getUTCFullYear(),v=g.getUTCMonth();f=(b-T)*12+(v-h);break}case"quarter":{const T=d.getUTCFullYear(),h=Math.floor(d.getUTCMonth()/3),b=g.getUTCFullYear(),v=Math.floor(g.getUTCMonth()/3);f=(b-T)*4+(v-h);break}}const y=f*r;return{dateToX(T){return(T.getTime()-d.getTime())/p*y},getColumnWidth(){return r},getTotalWidth(){return y},getHeaderRows(){return ya(c,d,g,r,y)},getGridLines(){return this.getHeaderRows()[1].map(h=>h.x).filter(h=>h>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),g=n(),p=u.getTotalWidth(),r=g+p,c=l.flatVisibleIds.length*l.config.rowHeight,f=l.config.headerHeight+c,y=a??"gantt-export.png";if(r>Lt||f>Lt){o(l,d,u,g,r,f,y);return}const T=document.createElement("canvas");T.width=r,T.height=f;const h=T.getContext("2d");h&&(g>0&&Is(h,l,g,f),As(h,l,d,u,g),T.toBlob(b=>{b&&gn(b,y)},"image/png"))}function o(a,l,u,d,g,p,r){const c=Math.min(1,Lt/g,Lt/p),f=Math.ceil(g*c),y=Math.ceil(p*c),T=document.createElement("canvas");T.width=f,T.height=y;const h=T.getContext("2d");h&&(h.scale(c,c),d>0&&Is(h,a,d,p),As(h,a,l,u,d),T.toBlob(b=>{b&&gn(b,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),g=n(),p=fa(l,d,u,g),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});gn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const Ls=["January","February","March","April","May","June","July","August","September","October","November","December"],Rs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Ps(e,t){return new Date(e.getTime()+t*Oe)}function fn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function ma(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ta(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function ya(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Ta(l,t,i,o);switch(e){case"day":{const l=[],u=[],d=Math.round(i/Oe);let g=new Date(t);for(let r=0;r<d;r++)u.push({label:String(g.getUTCDate()),x:r*s,width:s,date:new Date(g)}),g=Ps(g,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=fn(p),c=a(p),f=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${Ls[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:c,width:f-c,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],d=Math.ceil(i/(Oe*7));for(let p=0;p<d;p++){const r=Ps(t,p*7);u.push({label:`${Rs[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let g=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;g.getTime()<n.getTime();){const p=fn(g),r=g.getTime()<t.getTime()?t:g,c=p.getTime()>n.getTime()?n:p;l.push({label:`${Ls[g.getUTCMonth()]} ${g.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),g=p}return[l,u]}case"month":{const l=[],u=[],d=t.getUTCFullYear(),g=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),c=(p-d)*12+(r-g);let f=new Date(Date.UTC(d,g,1));for(let T=0;T<c;T++)u.push({label:Rs[f.getUTCMonth()],x:T*s,width:s,date:new Date(f)}),f=fn(f);let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const T=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),h=y.getTime()<t.getTime()?t:y,b=T.getTime()>n.getTime()?n:T;l.push({label:String(y.getUTCFullYear()),x:a(h),width:a(b)-a(h),date:new Date(h)}),y=T}return[l,u]}case"quarter":{const l=[],u=[],d=t.getUTCFullYear(),g=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(p-d)*4+(r-g);let f=new Date(Date.UTC(d,g*3,1));for(let T=0;T<c;T++){const h=Math.floor(f.getUTCMonth()/3)+1;u.push({label:`Q${h}`,x:T*s,width:s,date:new Date(f)}),f=ma(f,3)}let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const T=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),h=y.getTime()<t.getTime()?t:y,b=T.getTime()>n.getTime()?n:T;l.push({label:String(y.getUTCFullYear()),x:a(h),width:a(b)-a(h),date:new Date(h)}),y=T}return[l,u]}default:return[[],[]]}}const ba={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},pn="nimbus-gantt-dark-theme-transition";function va(){if(typeof document>"u"||document.getElementById(pn))return;const e=document.createElement("style");e.id=pn,e.textContent=`
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
  `,document.head.appendChild(e)}function wa(){if(typeof document>"u")return;const e=document.getElementById(pn);e&&e.remove()}function Sa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const f={...c.config.theme,...ba};Object.assign(c.config.theme,f),s=!0,p()}function d(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,p()}function g(){s?d():u()}function p(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?u():d()}return{name:"DarkThemePlugin",install(c){n=c,va(),c.on("theme:toggle",()=>{g()}),c.on("theme:dark",()=>{u()}),c.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}wa(),n=null,o=null,i=null,a=null,s=!1}}}const Ae=864e5,Ea=[1,2,3,4,5],Da="rgba(128, 128, 128, 0.06)",ka="rgba(128, 128, 128, 0.04)",Ca="#f87171",pt=4;function mt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function $e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ma(e){const t=new Set((e==null?void 0:e.workDays)??Ea),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=$e(r);return t.has(c.getUTCDay())}function i(r){const c=mt(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=$e(r);for(c=new Date(c.getTime()+Ae);!i(c);)c=new Date(c.getTime()+Ae);return mt(c)}function l(r,c){if(c===0)return r;let f=$e(r);const y=c>0?1:-1;let T=Math.abs(c);if(!i(f))for(f=new Date(f.getTime()+y*Ae);!i(f);)f=new Date(f.getTime()+y*Ae);for(;T>0;)f=new Date(f.getTime()+y*Ae),i(f)&&T--;return mt(f)}function u(r,c){const f=$e(r),y=$e(c);if(f.getTime()>y.getTime())return-u(c,r);let T=0,h=new Date(f.getTime());for(;h.getTime()<y.getTime();)i(h)&&T++,h=new Date(h.getTime()+Ae);return T}function d(r,c="forward"){if(o(r))return r;let f=$e(r);const y=c==="forward"?Ae:-Ae;for(let T=0;T<30;T++)if(f=new Date(f.getTime()+y),i(f))return mt(f);return r}function g(r,c){if(r.type==="TASK_MOVE"){const f=d(r.startDate,"forward"),y=d(r.endDate,"backward"),T=$e(y).getTime()<$e(f).getTime()?f:y;c({...r,startDate:f,endDate:T});return}if(r.type==="TASK_RESIZE"){const f=d(r.startDate,"forward"),y=d(r.endDate,"backward"),T=$e(y).getTime()<$e(f).getTime()?f:y;c({...r,startDate:f,endDate:T});return}c(r)}function p(r,c,f){const{config:y}=c,T=y.headerHeight,h=c.flatVisibleIds.length*y.rowHeight,b=s==null?void 0:s.getTimeScale();if(!b||h===0)return;const{start:v,end:m}=c.dateRange,D=c.scrollX,k=c.scrollY;r.save();const w=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(w,0,0,w,0,0),r.beginPath(),r.rect(0,T,r.canvas.width/w,h),r.clip(),r.translate(-D,0);const E=new Date(v);E.setUTCHours(0,0,0,0);const S=m.getTime();for(b.getColumnWidth();E.getTime()<=S;){const M=mt(E),I=n.has(M),R=!t.has(E.getUTCDay());if(I||R){const _=b.dateToX(E),x=new Date(E.getTime()+Ae),N=b.dateToX(x)-_;if(r.fillStyle=Da,r.fillRect(_,T-k,N,h+k),R&&!I){r.save(),r.beginPath(),r.rect(_,T,N,h),r.clip(),r.strokeStyle=ka,r.lineWidth=1;const Y=8,W=h;for(let j=-W;j<N+W;j+=Y)r.beginPath(),r.moveTo(_+j,T),r.lineTo(_+j+W,T+W),r.stroke();r.restore()}}if(I){const _=b.dateToX(E),x=new Date(E.getTime()+Ae),O=b.dateToX(x),N=(_+O)/2;r.save(),r.setTransform(w,0,0,w,0,0),r.translate(-D,0);const Y=T-pt-3;r.beginPath(),r.moveTo(N,Y-pt),r.lineTo(N+pt,Y),r.lineTo(N,Y+pt),r.lineTo(N-pt,Y),r.closePath(),r.fillStyle=Ca,r.fill(),r.restore()}E.setTime(E.getTime()+Ae)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const f=c[0],y=c[1],T=c[2],h=l(f,y);T&&T(h)}),r.on("calendar:workDaysBetween",(...c)=>{const f=c[0],y=c[1],T=c[2],h=u(f,y);T&&T(h)}),r.on("calendar:isWorkDay",(...c)=>{const f=c[0],y=c[1],T=o(f);y&&y(T)}),r.on("calendar:nextWorkDay",(...c)=>{const f=c[0],y=c[1],T=a(f);y&&y(T)})},middleware:g,renderCanvas:p,destroy(){s=null}}}function Ia(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Aa(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function La(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=Ia(),a=[],l=Date.now();let u=null,d=null,g=!1,p=[];const r=[];function c(m,D){if(g)return;const k={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:D};a.push(k),o&&o(k)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function y(){d===null&&(d=setInterval(()=>{f()},s))}function T(){d!==null&&(clearInterval(d),d=null)}const h=Aa(()=>{if(!u)return;const m=u.getState();c("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let b=0;function v(m,D){switch(m.type){case"SET_ZOOM":{const k=u?u.getState().zoomLevel:"unknown";D(m),c("gantt.zoom",{oldLevel:k,newLevel:m.level});return}case"TASK_MOVE":{const k=b>0?Date.now()-b:0;D(m),c("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:k}),b=0;return}case"TASK_RESIZE":{D(m),c("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{b=Date.now(),D(m);return}case"SELECT_TASK":{D(m),c("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{D(m),h();return}case"TOGGLE_EXPAND":{const k=u?u.getState().expandedIds.has(m.taskId):!1;D(m),c(k?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{D(m),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{D(m),c("gantt.collapse",{all:!0});return}default:D(m);return}}return{name:"TelemetryPlugin",install(m){u=m,y();const D=m.getState();c("gantt.init",{taskCount:D.tasks.size,dependencyCount:D.dependencies.size,zoomLevel:D.zoomLevel}),setTimeout(()=>{g||c("gantt.feature.used",{plugins:p})},0);const k=m.on("taskClick",(...w)=>{const E=w[0];E&&c("gantt.task.click",{taskId:E.id})});r.push(k)},middleware:v,destroy(){g=!0;const m=Date.now()-l;c("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),f(),T();for(const D of r)D();r.length=0,u=null}}}const $s=5,mn=.15,Tn=.85,Ra=2,_s=30,He=["day","week","month","quarter"];function Ns(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function Pa(e,t,n){return Math.max(t,Math.min(n,e))}function $a(e){const t=Pa((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,d=0,g=0,p=0,r=null,c=null,f=null,y=null,T=null,h=null,b=0,v=0,m=0,D=!1;function k(O,N,Y){m=O,b=N,v=Y,D=!0,r===null&&(r=O)}function w(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(y=O=>{u||O.alpha==null||O.beta==null||O.gamma==null||k(O.alpha,O.beta,O.gamma)},window.addEventListener("deviceorientation",y),!0)}function E(){y&&(window.removeEventListener("deviceorientation",y),y=null)}function S(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function M(O){try{const N=JSON.parse(O);N.type==="orientation"?k(N.alpha,N.beta,N.gamma):N.type==="gesture"&&I(N.gesture)}catch{}}function I(O){if(!l)return;const N=l.getState();switch(O){case"tap":{N.selectedIds.size===0&&N.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:N.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const Y=He.indexOf(N.zoomLevel);Y<He.length-1&&l.dispatch({type:"SET_ZOOM",level:He[Y+1]});break}case"swipe-right":{const Y=He.indexOf(N.zoomLevel);Y>0&&l.dispatch({type:"SET_ZOOM",level:He[Y-1]});break}}}function R(){if(u||typeof WebSocket>"u")return;const O=S();try{T=new WebSocket(O),T.onmessage=N=>{typeof N.data=="string"&&M(N.data)},T.onclose=()=>{T=null,u||(h=setTimeout(R,3e3))},T.onerror=()=>{T&&T.close()}}catch{u||(h=setTimeout(R,3e3))}}function _(){h!==null&&(clearTimeout(h),h=null),T&&(T.onmessage=null,T.onclose=null,T.onerror=null,T.close(),T=null)}function x(){if(!(u||!l)){if(D){d=d*Tn+b*mn,g=g*Tn+v*mn,p=p*Tn+m*mn;const O=l.getState(),N=Ra*a;if(n){const Y=Ns(g,$s);if(Y!==0){const W=Y*N,j=Math.max(0,O.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:j})}}if(s){const Y=Ns(d,$s);if(Y!==0){const W=Y*N,j=Math.max(0,O.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:j})}}if(o&&r!==null){const W=(p-r+540)%360-180,j=He.indexOf(O.zoomLevel);if(W>_s&&j>0){const q=He[j-1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}else if(W<-_s&&j<He.length-1){const q=He[j+1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}}}f=requestAnimationFrame(x)}}return{name:"MotionControlPlugin",install(O){l=O,c=O.getState().zoomLevel,(!w()||i)&&R(),f=requestAnimationFrame(x)},destroy(){u=!0,f!==null&&(cancelAnimationFrame(f),f=null),E(),_(),l=null}}}const Tt="http://schemas.microsoft.com/project",_a=8,Os=4800,Na={0:"FF",1:"FS",2:"SF",3:"SS"},Oa={FF:0,FS:1,SF:2,SS:3};function Hs(e){return e?e.substring(0,10):""}function xs(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(Tt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function Ha(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function xa(e){return`PT${e*_a}H0M0S`}function yt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function yn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(Tt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let h=0;h<l.length;h++){const b=l[h],v=Ee(b,"UID"),m=Ee(b,"Name");v&&m&&i.set(v,m)}const u=new Map,d=o.getElementsByTagNameNS(Tt,"Assignment"),g=d.length>0?d:o.getElementsByTagName("Assignment");for(let h=0;h<g.length;h++){const b=g[h],v=Ee(b,"TaskUID"),m=Ee(b,"ResourceUID");if(v&&m){const D=i.get(m);D&&u.set(v,D)}}const p=[],r=[],c=o.getElementsByTagNameNS(Tt,"Task"),f=c.length>0?c:o.getElementsByTagName("Task"),y=[];let T=1;for(let h=0;h<f.length;h++){const b=f[h],v=Ee(b,"UID"),m=Ee(b,"Name"),D=Ee(b,"Start"),k=Ee(b,"Finish"),w=Ee(b,"PercentComplete"),E=Ee(b,"Summary")==="1",S=Ee(b,"Milestone")==="1",M=parseInt(Ee(b,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const I=`msp-${v}`,R=Hs(D),_=Hs(k);if(!R&&!S)continue;let x;M>0&&y[M-1]&&(x=y[M-1]),y[M]=I,y.length=M+1;const O={id:I,name:m||`Task ${v}`,startDate:R||_,endDate:_||R,progress:w?parseInt(w,10)/100:0,isMilestone:S,parentId:x,sortOrder:h},N=u.get(v);N&&(O.assignee=N),E&&(O.metadata={...O.metadata,isSummary:!0}),p.push(O);const Y=b.getElementsByTagNameNS(Tt,"PredecessorLink"),W=Y.length>0?Y:b.getElementsByTagName("PredecessorLink");for(let j=0;j<W.length;j++){const q=W[j],U=Ee(q,"PredecessorUID"),C=parseInt(Ee(q,"Type")||"1",10),P=Ee(q,"LinkLag"),A=P?parseInt(P,10):0;if(!U||U==="0")continue;const $={id:`msp-dep-${T++}`,source:`msp-${U}`,target:I,type:Na[C]??"FS",lag:A!==0?A/Os:void 0};r.push($)}}return{tasks:p,dependencies:r}}function bn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(v){let m=1,D=v;for(;D!=null&&D.parentId;)m++,D=e.tasks.get(D.parentId);return m}const d=new Map,g=new Map;for(const v of a){const m=v.parentId??"__root__",D=(d.get(m)??0)+1;if(d.set(m,D),!v.parentId)g.set(v.id,String(D));else{const k=g.get(v.parentId)??"0";g.set(v.id,`${k}.${D}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const c=new Map;for(const v of l){const m=c.get(v.target)??[];m.push(v),c.set(v.target,m)}const f=new Set;for(const v of a)v.assignee&&f.add(v.assignee);const y=Array.from(f),T=new Map;y.forEach((v,m)=>{T.set(v,m+1)});const h=[];h.push('<?xml version="1.0" encoding="UTF-8"?>'),h.push('<Project xmlns="http://schemas.microsoft.com/project">'),h.push(`  <Name>${yt(n)}</Name>`),h.push(`  <Author>${yt(s)}</Author>`),h.push(`  <CreationDate>${o}</CreationDate>`),h.push("  <CalendarUID>1</CalendarUID>"),h.push("  <Calendars>"),h.push("    <Calendar>"),h.push("      <UID>1</UID>"),h.push(`      <Name>${yt(i)}</Name>`),h.push("      <IsBaseCalendar>1</IsBaseCalendar>"),h.push("    </Calendar>"),h.push("  </Calendars>"),h.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,D=u(v),k=g.get(v.id)??"1",w=p.has(v.id),E=v.isMilestone??!1,S=xs(v.startDate),M=xs(v.endDate),I=Ha(S,M),R=xa(I),_=Math.round((v.progress??0)*100);h.push("    <Task>"),h.push(`      <UID>${m}</UID>`),h.push(`      <ID>${m}</ID>`),h.push(`      <Name>${yt(v.name)}</Name>`),h.push(`      <Start>${v.startDate}T08:00:00</Start>`),h.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),h.push(`      <Duration>${R}</Duration>`),h.push(`      <PercentComplete>${_}</PercentComplete>`),h.push(`      <Summary>${w?"1":"0"}</Summary>`),h.push(`      <Milestone>${E?"1":"0"}</Milestone>`),h.push(`      <OutlineLevel>${D}</OutlineLevel>`),h.push(`      <OutlineNumber>${k}</OutlineNumber>`);const x=c.get(v.id);if(x)for(const O of x){const N=r.get(O.source)??0;if(N===0)continue;const Y=Oa[O.type??"FS"]??1,W=Math.round((O.lag??0)*Os);h.push("      <PredecessorLink>"),h.push(`        <PredecessorUID>${N}</PredecessorUID>`),h.push(`        <Type>${Y}</Type>`),h.push(`        <LinkLag>${W}</LinkLag>`),h.push("      </PredecessorLink>")}h.push("    </Task>")}h.push("  </Tasks>"),h.push("  <Resources>");for(const v of y){const m=T.get(v)??0;h.push("    <Resource>"),h.push(`      <UID>${m}</UID>`),h.push(`      <Name>${yt(v)}</Name>`),h.push("    </Resource>")}h.push("  </Resources>"),h.push("  <Assignments>");let b=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,D=T.get(v.assignee)??0;m===0||D===0||(h.push("    <Assignment>"),h.push(`      <UID>${b++}</UID>`),h.push(`      <TaskUID>${m}</TaskUID>`),h.push(`      <ResourceUID>${D}</ResourceUID>`),h.push("    </Assignment>"))}return h.push("  </Assignments>"),h.push("</Project>"),h.join(`
`)}function Ba(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var d;const u=(d=l.target)==null?void 0:d.result;if(!(!u||!e))try{const g=yn(u);e.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies})}catch(g){console.error("[MSProjectPlugin] Import failed:",g)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=yn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),d=bn(u,a);l&&l(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),d=bn(u,a),g=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(g),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const Fa=[4,3],Ya=1.5,Ua=.5,Wa=.06,Xa=4,za=8,Ga=.35,Va=1,Bs=.2,bt=6,Fs=864e5;function _e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ys(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function vn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function wn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function ja(e){let t=0;for(const n of e){const s=_e(n.startDate).getTime(),o=_e(n.endDate).getTime();t+=Math.max(o-s,Fs)}return t}function Ka(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=_e(l.startDate).getTime(),g=_e(s.startDate).getTime()-u,p=i.segments.map(r=>{const c=new Date(_e(r.startDate).getTime()+g),f=new Date(_e(r.endDate).getTime()+g);return{startDate:Ys(c),endDate:Ys(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,d=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const g=i.segments.length-1;i.segments[g]={...i.segments[g],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:d,headerHeight:g,barHeight:p}=a,r=n.getTimeScale(),c=d.barBorderRadius,f=g;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-l,0);for(const y of i){if(y.isMilestone)continue;const T=t.get(y.taskId);if(!T||T.segments.length===0)continue;const h=y.barY-u,b=y.barHeight,v=h+b/2;if(h+b<f||h>s.canvas.height)continue;const m=[];for(const M of T.segments){const I=r.dateToX(_e(M.startDate)),R=r.dateToX(_e(M.endDate)),_=Math.max(R-I,4);m.push({startX:I,endX:I+_,width:_})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(y.x-1,h-1,y.width+2,b+2),s.restore();for(let M=0;M<m.length-1;M++){const I=m[M].endX,R=m[M+1].startX,_=R-I;if(!(_<=0)){s.save(),s.globalAlpha=Wa,s.strokeStyle=y.color,s.lineWidth=Xa,s.beginPath(),s.rect(I,h,_,b),s.clip();for(let x=I-b;x<R+b;x+=za)s.beginPath(),s.moveTo(x,h+b),s.lineTo(x+b,h),s.stroke();s.restore()}}for(let M=0;M<m.length-1;M++){const I=m[M].endX,R=m[M+1].startX;s.save(),s.globalAlpha=Ua,s.strokeStyle=vn(y.color,Bs),s.lineWidth=Ya,s.setLineDash(Fa),s.beginPath(),s.moveTo(I,v),s.lineTo(R,v),s.stroke(),s.setLineDash([]),s.restore()}const D=o.tasks.get(y.taskId),k=(D==null?void 0:D.progress)??0,w=ja(T.segments);let S=k*w;for(let M=0;M<m.length;M++){const I=m[M],R=Math.max(_e(T.segments[M].endDate).getTime()-_e(T.segments[M].startDate).getTime(),Fs);if(s.save(),wn(s,I.startX,h,I.width,b,c),s.fillStyle=y.color,s.fill(),s.strokeStyle=vn(y.color,Bs),s.lineWidth=Va,s.stroke(),s.restore(),S>0&&a.showProgress){const _=Math.min(S,R),x=_/R,O=I.width*x;s.save(),wn(s,I.startX,h,I.width,b,c),s.clip(),s.globalAlpha=Ga,s.fillStyle=vn(y.color,.3),s.fillRect(I.startX,h,O,b),s.restore(),S-=_}}if(y.label){const M=m[0],I=m[m.length-1],R=I.endX-M.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const x=s.measureText(y.label).width;s.textBaseline="middle",s.textAlign="left",x+bt*2<=M.width?(s.fillStyle=y.textColor,wn(s,M.startX,h,M.width,b,c),s.clip(),s.fillText(y.label,M.startX+bt,v)):x+bt<=R?(s.fillStyle=y.textColor,s.fillText(y.label,M.startX+bt,v)):(s.fillStyle=d.gridTextColor,s.fillText(y.label,I.endX+bt,v)),s.restore()}}s.restore()},destroy(){n=null}}}const Sn=864e5,Us=1e3,Rt=4,qa=.6,Za="#E53E3E",Ja="#48BB78",Qa="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function rt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Pt(e,t){return Math.round((t.getTime()-e.getTime())/Sn)}function Ws(e,t){return new Date(e.getTime()+t*Sn)}function Ge(e,t){return rt(Ws(he(e),t))}function xe(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(rt(n)),o;for(;i.getTime()<s.getTime();)o.push(rt(i)),i.setTime(i.getTime()+Sn);return o}class En{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(l=a.get(d))==null||l.delete(n),((u=a.get(d))==null?void 0:u.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const d of s){let g=(a==null?void 0:a.get(d))??0;if((u=l==null?void 0:l.get(d))!=null&&u.has(n)&&(g-=o),g+o>i)return!1}return!0}}function $t(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function er(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const d=parseInt(l,10);isNaN(d)||(u=d)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Xs(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function tr(e,t,n,s,o){const i=new Map;for(const h of s)e.has(h.taskId)&&n.has(h.resourceId)&&(i.has(h.taskId)||i.set(h.taskId,[]),i.get(h.taskId).push({resourceId:h.resourceId,units:h.units||1}));const a=new Map,l=new Map;for(const h of e.keys())a.set(h,[]),l.set(h,[]);for(const h of t.values()){if((h.type||"FS")!=="FS"||!e.has(h.source)||!e.has(h.target))continue;const v=h.lag||0;a.get(h.source).push({target:h.target,lag:v}),l.get(h.target).push({source:h.source,lag:v})}const u=new Map;for(const[h,b]of e){const v=he(b.startDate),m=he(b.endDate);u.set(h,{taskId:h,startDate:b.startDate,endDate:b.endDate,duration:Math.max(Pt(v,m),0)})}const d=new En;function g(){d.clear();for(const[h,b]of u){const v=i.get(h);if(!v)continue;const m=xe(b.startDate,b.endDate);for(const D of v)d.allocate(D.resourceId,h,m,D.units)}}function p(h,b){const v=u.get(h);if(!v)return new Set;const m=new Set,D=v.startDate;if(b===D||he(b).getTime()<he(D).getTime())return m;const k=i.get(h);if(k){const w=xe(v.startDate,v.endDate);for(const E of k)d.deallocate(E.resourceId,h,w,E.units)}if(v.startDate=b,v.endDate=Ge(b,v.duration),m.add(h),k){const w=xe(v.startDate,v.endDate);for(const E of k)d.allocate(E.resourceId,h,w,E.units)}return m}function r(h){const b=new Set,v=u.get(h);if(!v)return b;const m=a.get(h)??[];for(const{target:D,lag:k}of m){const w=u.get(D);if(!w)continue;const E=Ge(v.endDate,k);if(he(w.startDate).getTime()<he(E).getTime()){const S=p(D,E);for(const M of S){b.add(M);const I=r(M);for(const R of I)b.add(R)}}}return b}function c(h){const b=l.get(h)??[];let v=u.get(h).startDate;v=e.get(h).startDate;for(const{source:D,lag:k}of b){const w=u.get(D);if(!w)continue;const E=Ge(w.endDate,k);he(E).getTime()>he(v).getTime()&&(v=E)}return v}g();for(let h=0;h<Us;h++){const b=$t(d,n);if(b.length===0)break;let v=!1;const m=b[0],D=m.taskIds.map(k=>o.get(k)).filter(k=>k!==void 0).sort(Xs);if(!(D.length<2))for(let k=1;k<D.length;k++){const w=D[k],E=u.get(w.taskId);if(!E)continue;const S=u.get(D[0].taskId);if(!S)continue;const M=S.endDate,I=c(w.taskId),R=he(M).getTime()>he(I).getTime()?M:I;he(R).getTime()>he(E.startDate).getTime()&&(p(w.taskId,R),r(w.taskId),v=!0);const _=d.getLoad(m.resourceId,m.date),x=n.get(m.resourceId).maxUnits;if(_<=x)break}}const f=new Map;let y=0;for(const[h,b]of u){const v=e.get(h),m=Pt(he(v.startDate),he(b.startDate));m!==0&&(f.set(h,{startDate:b.startDate,endDate:b.endDate,delayDays:m}),y+=m)}const T=$t(d,n);return{adjustedTasks:f,totalDelay:y,conflicts:T,resolved:T.length===0}}function nr(e,t,n,s,o){const i=new Map;for(const b of s)e.has(b.taskId)&&n.has(b.resourceId)&&(i.has(b.taskId)||i.set(b.taskId,[]),i.get(b.taskId).push({resourceId:b.resourceId,units:b.units||1}));const a=new Map;for(const b of e.keys())a.set(b,[]);for(const b of t.values())(b.type||"FS")==="FS"&&(!e.has(b.source)||!e.has(b.target)||a.get(b.target).push({source:b.source,lag:b.lag||0}));const l=Array.from(e.keys()).map(b=>o.get(b)).filter(b=>b!==void 0).sort(Xs),u=new Map,d=new En,g=new Set,p=new Map;for(const[b,v]of e)p.set(b,Math.max(Pt(he(v.startDate),he(v.endDate)),0));function r(b){let m=e.get(b).startDate;const D=a.get(b)??[];for(const{source:k,lag:w}of D){const E=u.get(k);if(!E)continue;const S=Ge(E.endDate,w);he(S).getTime()>he(m).getTime()&&(m=S)}return m}function c(b,v,m){const D=i.get(b);if(!D||D.length===0)return v;let k=v;const w=365*5;for(let E=0;E<w;E++){const S=Ge(k,m),M=xe(k,S);let I=!0;for(const R of D){const _=n.get(R.resourceId);if(!_||_.maxUnits===0)continue;const x=_.calendar?new Set(_.calendar):null;if(x&&M.some(N=>x.has(N))){I=!1;break}if(!d.canFit(R.resourceId,b,M,R.units,_.maxUnits)){I=!1;break}}if(I)return k;k=Ge(k,1)}return v}const f=new Set(l.map(b=>b.taskId));for(let b=0;b<Us&&f.size>0;b++){let v=!1;for(const m of l){if(!f.has(m.taskId)||!(a.get(m.taskId)??[]).every(_=>g.has(_.source)))continue;const w=m.taskId,E=p.get(w)??0,S=r(w),M=c(w,S,E),I=Ge(M,E);u.set(w,{taskId:w,startDate:M,endDate:I,duration:E});const R=i.get(w);if(R){const _=xe(M,I);for(const x of R)d.allocate(x.resourceId,w,_,x.units)}g.add(w),f.delete(w),v=!0}if(!v){for(const m of f){const D=e.get(m),k=p.get(m)??0;u.set(m,{taskId:m,startDate:D.startDate,endDate:D.endDate,duration:k});const w=i.get(m);if(w){const E=xe(D.startDate,D.endDate);for(const S of w)d.allocate(S.resourceId,m,E,S.units)}g.add(m)}f.clear()}}const y=new Map;let T=0;for(const[b,v]of u){const m=e.get(b),D=Pt(he(m.startDate),he(v.startDate));D!==0&&(y.set(b,{startDate:v.startDate,endDate:v.endDate,delayDays:D}),T+=D)}const h=$t(d,n);return{adjustedTasks:y,totalDelay:T,conflicts:h,resolved:h.length===0}}function sr(e,t,n,s){const o=[],i=xe(n,Ge(s,1)),a=i.length;for(const[l,u]of t){const d=new Map;let g=0,p=0;for(const f of i){const y=e.getLoad(l,f);d.set(f,y),g+=y,y>p&&(p=y)}const r=u.maxUnits===0?1:u.maxUnits,c=a>0?g/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:d,overallUtilization:Math.min(c,1),peakUtilization:p})}return o}function zs(e,t,n,s){const o=new En,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const d=s.get(a),g=(d==null?void 0:d.startDate)??l.startDate,p=(d==null?void 0:d.endDate)??l.endDate,r=xe(g,p);for(const c of u)o.allocate(c.resourceId,a,r,c.units)}return o}function or(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:f}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const y=u(),T=er(c,y,n);s==="parallel"?i=nr(c,f,t,e.assignments,T):i=tr(c,f,t,e.assignments,T);const h=g(c,i.adjustedTasks),b=zs(c,t,e.assignments,i.adjustedTasks);return a=sr(b,t,h.start,h.end),i}function g(r,c){let f=1/0,y=-1/0;for(const[T,h]of r){const b=c.get(T),v=he((b==null?void 0:b.startDate)??h.startDate).getTime(),m=he((b==null?void 0:b.endDate)??h.endDate).getTime();v<f&&(f=v),m>y&&(y=m)}if(f===1/0){const T=rt(new Date);return{start:T,end:T}}return{start:rt(new Date(f)),end:rt(new Date(y))}}function p(r){const c=[];for(const f of e.assignments)f.taskId===r&&c.push(f.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),l.push(r.on("resourceLeveling:run",(...c)=>{const f=c[0],y=d();f&&f(y)})),l.push(r.on("resourceLeveling:result",(...c)=>{const f=c[0];f&&f(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const f=c[0];f&&f(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const f=c[0];if(!f)return;const y=r.getState(),T=zs(y.tasks,t,e.assignments,new Map);f($t(T,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,c,f){if(!i||a.length===0)return;const{config:y}=c,{headerHeight:T,rowHeight:h}=y,b=c.scrollX,v=c.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,T,r.canvas.width,r.canvas.height-T),r.clip(),r.translate(-b,0);const D=new Map;for(const k of a)D.set(k.resourceId,k);for(const k of f){const w=p(k.taskId);if(w.length===0)continue;const E=D.get(w[0]);if(!E)continue;const S=t.get(w[0]);if(!S)continue;const M=S.maxUnits===0?1:S.maxUnits,R=k.barY+k.barHeight-v+1;if(R+Rt<T||R>r.canvas.height)continue;const _=c.tasks.get(k.taskId);if(!_)continue;const x=i.adjustedTasks.get(k.taskId),O=(x==null?void 0:x.startDate)??_.startDate,N=(x==null?void 0:x.endDate)??_.endDate,Y=m.dateToX(he(O)),j=m.dateToX(he(N))-Y;if(j<2)continue;r.fillStyle=Qa,r.fillRect(Y,R,j,Rt);const q=xe(O,N);for(const U of q){const C=E.dailyLoad.get(U)??0;if(C===0)continue;const P=m.dateToX(he(U)),$=m.dateToX(Ws(he(U),1))-P,Q=Math.min(C/M,2)/2*Rt,Z=C>M;r.globalAlpha=qa,r.fillStyle=Z?Za:Ja,r.fillRect(P,R+Rt-Q,$,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const ir=864e5,ar=75,rr=50,Gs=25,_t=.3,Nt=.25,Vs=.2,Dn=.15,Ot=.1,lr=.3,js=.5,cr=20,Ks=40,dr=3,ur=5,gr=30,qs=.25,Zs=4,hr=2,fr=5,kn=5,Js=4,Qs=.4,pr=.003,Ve=260,lt=260,eo=16,Be=14,mr="rgba(30, 30, 46, 0.92)",Cn="#e0e0e0",Tr=10,Ht=32,yr=6,xt="#EF4444",Bt="#F97316",Ft="#EAB308",Yt="#22C55E";function ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ke(e,t){return Math.round((t.getTime()-e.getTime())/ir)}function De(e,t,n){return Math.max(t,Math.min(n,e))}function br(e){return e>=ar?"critical":e>=rr?"high":e>=Gs?"medium":"low"}function vr(e){switch(e){case"critical":return xt;case"high":return Bt;case"medium":return Ft;case"low":return Yt}}function Ut(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function wr(e,t){const n=new Map,s=new Map;for(const h of e.keys())n.set(h,[]),s.set(h,[]);for(const h of t.values())!e.has(h.source)||!e.has(h.target)||(n.get(h.source).push(h.target),s.get(h.target).push(h.source));const o=new Map,i=new Set;function a(h){if(o.has(h))return o.get(h);if(i.has(h))return 0;i.add(h);let b=0;for(const v of n.get(h)||[])b+=1+a(v);return o.set(h,b),b}for(const h of e.keys())a(h);const l=new Map;for(const[h,b]of e){const v=ve(b.startDate),m=ve(b.endDate);l.set(h,Math.max(ke(v,m),0))}const u=new Map,d=new Map,g=new Map;for(const h of e.keys())g.set(h,(s.get(h)||[]).length),u.set(h,l.get(h)||0),d.set(h,null);const p=[],r=new Map(g);for(const[h,b]of r)b===0&&p.push(h);for(;p.length>0;){const h=p.shift();for(const b of n.get(h)||[]){const v=u.get(h)+(l.get(b)||0);v>u.get(b)&&(u.set(b,v),d.set(b,h));const m=r.get(b)-1;r.set(b,m),m===0&&p.push(b)}}const c=new Set;let f=0,y=null;for(const[h,b]of u)b>f&&(f=b,y=h);let T=y;for(;T!==null;)c.add(T),T=d.get(T)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function Sr(e){const t=Ut(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ve(o.startDate),a=ve(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function Er(e,t,n){const s=[],o=Ut(),i=ve(e.startDate),a=ve(e.endDate),l=Math.max(ke(i,a),1),u=Math.max(ke(i,o),0),d=Math.max(ke(o,a),0),g=e.progress??0;if(e.isCompleted||g>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const E=ke(a,o);p=De(80+E*2,80,100),s.push({type:"time-pressure",description:`Task is ${E} day${E===1?"":"s"} past its end date`,impact:Math.round(p*_t)})}else{const E=d/l;E<.2&&g<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(E*100)}% time remaining but only ${Math.round(g*100)}% complete`,impact:Math.round(p*_t)})):(p=De(Math.round((1-E)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(E*100)}% of scheduled time remaining`,impact:Math.round(p*_t)}))}let c=0;const f=De(u/l,0,1),y=f-g;y>js?(c=De(Math.round(y*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(g*100)}%)`,impact:Math.round(c*Nt)})):y>lr?(c=De(Math.round(y*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(g*100)}%)`,impact:Math.round(c*Nt)})):y>.1&&(c=De(Math.round(y*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(g*100)}%`,impact:Math.round(c*Nt)}));let T=0;const h=t.downstreamCount.get(e.id)||0,b=t.criticalPathIds.has(e.id);if(h>0){T=De(Math.round(Math.log2(h+1)*20),0,70),b&&(T=De(Math.round(T*1.5),0,100));const E=b?" (on critical path)":"";s.push({type:"dependency-chain",description:`${h} downstream dependent${h===1?"":"s"}${E}`,impact:Math.round(T*Vs)})}let v=0;l>Ks?(v=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(v*Dn)})):l>cr&&(v=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(v*Dn)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*Ot)});else{const E=n.activeTasks.get(e.assignee)||[];E.length>ur?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*Ot)})):E.length>dr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*Ot)}))}const D=De(Math.round(p*_t+c*Nt+T*Vs+v*Dn+m*Ot),0,100),k=br(D);let w;return r&&g===0?w="Task is overdue with no progress — escalate immediately":r?w="Task is past its deadline — review scope or extend timeline":y>js?w="Task is significantly behind schedule — investigate blockers":l>Ks&&g<qs?w="Large task with little progress — consider splitting into smaller work items":(k==="high"||k==="critical")&&(w="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:k,riskScore:D,factors:s,suggestion:w}}function Dr(e,t,n,s,o){const i=Ut();let a=0,l=0,u=0;for(const[b,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;l++;const m=ve(v.startDate),D=ve(v.endDate),k=Math.max(ke(m,D),1),w=Math.max(ke(m,i),0),E=De(w/k,0,1);(v.progress??0)>=E-.1&&a++;const M=t.get(b);M&&(M.riskLevel==="high"||M.riskLevel==="critical")&&u++}const d=l>0?a/l:1;let g=0;for(const b of n.criticalPathIds){const v=e.get(b);if(!v||v.isCompleted)continue;const m=ve(v.endDate);i.getTime()>m.getTime()&&(g+=ke(m,i))}const p=[],r=[];for(const[b,v]of s.activeTasks)p.push(v.length),v.length>Zs&&r.push(b);let c=100;if(p.length>1){const b=p.reduce((v,m)=>v+m,0)/p.length;if(b>0){const v=p.reduce((D,k)=>D+(k-b)**2,0)/p.length,m=Math.sqrt(v)/b;c=De(Math.round(100-m*50),0,100)}}let f=100;if(l>0){let b=0,v=0,m=0;for(const D of e.values()){if(D.isCompleted)continue;const k=ve(D.startDate),w=ve(D.endDate),E=Math.max(ke(k,w),1),S=Math.max(ke(k,i),0),M=De(S/E,0,2);b+=D.progress??0,v+=M,m++}if(m>0){const D=b/m,k=v/m;if(k>0){const w=D/k;f=De(Math.round(w*100),0,100)}}}const y=d*100,T=De(100-g*10,0,100);return{overallScore:De(Math.round(y*.25+T*.25+c*.25+f*.25),0,100),tasksAtRisk:u,criticalPathDelay:g,resourceBottlenecks:r,recommendations:o}}function kr(e,t,n,s){const o=[],i=Ut();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.endDate),f=ke(c,i),y=r.progress??0;f>fr&&y===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const c=ve(r.startDate),f=ve(r.endDate),y=ke(c,f),T=r.progress??0;if(y>gr&&T<qs){const h=Math.ceil(y/15);o.push({type:"split",description:`"${r.name}" spans ${y} days — split into ${h} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>Zs?l.push({assignee:p,taskIds:r}):r.length<hr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const c=r.filter(f=>!t.criticalPathIds.has(f));c.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const c=ve(r.endDate),f=ke(i,c);if(f>=0&&f<=5){const y=s.get(p);y&&y.riskScore>=Gs&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ve(p.startDate).getTime()-ve(r.startDate).getTime()),g=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const c of r)g.add(`${c}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const c=d[p],f=d[r],y=ve(c.endDate),T=ve(f.startDate);if(y.getTime()<=T.getTime()&&!(g.has(`${c.id}->${f.id}`)||g.has(`${f.id}->${c.id}`))){const b=ke(y,T);b>0&&o.push({type:"parallel",description:`"${c.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${b} days on the critical path`,taskIds:[c.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function Cr(e,t,n,s,o,i,a){if(e.save(),i){const l=Qs+(1-Qs)*(.5+.5*Math.sin(a*pr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function Mr(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,d=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const g=i>=75?Yt:i>=50?Ft:i>=25?Bt:xt;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=g,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=Cn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function Ir(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:xt,label:"Critical"},{count:o.high,color:Bt,label:"High"},{count:o.medium,color:Ft,label:"Medium"},{count:o.low,color:Yt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const d=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+d),e.closePath(),e.fillStyle=u.color,e.fill(),l+=d}}function Ar(e,t,n,s,o){const i=t-Ve-eo,a=n+eo;e.save(),e.beginPath();const l=Tr;e.moveTo(i+l,a),e.lineTo(i+Ve-l,a),e.arcTo(i+Ve,a,i+Ve,a+l,l),e.lineTo(i+Ve,a+lt-l),e.arcTo(i+Ve,a+lt,i+Ve-l,a+lt,l),e.lineTo(i+l,a+lt),e.arcTo(i,a+lt,i,a+lt-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=mr,e.fill(),e.fillStyle=Cn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Be,a+Be);const u=i+Be+Ht+4,d=a+Be+20+Ht+8;Mr(e,u,d,Ht,yr,s.overallScore);const g=24,p=i+Ve-Be-g-4,r=d;Ir(e,p,r,g,o),e.font="9px sans-serif",e.textAlign="center";const c=r+g+8,f=[{count:o.critical,color:xt,label:"C"},{count:o.high,color:Bt,label:"H"},{count:o.medium,color:Ft,label:"M"},{count:o.low,color:Yt,label:"L"}],y=28,T=p-f.length*y/2+y/2;for(let m=0;m<f.length;m++){const D=f[m],k=T+m*y;e.fillStyle=D.color,e.fillText(`${D.label}:${D.count}`,k,c)}const h=d+Ht+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Be,h);const b=h+18;e.font="10px sans-serif",e.fillStyle=Cn,e.fillText("Recommendations:",i+Be,b);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const D=v[m],k=b+14+m*16,w=D.type==="escalate"?"⚠":D.type==="split"?"✂":D.type==="reassign"?"⇄":D.type==="parallel"?"⇉":D.type==="add-buffer"?"⏱":"ℹ",E=34,S=D.description.length>E?D.description.substring(0,E-1)+"…":D.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${w} ${S}`,i+Be,k)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Be,b+14)),e.restore()}function Lr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:d,dependencies:g}=u;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=wr(d,g),r=Sr(d),c=new Map;for(const[f,y]of d)c.set(f,Er(y,p,r));n=c,o=kr(d,p,r,n),s=Dr(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,d){d(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,d,g){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,c=d.scrollY,f=p,y=Date.now()-a;u.save(),u.beginPath(),u.rect(0,f,u.canvas.width,u.canvas.height-f),u.clip(),u.translate(-r,0);for(const T of g){const h=n.get(T.taskId);if(!h||h.riskLevel==="low")continue;const b=T.x,v=T.barY-c,m=T.width,D=T.barHeight;if(v+D<f||v>u.canvas.height||b+m<0)continue;const k=b+m-kn-Js,w=v+kn+Js,E=vr(h.riskLevel),S=h.riskLevel==="critical";Cr(u,k,w,kn,E,S,y)}if(u.restore(),i){const T={critical:0,high:0,medium:0,low:0};for(const h of n.values())T[h.riskLevel]++;u.save(),Ar(u,u.canvas.width,p,s,T),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Le=160,je=80,Mn=8,Rr=240,Pr=160,$r=100,_r=200,Wt=8,to=.1,no=3,Nr=.001,Or=500,Hr=5,xr=864e5,Br={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function so(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Fr(e,t){return Math.round((t.getTime()-e.getTime())/xr)}function oo(e,t,n){return e+(t-e)*n}function Xt(e,t,n){return Math.max(t,Math.min(n,e))}function In(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function Yr(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const d of s.get(l)){const g=n.get(d),p=u+1;(g===void 0||p>g)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function Ur(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Wr(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<Hr;a++){for(let l=1;l<e.length;l++){const u=e[l],d=new Map;for(const g of u){const p=o.get(g);if(p.size===0){d.set(g,i.get(g)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(g,r/p.size)}u.sort((g,p)=>(d.get(g)??0)-(d.get(p)??0));for(let g=0;g<u.length;g++)i.set(u[g],g)}for(let l=e.length-2;l>=0;l--){const u=e[l],d=new Map;for(const g of u){const p=s.get(g);if(p.size===0){d.set(g,i.get(g)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(g,r/p.size)}u.sort((g,p)=>(d.get(g)??0)-(d.get(p)??0));for(let g=0;g<u.length;g++)i.set(u[g],g)}}}function Xr(e,t){const n=new Map;if(t==="radial")return zr(e);const s=t==="lr",o=s?Rr:Pr,i=s?$r:_r;for(let a=0;a<e.length;a++){const l=e[a],g=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],c=g+p*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function zr(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function vt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Gr(e,t){return e.color?e.color:e.status&&(t[e.status]||Br[e.status])||"#94A3B8"}function Vr(e){const t=so(e.startDate),n=so(e.endDate);return Math.max(Fr(t,n),0)}function jr(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,d=new Map,g=[],p=null,r=0,c=0,f=1,y=!1,T=0,h=0,b=0,v=0,m=null,D=0,k=0,w=null,E=null,S=new Set,M=!1,I=0,R=0,_=0,x=0;function O(X,L){return{x:(X-r)/f,y:(L-c)/f}}function N(X,L){const{x:H,y:z}=O(X,L);for(const G of d.values()){const V=G.x,te=G.y;if(H>=V&&H<=V+Le&&z>=te&&z<=te+je)return G}return null}function Y(){const X=e.getState(),{tasks:L,dependencies:H,config:z}=X;if(L.size===0){d=new Map,g=[];return}p=dn(L,H);const G=Yr(L,H),V=Ur(G);Wr(V,H,L);const te=Xr(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:Se}of te.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Le),le=Math.min(le,Se),pe=Math.max(pe,Se+je);const be=(oe+ae)/2,Ce=(le+pe)/2,Me=d;d=new Map;for(const[ue,Se]of L){const Ie=te.get(ue);if(!Ie)continue;const Ue=Ie.x-be,Je=Ie.y-Ce,Ne=Me.get(ue);d.set(ue,{id:ue,task:Se,layer:G.get(ue)??0,orderInLayer:0,x:Ne?Ne.x:Ue,y:Ne?Ne.y:Je,targetX:Ue,targetY:Je,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let Se=0;Se<ue.length;Se++){const Ie=d.get(ue[Se]);Ie&&(Ie.orderInLayer=Se)}g=[];for(const ue of H.values())!L.has(ue.source)||!L.has(ue.target)||g.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const L=e.getState(),H=new Set;H.add(X);const z=new Map,G=new Map;for(const oe of L.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of L.dependencies.values())!L.tasks.has(oe.source)||!L.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])H.has(ae)||(H.add(ae),V.push(ae))}const te=[X];for(;te.length>0;){const oe=te.shift();for(const ae of z.get(oe)||[])H.has(ae)||(H.add(ae),te.push(ae))}return H}function j(){M&&cancelAnimationFrame(R),M=!0,I=performance.now(),q()}function q(){const X=performance.now()-I,L=Xt(X/Or,0,1),H=1-Math.pow(1-L,3);let z=!1;for(const G of d.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),te=Math.abs(G.y-G.targetY);V>.5||te>.5?(G.x=oo(G.x,G.targetX,H),G.y=oo(G.y,G.targetY,H),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(U(),z&&L<1)R=requestAnimationFrame(q);else{M=!1;for(const G of d.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);U()}}function U(){if(!i||!o)return;const X=e.getState(),{config:L}=X,H=L.theme,z=L.colorMap,G=H.timelineBg==="#1A202C"||H.gridBg==="#1A202C"||H.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(H.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,_,x),i.save(),i.translate(r,c),i.scale(f,f);for(const V of g){const te=d.get(V.sourceId),oe=d.get(V.targetId);if(!te||!oe)continue;const ae=S.has(V.sourceId)&&S.has(V.targetId),le=w===V.sourceId||w===V.targetId,pe=w!==null&&!le||E!==null&&!ae,be=te.x+Le,Ce=te.y+je/2,Me=oe.x,ue=oe.y+je/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=H.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const Se=(be+Me)/2;i.beginPath(),i.moveTo(be,Ce),i.quadraticCurveTo(Se,Ce,(be+Me)/2,(Ce+ue)/2),i.quadraticCurveTo(Se,ue,Me,ue),i.stroke();const Ie=Math.atan2(ue-(Ce+ue)/2,Me-Se);i.beginPath(),i.moveTo(Me,ue),i.lineTo(Me-Wt*Math.cos(Ie-Math.PI/6),ue-Wt*Math.sin(Ie-Math.PI/6)),i.lineTo(Me-Wt*Math.cos(Ie+Math.PI/6),ue-Wt*Math.sin(Ie+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Ue=V.dep.type||"FS",Je=V.dep.lag||0,Ne=Je!==0?`${Ue} +${Je}d`:Ue!=="FS"?Ue:"";if(Ne&&!pe){const Et=(be+Me)/2,zn=(Ce+ue)/2-8;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ne,Et,zn)}i.restore()}for(const V of d.values()){const te=w!==null&&w!==V.id&&!P(w,V.id)||E!==null&&!S.has(V.id),oe=w===V.id,ae=E===V.id,le=Gr(V.task,z),pe=V.x,be=V.y;i.save(),te&&(i.globalAlpha=.25),V.isCritical&&!te&&(i.save(),i.shadowColor=H.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,vt(i,pe,be,Le,je,Mn),i.fillStyle="transparent",i.fill(),i.restore()),vt(i,pe,be,Le,je,Mn),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=H.selectionColor||"#3182CE",i.lineWidth=2,vt(i,pe-2,be-2,Le+4,je+4,Mn+2),i.stroke()),i.font=`600 12px ${H.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ce=In(i,V.task.name,Le-20);i.fillText(Ce,pe+10,be+8);const Me=be+26;i.beginPath(),i.arc(pe+16,Me+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(In(i,ue,Le-40),pe+24,Me);const Se=Vr(V.task),Ie=Se===1?"1 day":`${Se} days`;i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Ie,pe+10,be+42),V.task.assignee&&(i.font=`10px ${H.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(In(i,V.task.assignee,Le/2-10),pe+Le-10,be+42));const Ue=V.task.progress??0,Je=be+je-6,Ne=Le-20,Et=3;if(vt(i,pe+10,Je,Ne,Et,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),Ue>0){const zn=Math.max(Et,Ne*Xt(Ue,0,1));vt(i,pe+10,Je,zn,Et,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),C(G,H.fontFamily)}function C(X,L){if(!i)return;const H={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${H[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,_-12,12),i.restore()}function P(X,L){for(const H of g)if(H.sourceId===X&&H.targetId===L||H.sourceId===L&&H.targetId===X)return!0;return!1}function A(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;u=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const H=o.getContext("2d");H&&(i=H,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",me),o.addEventListener("mouseup",F),o.addEventListener("mouseleave",ee),o.addEventListener("dblclick",K),o.addEventListener("wheel",J,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function $(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(_=X.clientWidth,x=X.clientHeight,o.width=Math.round(_*a),o.height=Math.round(x*a),o.style.width=`${_}px`,o.style.height=`${x}px`)}function B(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),$(),Z(),Y();for(const X of d.values())X.x=X.targetX,X.y=X.targetY;U()}}function Q(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),w=null,E=null,S=new Set)}function Z(){r=_/2,c=x/2,f=1}function re(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function ge(X){const{x:L,y:H}=re(X),z=N(L,H);z?(m=z,z.isDragging=!0,D=O(L,H).x-z.x,k=O(L,H).y-z.y,E=z.id,S=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),U()):(y=!0,T=L,h=H,b=r,v=c,E&&(E=null,S=new Set,e.dispatch({type:"DESELECT_ALL"}),U()))}function me(X){if(!o)return;const{x:L,y:H}=re(X);if(m){const V=O(L,H);m.x=V.x-D,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U();return}if(y){const V=L-T,te=H-h;r=b+V,c=v+te,U();return}const z=N(L,H),G=z?z.id:null;G!==w&&(w=G,o.style.cursor=w?"pointer":"default",U())}function F(X){m&&(m.isDragging=!1,m=null),y=!1}function ee(X){m&&(m.isDragging=!1,m=null),y=!1,w&&(w=null,U())}function K(X){const{x:L,y:H}=re(X),z=N(L,H);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function J(X){if(X.preventDefault(),!o)return;const{x:L,y:H}=re(X),z=O(L,H),G=-X.deltaY*Nr;f=Xt(f+G*f,to,no);const V=O(L,H);r+=(V.x-z.x)*f,c+=(V.y-z.y)*f,U()}let ne=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],H=o.getBoundingClientRect(),z=L.clientX-H.left,G=L.clientY-H.top,V=N(z,G);V?(m=V,V.isDragging=!0,D=O(z,G).x-V.x,k=O(z,G).y-V.y,E=V.id,S=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(y=!0,T=z,h=G,b=r,v=c),U()}else if(X.touches.length===2){y=!1,m&&(m.isDragging=!1,m=null);const L=X.touches[0],H=X.touches[1];ne=Math.hypot(H.clientX-L.clientX,H.clientY-L.clientY),de=(L.clientX+H.clientX)/2,ie=(L.clientY+H.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const H=X.touches[0],z=H.clientX-L.left,G=H.clientY-L.top;if(m){const V=O(z,G);m.x=V.x-D,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U()}else if(y){const V=z-T,te=G-h;r=b+V,c=v+te,U()}}else if(X.touches.length===2){const H=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-H.clientX,z.clientY-H.clientY),V=(H.clientX+z.clientX)/2,te=(H.clientY+z.clientY)/2,oe=V-L.left,ae=te-L.top;if(ne>0){const le=G/ne,pe=O(oe,ae);f=Xt(f*le,to,no);const be=O(oe,ae);r+=(be.x-pe.x)*f,c+=(be.y-pe.y)*f}r+=V-de,c+=te-ie,ne=G,de=V,ie=te,U()}}function Te(X){m&&(m.isDragging=!1,m=null),y=!1,ne=0}function ye(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",me),o.removeEventListener("mouseup",F),o.removeEventListener("mouseleave",ee),o.removeEventListener("dblclick",K),o.removeEventListener("wheel",J),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),M&&(cancelAnimationFrame(R),M=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():B()})),t.push(e.on("networkGraph:layout",(...L)=>{const H=L[0];H!==s&&(s=H,n&&(Y(),j()))})),t.push(e.on("stateChange",()=>{n&&(Y(),j())}))},renderDOM(X,L){o||A(X),n&&($(),U())},destroy(){for(const X of t)X();t=[],ye(),d=new Map,g=[],p=null,n=!1}}}const io=300,ao="nimbus-gantt-config-panel",An="nimbus-gantt-config-panel-styles",ro=300,Ln=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],Kr=`
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
    transition: opacity ${ro}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${io}px;
    width: ${io}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${ro}ms ease;
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
`;function qr(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(ao);return e?JSON.parse(e):{}}catch{return{}}}function Zr(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(ao,JSON.stringify(e))}catch{}}function lo(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function zt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Jr(){if(typeof document>"u"||document.getElementById(An))return;const e=document.createElement("style");e.id=An,e.textContent=Kr,document.head.appendChild(e)}function Qr(){if(typeof document>"u")return;const e=document.getElementById(An);e&&e.remove()}function Gt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),u.addEventListener("input",()=>{const g=Number(u.value);d.textContent=String(g),i(g)}),a.appendChild(l),a.appendChild(u),a.appendChild(d),a}function wt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function Vt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=co(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function co(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function el(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const w=e.getState();e.dispatch({type:"SET_SCROLL",x:w.scrollX,y:w.scrollY})}function d(w){Object.assign(t,w),Zr(t)}function g(w,E,S){w[E]=S}function p(w,E){if(!e)return;const S=e.getState();g(S.config,w,E),d({[w]:E}),u()}function r(w,E){if(!e)return;const S=e.getState();g(S.config.theme,w,E),u()}function c(w){if(!e)return;const E=Ln.find(M=>M.name===w);if(!E)return;const S=e.getState();Object.assign(S.config.theme,E.values),d({themePreset:w}),u()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function y(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function T(w,E){var X;const{config:S}=E;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?y():f()}),w.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",y),w.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",w.appendChild(o)),o.innerHTML="";const M=document.createElement("div");M.className="ng-config-panel-header",M.innerHTML="<span>Configuration</span>";const I=document.createElement("button");I.className="ng-config-close",I.innerHTML="×",I.addEventListener("click",y),M.appendChild(I),o.appendChild(M);const R=h("Display Settings");R.appendChild(Gt("Row height",24,60,S.rowHeight,2,L=>p("rowHeight",L))),R.appendChild(Gt("Bar height",16,40,S.barHeight,2,L=>p("barHeight",L))),R.appendChild(Gt("Grid width",0,500,S.gridWidth,10,L=>p("gridWidth",L))),R.appendChild(Gt("Font size",10,16,S.theme.fontSize,1,L=>{g(E.config.theme,"fontSize",L),d({fontSize:L}),u()})),R.appendChild(wt("Today marker",S.showToday,L=>{g(E.config,"showToday",L),d({showToday:L}),u()})),R.appendChild(wt("Weekends",S.showWeekends,L=>{g(E.config,"showWeekends",L),d({showWeekends:L}),u()})),R.appendChild(wt("Progress bars",S.showProgress,L=>{g(E.config,"showProgress",L),d({showProgress:L}),u()})),R.appendChild(wt("Dependency arrows",a,L=>{a=L,d({showDependencies:L}),u()})),R.appendChild(wt("Labels on bars",t.showBarLabels!==!1,L=>{d({showBarLabels:L}),u()})),o.appendChild(R);const _=h("Color Theme"),x=document.createElement("div");x.className="ng-config-row";const O=document.createElement("span");O.className="ng-config-label",O.textContent="Preset";const N=document.createElement("select");N.className="ng-config-select";const Y=document.createElement("option");Y.value="",Y.textContent="Custom",N.appendChild(Y);for(const L of Ln){const H=document.createElement("option");H.value=L.name,H.textContent=L.name,t.themePreset===L.name&&(H.selected=!0),N.appendChild(H)}N.addEventListener("change",()=>{N.value&&c(N.value)}),x.appendChild(O),x.appendChild(N),_.appendChild(x),_.appendChild(Vt("Bar default",S.theme.barDefaultColor,L=>{r("barDefaultColor",L),d({customColors:{...t.customColors,barDefault:L}})})),_.appendChild(Vt("Today line",S.theme.todayLineColor,L=>{r("todayLineColor",L),d({customColors:{...t.customColors,todayLine:L}})})),_.appendChild(Vt("Grid lines",S.theme.timelineGridColor,L=>{r("timelineGridColor",L),d({customColors:{...t.customColors,gridLines:L}})})),_.appendChild(Vt("Background",S.theme.timelineBg,L=>{r("timelineBg",L),d({customColors:{...t.customColors,background:L}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",_.appendChild(W);const j={...S.colorMap,...t.statusColorMap},q=document.createElement("div");function U(){q.innerHTML="";const L=Object.entries(j);for(const[z,G]of L){const V=document.createElement("div");V.className="ng-config-color-map-entry";const te=document.createElement("input");te.className="ng-config-color-map-status",te.value=z,te.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=co(G),oe.addEventListener("input",()=>{j[z]=oe.value,S.colorMap[z]=oe.value,d({statusColorMap:{...j}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete j[z],delete S.colorMap[z],d({statusColorMap:{...j}}),U(),u()}),V.appendChild(te),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const H=document.createElement("button");H.className="ng-config-color-map-add",H.textContent="+ Add status color",H.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(j[z.trim()]="#3b82f6",S.colorMap[z.trim()]="#3b82f6",d({statusColorMap:{...j}}),U(),u())}),q.appendChild(H)}U(),_.appendChild(q),o.appendChild(_);const C=h("Zoom & Time"),P=document.createElement("div");P.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const $=document.createElement("div");$.className="ng-config-zoom-group";const B=["day","week","month","quarter"];for(const L of B){const H=document.createElement("button");H.className="ng-config-zoom-btn"+(E.zoomLevel===L?" ng-active":""),H.textContent=L.charAt(0).toUpperCase()+L.slice(1),H.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),d({zoomLevel:L}),$.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===H)))}),$.appendChild(H)}P.appendChild(A),P.appendChild($),C.appendChild(P);const Q=document.createElement("div");Q.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=lo(E.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const L=zt(re.value),H=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeStart:re.value})}),Q.appendChild(Z),Q.appendChild(re),C.appendChild(Q);const ge=document.createElement("div");ge.className="ng-config-row";const me=document.createElement("span");me.className="ng-config-label",me.textContent="End date";const F=document.createElement("input");F.type="date",F.className="ng-config-date-input",F.value=lo(E.dateRange.end),F.addEventListener("change",()=>{if(!e||!F.value)return;const L=e.getState().dateRange.start,H=zt(F.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:H}),d({dateRangeEnd:F.value})}),ge.appendChild(me),ge.appendChild(F),C.appendChild(ge);const ee=document.createElement("div");ee.style.cssText="margin-top: 8px;";const K=document.createElement("button");K.className="ng-config-btn ng-primary",K.textContent="Fit to View",K.addEventListener("click",()=>{e&&(g(e.getState().config,"fitToView",!0),u())}),ee.appendChild(K),C.appendChild(ee),o.appendChild(C);const J=h("Export"),ne=document.createElement("div");ne.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:E.scrollX,y:E.scrollY}),b("export:png"))}),ne.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>b("export:svg")),ne.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),ne.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&D(e.getState())}),ne.appendChild(ce),J.appendChild(ne),o.appendChild(J);const Te=h("Plugin Toggles"),ye=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of ye){const H=document.createElement("div");H.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=L.label;const G=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const te=document.createElement("div");te.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",te.appendChild(oe);let ae=G;te.addEventListener("click",()=>{ae=!ae,te.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[L.key]:ae};d({pluginToggles:pe}),b(L.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),H.appendChild(le),H.appendChild(te),Te.appendChild(H)}o.appendChild(Te)}function h(w){const E=document.createElement("div");E.className="ng-config-section";const S=document.createElement("div");return S.className="ng-config-section-title",S.textContent=w,E.appendChild(S),E}function b(w){e&&v.forEach(E=>E(w))}const v=[];function m(w){const E=Array.from(w.tasks.values());if(E.length===0)return;const S=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],M=E.map(O=>[O.id,`"${(O.name||"").replace(/"/g,'""')}"`,O.startDate,O.endDate,String(Math.round((O.progress??0)*100))+"%",O.status||"",O.assignee||"",O.priority||"",O.groupName||""]),I=[S.join(","),...M.map(O=>O.join(","))].join(`
`),R=new Blob([I],{type:"text/csv;charset=utf-8;"}),_=URL.createObjectURL(R),x=document.createElement("a");x.href=_,x.download="gantt-tasks.csv",document.body.appendChild(x),x.click(),document.body.removeChild(x),URL.revokeObjectURL(_)}function D(w){const E=Array.from(w.tasks.values());if(E.length===0)return;const S=["Name","Start","End","Progress","Status","Assignee"],M=E.map(_=>[_.name,_.startDate,_.endDate,Math.round((_.progress??0)*100)+"%",_.status||"",_.assignee||""]),R=[S.join("	"),...M.map(_=>_.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(R).catch(()=>{})}function k(w){const E=t;if(E.rowHeight!==void 0&&g(w.config,"rowHeight",E.rowHeight),E.barHeight!==void 0&&g(w.config,"barHeight",E.barHeight),E.gridWidth!==void 0&&g(w.config,"gridWidth",E.gridWidth),E.fontSize!==void 0&&g(w.config.theme,"fontSize",E.fontSize),E.showToday!==void 0&&g(w.config,"showToday",E.showToday),E.showWeekends!==void 0&&g(w.config,"showWeekends",E.showWeekends),E.showProgress!==void 0&&g(w.config,"showProgress",E.showProgress),E.showDependencies!==void 0&&(a=E.showDependencies),E.themePreset){const S=Ln.find(M=>M.name===E.themePreset);S&&Object.assign(w.config.theme,S.values)}E.customColors&&(E.customColors.barDefault&&g(w.config.theme,"barDefaultColor",E.customColors.barDefault),E.customColors.todayLine&&g(w.config.theme,"todayLineColor",E.customColors.todayLine),E.customColors.gridLines&&g(w.config.theme,"timelineGridColor",E.customColors.gridLines),E.customColors.background&&g(w.config.theme,"timelineBg",E.customColors.background)),E.statusColorMap&&Object.assign(w.config.colorMap,E.statusColorMap),E.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:E.zoomLevel})),E.dateRangeStart&&E.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:zt(E.dateRangeStart),end:zt(E.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(w){e=w,Jr(),t=qr();const E=w.on("render",()=>{E(),k(w.getState()),u()});l.push(E);const S=w.on("config:open",()=>f()),M=w.on("config:close",()=>y()),I=w.on("config:toggle",()=>{i?y():f()});l.push(S,M,I)},renderDOM(w,E){T(w,E)},destroy(){l.forEach(w=>w()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Qr(),e=null,i=!1}}}const uo=864e5,Rn="nimbus-gantt-heatmap-styles",we=28,Re=2,Ke=48,Pe=160,tl=3,go="#1e1e2e",ho="#166534",fo="#a16207",po="#b91c1c",nl=`
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
`;function mo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function sl(e){return String(e.getUTCDate())}function ol(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function il(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function To(e,t){return Math.round((t.getTime()-e.getTime())/uo)}function yo(e,t){return new Date(e.getTime()+t*uo)}function ct(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function al(e,t){return e===0?go:e===1?ho:e===2?fo:po}function rl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function ll(){if(typeof document>"u"||document.getElementById(Rn))return;const e=document.createElement("style");e.id=Rn,e.textContent=nl,document.head.appendChild(e)}function cl(){if(typeof document>"u")return;const e=document.getElementById(Rn);e&&e.remove()}function dl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const g of t){const p=g.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=To(o,i)+1,l=[];for(let g=0;g<a;g++)l.push(yo(o,g));const u=new Map;let d=0;for(const g of s)for(const p of l){const r=`${g}|${ct(p)}`;u.set(r,{assignee:g,date:p,dateKey:ct(p),tasks:[],count:0})}for(const g of t){const p=g.assignee||"Unassigned",r=mo(g.startDate),c=mo(g.endDate),f=To(r,c)+1;for(let y=0;y<f;y++){const T=yo(r,y),h=`${p}|${ct(T)}`,b=u.get(h);b&&(b.tasks.push(g),b.count++,b.count>d&&(d=b.count))}}return{assignees:s,dates:l,cells:u,maxCount:d}}function ul(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=dl(p);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const f=document.createElement("canvas"),y=Pe+r.dates.length*(we+Re),T=Ke+r.assignees.length*(we+Re),h=window.devicePixelRatio||1;f.width=y*h,f.height=T*h,f.style.width=y+"px",f.style.height=T+"px",f.style.cursor="pointer";const b=f.getContext("2d");b.scale(h,h),b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle";let v="",m=Pe;for(let D=0;D<r.dates.length;D++){const k=r.dates[D],w=ol(k),E=Pe+D*(we+Re);if(w!==v){if(v&&D>0){const S=(m+E)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(v,S,12)}m=E,v=w}}if(v){const D=Pe+r.dates.length*(we+Re),k=(m+D)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(v,k,12)}b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let D=0;D<r.dates.length;D++){const k=r.dates[D],w=Pe+D*(we+Re)+we/2,E=k.getUTCDay()===0||k.getUTCDay()===6;b.fillStyle=E?"#475569":"#64748b",b.fillText(sl(k),w,32)}b.beginPath(),b.strokeStyle="#1e293b",b.lineWidth=1,b.moveTo(0,Ke-.5),b.lineTo(y,Ke-.5),b.stroke();for(let D=0;D<r.assignees.length;D++){const k=r.assignees[D],w=Ke+D*(we+Re);b.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="left",b.textBaseline="middle",b.fillStyle="#cbd5e1",b.save(),b.beginPath(),b.rect(0,w,Pe-8,we),b.clip(),b.fillText(k,8,w+we/2),b.restore();for(let E=0;E<r.dates.length;E++){const S=r.dates[E],M=`${k}|${ct(S)}`,I=r.cells.get(M),R=(I==null?void 0:I.count)??0,_=Pe+E*(we+Re),x=al(R),O=rl(R,r.maxCount);b.globalAlpha=O,b.fillStyle=x,g(b,_,w,we,we,tl),b.fill(),R>=2&&(b.globalAlpha=1,b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle",b.fillStyle="#fff",b.fillText(String(R),_+we/2,w+we/2)),b.globalAlpha=1}}c.appendChild(f),f.addEventListener("mousemove",D=>{if(!n)return;const k=f.getBoundingClientRect(),w=D.clientX-k.left,E=D.clientY-k.top,S=Math.floor((w-Pe)/(we+Re)),M=Math.floor((E-Ke)/(we+Re));if(S<0||S>=r.dates.length||M<0||M>=r.assignees.length||w<Pe||E<Ke){n.classList.remove("ng-visible");return}const I=r.dates[S],R=r.assignees[M],_=`${R}|${ct(I)}`,x=r.cells.get(_);if(!x||x.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const O=document.createElement("div");O.className="ng-heatmap-tooltip-date",O.textContent=`${R} - ${il(I)}`,n.appendChild(O);for(const W of x.tasks){const j=document.createElement("div");j.className="ng-heatmap-tooltip-task",j.textContent=`• ${W.name}`,n.appendChild(j)}n.classList.add("ng-visible");const N=D.clientX+12,Y=D.clientY+12;n.style.left=N+"px",n.style.top=Y+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",D=>{if(!e)return;const k=f.getBoundingClientRect(),w=D.clientX-k.left,E=D.clientY-k.top,S=Math.floor((w-Pe)/(we+Re)),M=Math.floor((E-Ke)/(we+Re));if(S<0||S>=r.dates.length||M<0||M>=r.assignees.length||w<Pe||E<Ke)return;const I=r.dates[S],_=`${r.assignees[M]}|${ct(I)}`,x=r.cells.get(_);if(!(!x||x.count===0)){u();for(const O of x.tasks)e.dispatch({type:"SELECT_TASK",taskId:O.id,multi:!0})}})}function g(p,r,c,f,y,T){p.beginPath(),p.moveTo(r+T,c),p.lineTo(r+f-T,c),p.quadraticCurveTo(r+f,c,r+f,c+T),p.lineTo(r+f,c+y-T),p.quadraticCurveTo(r+f,c+y,r+f-T,c+y),p.lineTo(r+T,c+y),p.quadraticCurveTo(r,c+y,r,c+y-T),p.lineTo(r,c+T),p.quadraticCurveTo(r,c,r+T,c),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,ll();const r=p.on("heatmap:toggle",()=>a()),c=p.on("heatmap:show",()=>l()),f=p.on("heatmap:hide",()=>u());i.push(r,c,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",c.appendChild(f);const y=document.createElement("div");y.className="ng-heatmap-legend";const T=[{color:go,label:"None"},{color:ho,label:"1 task"},{color:fo,label:"2 tasks"},{color:po,label:"3+ tasks"}];for(const b of T){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=b.color,y.appendChild(v);const m=document.createElement("span");m.textContent=b.label,y.appendChild(m)}c.appendChild(y);const h=document.createElement("button");h.className="ng-heatmap-close",h.textContent="Back to Gantt",h.addEventListener("click",u),c.appendChild(h),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),cl(),e=null,s=!1,o=null}}}const qe=200,Ze=80,bo=12,vo=6,gl="rgba(255, 255, 255, 0.95)",hl="#cbd5e1",fl="rgba(59, 130, 246, 0.3)",pl="rgba(59, 130, 246, 0.7)",ml=1.5,Tl=2,yl=1,Pn="nimbus-gantt-minimap-styles",bl=864e5,vl=`
  .ng-minimap {
    position: absolute;
    bottom: ${bo}px;
    right: ${bo}px;
    width: ${qe}px;
    height: ${Ze}px;
    z-index: 900;
    border-radius: ${vo}px;
    border: 1px solid ${hl};
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
    border-radius: ${vo}px;
  }
`;function wl(){if(typeof document>"u"||document.getElementById(Pn))return;const e=document.createElement("style");e.id=Pn,e.textContent=vl,document.head.appendChild(e)}function Sl(){if(typeof document>"u")return;const e=document.getElementById(Pn);e&&e.remove()}function El(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,d=0,g=0,p=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function y(){o=!1,t&&t.classList.add("ng-hidden")}function T(D,k){const w=D/l-p/2,E=k/u-r/2;return{x:Math.max(0,Math.min(w,d-p)),y:Math.max(0,Math.min(E,g-r))}}function h(D){if(!e||!n)return;D.preventDefault(),i=!0;const k=n.getBoundingClientRect(),w=D.clientX-k.left,E=D.clientY-k.top,S=T(w,E);e.dispatch({type:"SET_SCROLL",x:S.x,y:S.y})}function b(D){if(!i||!e||!n)return;D.preventDefault();const k=n.getBoundingClientRect(),w=Math.max(0,Math.min(D.clientX-k.left,qe)),E=Math.max(0,Math.min(D.clientY-k.top,Ze)),S=T(w,E);e.dispatch({type:"SET_SCROLL",x:S.x,y:S.y})}function v(){i=!1}function m(D,k){if(!s||!n||!o)return;const w=window.devicePixelRatio||1;n.width=qe*w,n.height=Ze*w,n.style.width=qe+"px",n.style.height=Ze+"px",s.scale(w,w);const{config:E,scrollX:S,scrollY:M,dateRange:I}=D,R=e.getTimeScale(),_=Math.round((I.end.getTime()-I.start.getTime())/bl),x=R.getColumnWidth();if(d=Math.max(_*x,1),g=Math.max(D.flatVisibleIds.length*E.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=g>0?Math.min(g,600):600,t&&t.parentElement){const A=t.parentElement;p=A.clientWidth-E.gridWidth,r=A.clientHeight-E.headerHeight}l=qe/Math.max(d,1),u=Ze/Math.max(g,1),s.fillStyle=gl,s.fillRect(0,0,qe,Ze);const O=new Map;for(const A of k)O.has(A.rowIndex)||O.set(A.rowIndex,[]),O.get(A.rowIndex).push(A);for(const A of k){const $=A.x*l,B=Math.max(A.width*l,1),Q=A.rowIndex*E.rowHeight*u;s.fillStyle=A.color||E.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect($,Q,B,Math.max(Tl,E.rowHeight*u-yl))}s.globalAlpha=1;const N=S*l,Y=M*u,W=p*l,j=r*u,q=Math.max(0,Math.min(N,qe-1)),U=Math.max(0,Math.min(Y,Ze-1)),C=Math.min(W,qe-q),P=Math.min(j,Ze-U);s.fillStyle=fl,s.fillRect(q,U,C,P),s.strokeStyle=pl,s.lineWidth=ml,s.strokeRect(q,U,C,P)}return{name:"MiniMapPlugin",install(D){e=D,wl();const k=D.on("minimap:toggle",()=>c()),w=D.on("minimap:show",()=>f()),E=D.on("minimap:hide",()=>y());a.push(k,w,E),typeof document<"u"&&(document.addEventListener("mousemove",b),document.addEventListener("mouseup",v))},renderDOM(D,k){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",h),t.appendChild(n),D.appendChild(t));const w=(e==null?void 0:e.getLayouts())??[];m(k,w)},destroy(){a.forEach(D=>D()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",b),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,Sl(),e=null,o=!0,i=!1}}}const Dl="#f59e0b",kl=[6,4],Cl=1,et=16,Ml=4,Il="rgba(15, 23, 42, 0.95)",Al="#e2e8f0",Ll="#334155",Rl=6,tt=10,wo=220,So=12,Eo=13;function Pl(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function St(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function $l(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=St(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function _l(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const d=u%2===0?i:a,g=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(g)*d,r=n+Math.sin(g)*d;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=St(o,.25),e.lineWidth=.5,e.stroke()}function Nl(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=St(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function Ol(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=St(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Hl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=St(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Do={flag:$l,star:_l,warning:Nl,info:Ol,deadline:Hl};function xl(e,t,n,s,o){e.save();const i=`${So}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Eo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let d=0;if(t.description){const T=t.description.split(" ");let h="";for(const b of T){const v=h?h+" "+b:b;e.measureText(v).width>wo-tt*2&&h?(u.push(h),d=Math.max(d,e.measureText(h).width),h=b):h=v}h&&(u.push(h),d=Math.max(d,e.measureText(h).width))}const g=Math.min(wo,Math.max(l,d)+tt*2),p=So+4,r=Eo+4,c=tt*2+r+(u.length>0?4+u.length*p:0);let f=n-g/2;const y=s-c-8;if(f<4&&(f=4),f+g>o-4&&(f=o-g-4),e.beginPath(),Bl(e,f,y,g,c,Rl),e.fillStyle=Il,e.fill(),e.strokeStyle=Ll,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Al,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+tt,y+tt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let T=y+tt+r+4;for(const h of u)e.fillText(h,f+tt,T),T+=p}e.restore()}function Bl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Fl(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,d=null;function g(h){return n.find(b=>b.id===h)}function p(h){n.push(h),y()}function r(h){n=n.filter(b=>b.id!==h),y()}function c(h,b){const v=g(h);v&&(Object.assign(v,b),y())}function f(){return[...n]}function y(){if(!t)return;const h=t.getState();t.dispatch({type:"SET_SCROLL",x:h.scrollX,y:h.scrollY})}function T(h){const b=h.canvas;d!==b&&(d&&u&&d.removeEventListener("mousemove",u),d=b,u=v=>{const m=b.getBoundingClientRect();a=v.clientX-m.left,l=v.clientY-m.top;let D=null;for(const k of o){const w=a-k.x,E=l-k.y;if(Math.sqrt(w*w+E*E)<=k.size){D=k.note.id;break}}D!==s&&(s=D,b.style.cursor=s?"pointer":"",y())},b.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(h){t=h;const b=h.on("notes:add",(...k)=>{const w=k[0];w&&w.id&&w.date&&w.label&&p(w)}),v=h.on("notes:remove",(...k)=>{const w=k[0];w&&r(w)}),m=h.on("notes:update",(...k)=>{const w=k[0];if(w&&w.id){const{id:E,...S}=w;c(E,S)}}),D=h.on("notes:list",(...k)=>{const w=k[0];typeof w=="function"&&w(f())});i.push(b,v,m,D)},renderCanvas(h,b,v){if(!t||n.length===0)return;const{config:m,scrollX:D,scrollY:k,dateRange:w}=b,{theme:E}=m,S=m.headerHeight,M=t.getTimeScale();T(h);const I=h.canvas.width/(window.devicePixelRatio||1),R=h.canvas.height/(window.devicePixelRatio||1),_=S,x=R-_;o=[],h.save();for(const O of n){const N=Pl(O.date);if(N<w.start||N>w.end)continue;const Y=O.color||Dl,W=O.icon||"flag",j=M.dateToX(N)-D;if(j<-et||j>I+et)continue;h.save(),h.beginPath(),h.setLineDash(kl),h.strokeStyle=Y,h.globalAlpha=.5,h.lineWidth=Cl,h.moveTo(j,_),h.lineTo(j,_+x),h.stroke(),h.setLineDash([]),h.globalAlpha=1,h.restore();const q=j,U=_+Ml+et/2,C=Do[W]||Do.flag;h.save(),h.beginPath(),h.arc(q,U,et/2+3,0,Math.PI*2),h.fillStyle="rgba(0, 0, 0, 0.4)",h.fill(),h.restore(),h.save(),C(h,q,U,et,Y),h.restore(),o.push({note:O,x:q,y:U,size:et/2+4}),s===O.id&&xl(h,O,q,U-et/2-4,I)}h.restore()},destroy(){i.forEach(h=>h()),i.length=0,d&&u&&d.removeEventListener("mousemove",u),t=null,d=null,u=null,s=null,o=[]}}}const Yl=500,Ul=40,ko=7,Co=3,Mo=5,Wl=500,$n="nimbus-gantt-timetravel-styles",Io={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Xl=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Ul}px;
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
    width: ${ko*2}px;
    height: ${ko*2}px;
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
    width: ${Co*2}px;
    height: ${Co*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${Mo*2}px;
    height: ${Mo*2}px;
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
`;function zl(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Gl(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Vl(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function jl(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function Kl(){if(typeof document>"u"||document.getElementById($n))return;const e=document.createElement("style");e.id=$n,e.textContent=Xl,document.head.appendChild(e)}function ql(){if(typeof document>"u")return;const e=document.getElementById($n);e&&e.remove()}const Ao=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),jt=[.5,1,2,4];function Zl(e){const t=(e==null?void 0:e.maxSnapshots)??Yl,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,d=1;const g=[];let p=null,r=null,c=null,f=null,y=null,T=null,h=null,b=!1;function v(U){if(!s||a)return;const C=s.getState(),P=Vl(C,U);i<o.length-1&&(o.length=i+1),o.push(P),o.length>t&&o.shift(),i=o.length-1}function m(U){if(!s||o.length===0)return;const C=Math.max(0,Math.min(U,o.length-1));i=C;const P=o[C];a=!0;const A=P.tasks.map(B=>({id:B.id,name:B.name,startDate:B.startDate,endDate:B.endDate,progress:B.progress,status:B.status})),$=P.dependencies.map(B=>({id:B.id,source:B.source,target:B.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:$}),a=!1,_()}function D(){o.length>0&&m(o.length-1),w()}function k(){if(l||o.length<=1)return;l=!0;const U=jt[d],C=Wl/U;u=setInterval(()=>{if(i>=o.length-1){w();return}m(i+1)},C),_()}function w(){l=!1,u!==null&&(clearInterval(u),u=null),_()}function E(){l?w():k()}function S(){d=(d+1)%jt.length,l&&(w(),k()),_()}function M(){w(),i>0&&m(i-1)}function I(){w(),i<o.length-1&&m(i+1)}function R(){w(),o.length=0,i=-1,a=!1,_()}function _(){if(p){if(f){const U=o.length,C=U>0?i+1:0;f.textContent=`${C} / ${U}`}y&&(y.textContent=l?"⏸":"▶",y.classList.toggle("ng-active",l)),T&&(T.textContent=`${jt[d]}x`),x(),O()}}function x(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const U=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${U}%`}function O(){if(!h||!r||(h.innerHTML="",o.length===0))return;const U=200,C=o.length>U?Math.ceil(o.length/U):1;for(let P=0;P<o.length;P+=C){const A=o[P],$=o.length<=1?50:P/(o.length-1)*100,B=zl(A.action.split(" ")[0]==="Loaded"?"SET_DATA":N(A.action)),Q=Io[B]||Io.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${$}%`,Z.style.background=Q;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${jl(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=P;Z.addEventListener("click",me=>{me.stopPropagation(),w(),m(ge)}),h.appendChild(Z)}}function N(U){return U.startsWith("Moved")?"TASK_MOVE":U.startsWith("Resized")?"TASK_RESIZE":U.startsWith("Added task")?"ADD_TASK":U.startsWith("Added dependency")?"ADD_DEPENDENCY":U.startsWith("Removed task")?"REMOVE_TASK":U.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":U.startsWith("Updated")?"UPDATE_TASK":(U.startsWith("Loaded"),"SET_DATA")}function Y(U){if(!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));w(),m(A)}function W(U){U.preventDefault(),U.stopPropagation(),b=!0,c&&c.classList.add("ng-dragging"),w()}function j(U){if(!b||!r||o.length<=1)return;const C=r.getBoundingClientRect(),P=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round(P*(o.length-1));m(A)}function q(){b&&(b=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(U){s=U,Kl(),g.push(U.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),U.on("timeTravel:scrub",(...C)=>{const P=C[0];w(),m(P)}),U.on("timeTravel:play",()=>k()),U.on("timeTravel:pause",()=>w()),U.on("timeTravel:present",()=>D()),U.on("timeTravel:clear",()=>R()),U.on("timeTravel:history",(...C)=>{const P=C[0];typeof P=="function"&&P([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",j),document.addEventListener("mouseup",q))},middleware(U,C){let P="";n&&Ao.has(U.type)&&s&&!a&&(P=Gl(U,s.getState())),C(U),n&&Ao.has(U.type)&&!a&&P&&v(P)},renderDOM(U,C){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const P=document.createElement("button");P.className="ng-timetravel-btn",P.textContent="◀",P.title="Step backward",P.addEventListener("click",()=>M()),p.appendChild(P),y=document.createElement("button"),y.className="ng-timetravel-btn",y.textContent="▶",y.title="Play / Pause",y.addEventListener("click",()=>E()),p.appendChild(y);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>I()),p.appendChild(A),T=document.createElement("span"),T.className="ng-timetravel-speed ng-timetravel-btn",T.textContent=`${jt[d]}x`,T.title="Click to cycle speed",T.addEventListener("click",()=>S()),p.appendChild(T),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",Y);const $=document.createElement("div");$.className="ng-timetravel-rail",r.appendChild($),h=document.createElement("div"),h.style.position="absolute",h.style.inset="0",r.appendChild(h),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",W),r.appendChild(c),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const B=document.createElement("button");B.className="ng-timetravel-btn ng-present",B.textContent="Present",B.title="Return to latest state",B.addEventListener("click",()=>D()),p.appendChild(B),U.appendChild(p)}_()},destroy(){w();for(const U of g)U();g.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",j),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,c=null,f=null,y=null,T=null,h=null,ql(),o.length=0,i=-1,a=!1,l=!1,b=!1,s=null}}}const Lo=864e5,Jl=60,Ql=2,Ro=[6,4],_n="nimbus-gantt-montecarlo-styles",Po={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},ec=.08,tc=`
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
`;function Nn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Kt(e,t){return Math.round((t.getTime()-e.getTime())/Lo)}function nt(e,t){return new Date(e.getTime()+t*Lo)}function $o(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function _o(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function nc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function sc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function oc(e,t){return e+Math.random()*(t-e)}function ic(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const d=new Float64Array(u),g=new Float64Array(u),p=new Int32Array(l),r=[];for(let y=0;y<u;y++)p[y]===0&&(r.push(y),d[y]=o[y],g[y]=o[y]+s[y]);let c=0;for(;c<r.length;){const y=r[c++],T=g[y],h=i[y];for(let b=0;b<h.length;b++){const v=h[b];T>d[v]&&(d[v]=T,g[v]=T+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let y=0;y<u;y++)g[y]===0&&s[y]>0&&(d[y]=o[y],g[y]=o[y]+s[y]);let f=0;for(let y=0;y<u;y++)g[y]>f&&(f=g[y]);return f}function ac(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),d=new Float64Array(e),g=new Int32Array(i),p=[],r=[];for(let T=0;T<e;T++)g[T]===0&&(r.push(T),a[T]=n[T],l[T]=n[T]+t[T]);let c=0;for(;c<r.length;){const T=r[c++];p.push(T);const h=l[T];for(const b of s[T])h>a[b]&&(a[b]=h,l[b]=h+t[b]),g[b]--,g[b]===0&&r.push(b)}for(let T=0;T<e;T++)l[T]===0&&t[T]>0&&(a[T]=n[T],l[T]=n[T]+t[T],p.push(T));let f=0;for(let T=0;T<e;T++)l[T]>f&&(f=l[T]);for(let T=0;T<e;T++)s[T].length===0?(d[T]=f,u[T]=f-t[T]):(d[T]=1/0,u[T]=1/0);for(let T=p.length-1;T>=0;T--){const h=p[T];if(d[h]===1/0){let b=1/0;for(const v of s[h])u[v]<b&&(b=u[v]);b===1/0?d[h]=f:d[h]=b,u[h]=d[h]-t[h]}}const y=new Set;for(let T=0;T<e;T++){const h=u[T]-a[T];Math.abs(h)<.5&&y.add(T)}return y}function rc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const $ of e.keys())u.set($,l.length),l.push($);const d=l.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const g=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const $ of e.values()){const B=Nn($.startDate).getTime();B<r&&(r=B)}const c=new Date(r);for(let $=0;$<d;$++){const B=e.get(l[$]),Q=Nn(B.startDate),Z=Nn(B.endDate);g[$]=Math.max(Kt(Q,Z),1),p[$]=Kt(c,Q)}const f=Array.from({length:d},()=>[]),y=Array.from({length:d},()=>[]),T=new Int32Array(d);for(const $ of t.values()){if(($.type||"FS")!=="FS")continue;const Q=u.get($.source),Z=u.get($.target);Q===void 0||Z===void 0||(f[Q].push(Z),y[Z].push(Q),T[Z]++)}const h=f.map($=>new Int32Array($)),b=y.map($=>new Int32Array($)),v=new Float64Array(s),m=new Float64Array(d),D=new Float64Array(d),k=new Float64Array(d),w=new Float64Array(d),E=new Float64Array(d),S=Math.max(1,Math.floor(s/100));for(let $=0;$<s;$++){for(let B=0;B<d;B++){const Q=g[B];let Z;switch(i){case"triangular":{const re=Q*(1-o),ge=Q,me=Q*(1+o*1.5);Z=nc(re,ge,me);break}case"normal":{Z=sc(Q,Q*o);break}case"uniform":{Z=oc(Q*(1-o),Q*(1+o));break}}m[B]=Math.max(.5,Z),D[B]+=m[B],k[B]+=m[B]*m[B],m[B]>g[B]&&w[B]++}if(v[$]=ic(l,u,g,m,p,h,b,T),$%S===0){const B=ac(d,m,p,h,b,T);for(const Q of B)E[Q]++}}const M=Array.from(v).sort(($,B)=>$-B),I=M.map($=>nt(c,$)),R=new Map;for(const $ of a){const B=Math.min(Math.floor($*M.length),M.length-1);R.set($,nt(c,M[B]))}let _=0;for(let $=0;$<s;$++)_+=M[$];const x=_/s,O=nt(c,x),N=Math.floor(s/2),Y=nt(c,M[N]);let W=0;for(let $=0;$<s;$++){const B=M[$]-x;W+=B*B}const j=Math.sqrt(W/s),q=nt(c,M[0]),U=nt(c,M[M.length-1]),C=new Map;for(let $=0;$<d;$++){const B=D[$]/s,Q=k[$]/s-B*B;C.set(l[$],{meanDuration:B,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:w[$]/s})}const P=Math.floor(s/S),A=new Map;for(let $=0;$<d;$++)E[$]>0&&A.set(l[$],E[$]/P);return{iterations:s,finishDates:I,percentiles:R,meanFinishDate:O,medianFinishDate:Y,earliestFinish:q,latestFinish:U,standardDeviation:j,taskRisk:C,criticalPathFrequency:A}}function lc(){if(typeof document>"u"||document.getElementById(_n))return;const e=document.createElement("style");e.id=_n,e.textContent=tc,document.head.appendChild(e)}function cc(){if(typeof document>"u")return;const e=document.getElementById(_n);e&&e.remove()}function dc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=rc(f.tasks,f.dependencies,c),g()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function g(){if(!a||!s)return;let r="",c=0;for(const[h,b]of s.criticalPathFrequency)b>c&&(c=b,r=h);let f=r;if(n){const h=n.getState().tasks.get(r);h&&(f=h.name)}let y=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const h of t.confidenceLevels){const b=s.percentiles.get(h);if(!b)continue;const v=Math.round(h*100),m=Po[h]||"#94A3B8";y+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${_o(b)}</span>
        </div>
      `}if(y+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${_o(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const h=Math.round(c*100);y+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${h}% of runs)
        </div>
      `}a.innerHTML=y;const T=a.querySelector(".ng-montecarlo-close");T&&T.addEventListener("click",()=>u())}function p(r,c){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:y}=c.config,T=c.scrollX,h=r.canvas.width/(window.devicePixelRatio||1),b=r.canvas.height/(window.devicePixelRatio||1),v=y,m=b-v,D=s.earliestFinish,k=s.latestFinish,w=Math.max(Kt(D,k),1),E=f.getColumnWidth(),S=Math.max(E,Ql),M=Math.max(Math.ceil(w),1),I=new Uint32Array(M);for(const N of s.finishDates){const Y=Kt(D,N),W=Math.min(Math.max(Math.floor(Y),0),M-1);I[W]++}let R=0;for(let N=0;N<M;N++)I[N]>R&&(R=I[N]);if(R===0)return;r.save(),r.beginPath(),r.rect(0,v,h,m),r.clip(),r.translate(-T,0);const _=s.finishDates[Math.floor(s.finishDates.length*.1)],x=s.finishDates[Math.floor(s.finishDates.length*.9)];if(_&&x){const N=f.dateToX(_),Y=f.dateToX(x),W=r.createLinearGradient(N,0,Y,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=ec*5,r.fillRect(N,v,Y-N,m),r.globalAlpha=1}const O=b-8;for(let N=0;N<M;N++){if(I[N]===0)continue;const Y=nt(D,N),W=f.dateToX(Y),j=I[N]/R*Jl,q=M>1?N/(M-1):.5;let U,C,P;if(q<.5){const A=q*2;U=Math.round(34+200*A),C=Math.round(197+-18*A),P=Math.round(94+-86*A)}else{const A=(q-.5)*2;U=Math.round(234+5*A),C=Math.round(179+-111*A),P=Math.round(8+60*A)}r.fillStyle=`rgba(${U}, ${C}, ${P}, 0.6)`,r.fillRect(W,O-j,Math.max(S-1,1),j)}r.setLineDash(Ro),r.lineWidth=1.5;for(const[N,Y]of s.percentiles){const W=f.dateToX(Y),j=Po[N]||"#94A3B8",q=`P${Math.round(N*100)}`;r.strokeStyle=j,r.beginPath(),r.moveTo(W,v),r.lineTo(W,b),r.stroke(),r.setLineDash([]),r.fillStyle=j,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const U=r.measureText(`${q}: ${$o(Y)}`).width,C=`${q}: ${$o(Y)}`,P=U+8,A=16,$=W-P/2,B=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo($+3,B),r.lineTo($+P-3,B),r.arcTo($+P,B,$+P,B+3,3),r.lineTo($+P,B+A-3),r.arcTo($+P,B+A,$+P-3,B+A,3),r.lineTo($+3,B+A),r.arcTo($,B+A,$,B+A-3,3),r.lineTo($,B+3),r.arcTo($,B,$+3,B,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=j,r.fillText(C,W,B+3),r.setLineDash(Ro)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,lc(),i.push(r.on("montecarlo:run",(...c)=>{const f=c[0];l(f)}),r.on("montecarlo:result",(...c)=>{const f=c[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...c)=>{const f=c[0];f&&d(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,f){!o||!s||p(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&g()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),cc(),s=null,n=null}}}const qt=864e5,No=400,On="nimbus-gantt-narrative-styles",Oo=300;function Fe(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Hn(e,t){return Math.round((t.getTime()-e.getTime())/qt)}function Ho(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function xo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*qt)}function Bo(e,t){return new Date(e.getTime()+t*qt)}function uc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const S of n){const M=Fe(S.startDate).getTime(),I=Fe(S.endDate).getTime();M<s&&(s=M),I>o&&(o=I)}const i=new Date(s),a=new Date(o),l=Hn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const d=new Map,g=new Map;for(const S of t.values())!e.has(S.source)||!e.has(S.target)||(d.has(S.source)||d.set(S.source,[]),d.get(S.source).push(S.target),g.has(S.target)||g.set(S.target,[]),g.get(S.target).push(S.source));const p=pc(n,t),r=xo(i),c=xo(a),f=[];let y=r;for(;y.getTime()<=c.getTime();)f.push({start:new Date(y),end:Bo(y,6)}),y=Bo(y,7);const T=[];for(let S=0;S<f.length;S++){const M=f[S],I=M.start,R=M.end,_=[],x=[],O=[],N=[],Y=[],W=[],j=[];for(const A of n){const $=Fe(A.startDate),B=Fe(A.endDate);$>=I&&$<=R&&(_.push(A),A.isMilestone?(W.push(A),j.push(`Milestone: ${A.name}`)):j.push(`Started: ${A.name}`)),B>=I&&B<=R&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(x.push(A),j.push(`Completed: ${A.name}`)),$<=R&&B>=I&&(Y.push(A),$<I&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&O.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&N.push(A))}for(const A of n)if(A.isMilestone){const $=Fe(A.startDate);$>=I&&$<=R&&!W.includes(A)&&(W.push(A),j.push(`Milestone: ${A.name}`))}const q=Y.filter(A=>p.has(A.id)),U=gc(_,x,O,Y,q),C=hc(_,x,O,N,Y,q,W,d,e),P=`Week ${S+1} (${Ho(I)}–${Ho(R)})`;T.push({weekLabel:P,headline:U,body:C,metrics:{started:_.length,completed:x.length,delayed:O.length,onTrack:N.length},events:j})}const h=n.length,b=n.filter(S=>S.isCompleted||S.progress!==void 0&&S.progress>=1).length,v=n.filter(S=>!S.isCompleted&&S.progress!==void 0&&S.progress>0&&S.progress<1).length,m=h-b-v,D=h>0?Math.round(b/h*100):0,k=D>=75?"strong":D>=50?"moderate":D>=25?"early-stage":"just getting started",w=`This project spans ${l} days across ${f.length} weeks with ${h} tasks. Progress is ${k} at ${D}% completion (${b} done, ${v} in progress, ${m} not started).`,E=fc(n,p,d,g,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:w,chapters:T,insights:E}}function gc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function hc(e,t,n,s,o,i,a,l,u){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(f=>f.name).join(", ");d.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const f=l.get(c.id);if(f)for(const y of f){const T=u.get(y);T&&!r.includes(T.name)&&r.push(T.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const g=new Map;for(const r of o)r.assignee&&g.set(r.assignee,(g.get(r.assignee)||0)+1);const p=Array.from(g.entries()).sort((r,c)=>c[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function fc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const T=e.filter(v=>t.has(v.id)),h=T.slice(0,4).map(v=>v.name).join(", "),b=T.length>4?` and ${T.length-4} more`:"";l.push(`The critical path runs through ${h}${b} — any delay here pushes the project finish.`)}const u=new Map;for(const T of e)T.assignee&&!T.isCompleted&&u.set(T.assignee,(u.get(T.assignee)||0)+1);const d=Array.from(u.entries()).sort((T,h)=>h[1]-T[1]);d.length>0&&d[0][1]>=2&&l.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const g=e.filter(T=>T.isCompleted?!1:Fe(T.startDate)<a&&(T.progress===void 0||T.progress===0));g.length>0&&l.push(`${g.length} task${g.length>1?"s have":" has"} zero progress despite being past ${g.length>1?"their":"its"} start date${g.length>1?"s":""}.`);const p=Hn(o,i),r=Hn(o,a);if(r>0&&p>0){const T=Math.round(r/p*100),h=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,b=Math.round(h/e.length*100),v=b-T;Math.abs(v)>=5?v>0?l.push(`Project is running ahead: ${b}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is running behind: only ${b}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${b}% complete at ${T}% of elapsed time.`)}const c=e.filter(T=>{if(T.isCompleted||T.progress!==void 0&&T.progress>0)return!1;const h=s.get(T.id);return!h||h.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,y="";for(const T of e){const h=n.get(T.id);h&&h.length>f&&(f=h.length,y=T.name)}return f>=3&&l.push(`"${y}" is a bottleneck with ${f} downstream tasks depending on it.`),l}function pc(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const f=Fe(c.endDate).getTime();i.set(c.id,f)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),f=i.get(c);for(const y of s.get(c)){const T=n.get(y.target),h=Fe(T.endDate).getTime()-Fe(T.startDate).getTime(),b=f+y.lag*qt+h;b>i.get(y.target)&&i.set(y.target,b);const v=l.get(y.target)-1;l.set(y.target,v),v===0&&a.push(y.target)}}let u=-1/0,d="";for(const[c,f]of i)f>u&&(u=f,d=c);if(!d)return new Set;const g=new Set,p=new Map;for(const c of e)p.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||p.get(c.target).push({source:c.source,lag:c.lag||0}));let r=d;for(;r;){g.add(r);const c=p.get(r);if(!c||c.length===0)break;let f="",y=-1/0;for(const T of c){const h=i.get(T.source)||0;h>y&&(y=h,f=T.source)}if(!f||g.has(f))break;r=f}return g}const mc=`
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
    transition: opacity ${Oo}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${No}px;
    width: ${No}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${Oo}ms ease;
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
`;function Tc(){if(typeof document>"u"||document.getElementById(On))return;const e=document.createElement("style");e.id=On,e.textContent=mc,document.head.appendChild(e)}function yc(){if(typeof document>"u")return;const e=document.getElementById(On);e&&e.remove()}function bc(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function vc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=uc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),g()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function g(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",c.appendChild(f);const y=document.createElement("span");y.textContent="Project Story",c.appendChild(y),r.appendChild(c);const T=document.createElement("div");T.style.display="flex",T.style.alignItems="center",T.style.gap="4px";const h=document.createElement("button");h.className="ng-narrative-refresh",h.innerHTML="↻",h.title="Regenerate",h.addEventListener("click",()=>{l(),g()}),T.appendChild(h);const b=document.createElement("button");b.className="ng-narrative-close",b.innerHTML="×",b.addEventListener("click",d),T.appendChild(b),r.appendChild(T),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const k=document.createElement("div");k.className="ng-narrative-empty",k.textContent="No weekly chapters to display.",a.appendChild(k)}else for(const k of t.chapters){const w=document.createElement("div");w.className="ng-narrative-chapter";const E=bc(k),S=document.createElement("div");S.className=`ng-narrative-chapter-header ng-${E}`;const M=document.createElement("div");M.className="ng-narrative-week-label",M.textContent=k.weekLabel,S.appendChild(M);const I=document.createElement("div");I.className="ng-narrative-headline",I.textContent=k.headline,S.appendChild(I),w.appendChild(S);const R=document.createElement("div");if(R.className="ng-narrative-metrics",k.metrics.started>0&&R.appendChild(p("started",`${k.metrics.started} started`)),k.metrics.completed>0&&R.appendChild(p("completed",`${k.metrics.completed} done`)),k.metrics.delayed>0&&R.appendChild(p("delayed",`${k.metrics.delayed} delayed`)),k.metrics.onTrack>0&&R.appendChild(p("ontrack",`${k.metrics.onTrack} on track`)),R.children.length>0&&w.appendChild(R),k.body){const _=document.createElement("div");_.className="ng-narrative-body",_.textContent=k.body,w.appendChild(_)}a.appendChild(w)}if(t.insights.length>0){const k=document.createElement("div");k.className="ng-narrative-insights";const w=document.createElement("div");w.className="ng-narrative-insights-title",w.innerHTML="<span>💡</span> Key Insights",k.appendChild(w);for(const E of t.insights){const S=document.createElement("div");S.className="ng-narrative-insight";const M=document.createElement("span");M.className="ng-narrative-insight-icon",M.textContent="•",S.appendChild(M);const I=document.createElement("span");I.textContent=E,S.appendChild(I),k.appendChild(S)}a.appendChild(k)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const D=new Date(t.generatedAt);m.textContent=`Generated ${D.toLocaleString()}`,a.appendChild(m)}function p(r,c){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=c,f}return{name:"NarrativePlugin",install(r){e=r,Tc(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&g()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),g())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),yc(),e=null,t=null,n=!1}}}const wc=864e5,Sc=10,xn="nimbus-gantt-whatif-styles",Fo=.25,Ec=.6,Zt=6,Yo="#38A169",Uo="#E53E3E",Wo="#A0AEC0",Bn=36,Dc="#F6AD55",Xo="#1a202c",kc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Bn}px;
    background: ${Dc};
    color: ${Xo};
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
    color: ${Xo};
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
    top: ${Bn}px;
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
    top: ${Bn+8}px;
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
    color: ${Yo};
  }
  .ng-whatif-summary-value--worsened {
    color: ${Uo};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${Wo};
  }
`;function Ye(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function zo(e){const t=Ye(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function Jt(e,t){return Math.round((t.getTime()-e.getTime())/wc)}function Go(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function Cc(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function Mc(e){return{...e}}function Ic(){if(typeof document>"u"||document.getElementById(xn))return;const e=document.createElement("style");e.id=xn,e.textContent=kc,document.head.appendChild(e)}function Ac(){if(typeof document>"u")return;const e=document.getElementById(xn);e&&e.remove()}function Lc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,Cc(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,Mc(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function Vo(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function Rc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,d=null,g=null,p=null,r=null,c=null,f=null;function y(){t||!e||(o=Lc(e.getState()),i=[],t=!0,n=!1,E())}function T(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],E(),I(),_())}function h(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,S(),I())}function b(C){if(!t||!e||!o)return;a.length>=Sc&&a.shift();const P=e.getState(),A=Vo(P.tasks),$=Ye(o.projectFinish),B=Ye(A),Q=Jt($,B);let Z=0;for(const[ge,me]of o.tasks){const F=P.tasks.get(ge);if(!F){Z++;continue}(F.startDate!==me.startDate||F.endDate!==me.endDate||F.assignee!==me.assignee)&&Z++}for(const ge of P.tasks.keys())o.tasks.has(ge)||Z++;const re={id:Go(),name:C,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:Q,tasksAffected:Z}};a.push(re),Y()}function v(C){if(!e||!o)return;const P=a.find(A=>A.id===C);if(P){t||y(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of P.changes)D(A);i=[...P.changes],S()}}function m(C){a=a.filter(P=>P.id!==C),Y()}function D(C){if(e)switch(C.type){case"move":case"resize":C.taskId&&C.after&&C.after.startDate&&C.after.endDate&&e.dispatch({type:C.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:C.taskId,startDate:C.after.startDate,endDate:C.after.endDate});break;case"add":C.after&&e.dispatch({type:"ADD_TASK",task:C.after});break;case"remove":C.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:C.taskId});break;case"reassign":C.taskId&&C.after&&e.dispatch({type:"UPDATE_TASK",taskId:C.taskId,changes:C.after});break;case"add-dependency":C.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:C.dependencyId||Go(),source:C.dependency.source,target:C.dependency.target,type:C.dependency.type||"FS"}});break;case"remove-dependency":C.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:C.dependencyId});break}}function k(){t&&(n=!n,n?M():I())}function w(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const C=e.getState(),P=Vo(C.tasks),A=Ye(o.projectFinish),$=Ye(P),B=Jt(A,$);let Q=0;for(const[Z,re]of o.tasks){const ge=C.tasks.get(Z);if(!ge){Q++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&Q++}for(const Z of C.tasks.keys())o.tasks.has(Z)||Q++;return{baselineFinish:o.projectFinish,sandboxFinish:P,deltaDays:B,tasksAffected:Q}}function E(){u&&u.classList.toggle("ng-hidden",!t)}function S(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function M(){if(!g)return;const C=w();let P="ng-whatif-summary-value--unchanged",A="No change";C.deltaDays<0?(P="ng-whatif-summary-value--improved",A=`${Math.abs(C.deltaDays)} day${Math.abs(C.deltaDays)!==1?"s":""} earlier`):C.deltaDays>0&&(P="ng-whatif-summary-value--worsened",A=`${C.deltaDays} day${C.deltaDays!==1?"s":""} later`),g.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${zo(C.baselineFinish)} &rarr; ${zo(C.sandboxFinish)}
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
    `,g.classList.remove("ng-hidden")}function I(){g&&g.classList.add("ng-hidden")}function R(){s=!s,d&&d.classList.toggle("ng-open",s),s&&Y()}function _(){s=!1,d&&d.classList.remove("ng-open")}function x(){r&&(r.classList.add("ng-active"),c==null||c.focus())}function O(){r&&r.classList.remove("ng-active"),c&&(c.value="")}function N(){if(!c)return;const C=c.value.trim();C&&(b(C),O())}function Y(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(C=>{var B;const P=new Date(C.createdAt).toLocaleDateString(),A=((B=C.result)==null?void 0:B.criticalPathDelta)??0;let $="No impact";return A<0?$=`${Math.abs(A)}d earlier`:A>0&&($=`${A}d later`),`
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
        `}).join("")}}function W(C){const P=document.createElement("div");return P.textContent=C,P.innerHTML}function j(C){const P=C.target,A=P.getAttribute("data-action"),$=P.getAttribute("data-id");if(!(!A||!$))switch(A){case"load":v($),_();break;case"compare":v($),n=!0,M(),_();break;case"delete":m($);break}}function q(C,P){switch(C.type){case"TASK_MOVE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"move",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"TASK_RESIZE":{const A=P.tasks.get(C.taskId);A&&i.push({type:"resize",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:C.task.id,after:{...C.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:C.taskId,before:P.tasks.get(C.taskId)?{...P.tasks.get(C.taskId)}:void 0});break;case"UPDATE_TASK":{const A=P.tasks.get(C.taskId);A&&i.push({type:"reassign",taskId:C.taskId,before:{...A},after:C.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:C.dependency.id,dependency:{source:C.dependency.source,target:C.dependency.target,type:C.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:C.dependencyId});break}S()}function U(C,P,A,$,B,Q){const Z=Math.min(Q,$/2,B/2);C.beginPath(),C.moveTo(P+Z,A),C.lineTo(P+$-Z,A),C.arcTo(P+$,A,P+$,A+Z,Z),C.lineTo(P+$,A+B-Z),C.arcTo(P+$,A+B,P+$-Z,A+B,Z),C.lineTo(P+Z,A+B),C.arcTo(P,A+B,P,A+B-Z,Z),C.lineTo(P,A+Z),C.arcTo(P,A,P+Z,A,Z),C.closePath()}return{name:"WhatIfPlugin",install(C){e=C,Ic(),l.push(C.on("whatif:enter",()=>y())),l.push(C.on("whatif:exit",()=>T())),l.push(C.on("whatif:compare",()=>k())),l.push(C.on("whatif:discard",()=>h())),l.push(C.on("whatif:save",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?b(A):x()})),l.push(C.on("whatif:load",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A?v(A):R()})),l.push(C.on("whatif:list-scenarios",(...P)=>{const A=typeof P[0]=="function"?P[0]:void 0;A?A([...a]):R()})),l.push(C.on("whatif:delete-scenario",(...P)=>{const A=typeof P[0]=="string"?P[0]:void 0;A&&m(A)}))},middleware(C,P){if(!t){P(C);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(C.type)&&e){const $=e.getState();q(C,$)}P(C)},renderCanvas(C,P,A){if(!t||!e)return;const{theme:$,headerHeight:B,barHeight:Q}=P.config,Z=P.scrollX,re=P.scrollY,ge=B,me=e.getTimeScale(),F=$.barBorderRadius;if(C.save(),C.beginPath(),C.rect(0,ge,C.canvas.width,C.canvas.height-ge),C.clip(),C.translate(-Z,0),o){const ee=new Set;for(const K of A){const J=o.tasks.get(K.taskId),ne=P.tasks.get(K.taskId);(!J&&ne||J&&ne&&(J.startDate!==ne.startDate||J.endDate!==ne.endDate||J.assignee!==ne.assignee))&&ee.add(K.taskId)}for(const K of A){if(!ee.has(K.taskId))continue;const J=K.x,ne=K.barY-re,de=K.width,ie=K.barHeight;ne+ie<ge||ne>C.canvas.height||(C.save(),C.setLineDash([4,3]),C.strokeStyle="#F6AD55",C.lineWidth=2,U(C,J,ne,de,ie,F),C.stroke(),C.restore())}}if(n&&o){const ee=Q*Ec;for(const K of A){if(K.isMilestone)continue;const J=o.tasks.get(K.taskId);if(!J)continue;const ne=P.tasks.get(K.taskId);if(!ne)continue;const de=Ye(J.startDate),ie=Ye(J.endDate),fe=Ye(ne.startDate),ce=Ye(ne.endDate),Te=Jt(de,fe),ye=Jt(ie,ce);if(Te===0&&ye===0)continue;let X=Wo;ye<0?X=Yo:ye>0&&(X=Uo);const L=me.dateToX(de),H=me.dateToX(ie),z=Math.max(H-L,2),G=K.barY-re,V=G+Q+2;C.save(),C.globalAlpha=Fo,C.fillStyle=X,U(C,L,V,z,ee,F),C.fill(),C.globalAlpha=Fo*2,C.strokeStyle=X,C.lineWidth=1,C.stroke(),C.restore();const te=L+z/2,oe=V+ee/2,ae=K.x+K.width/2,le=G+Q/2;C.save(),C.globalAlpha=.6,C.strokeStyle=X,C.lineWidth=1.5,C.setLineDash([3,2]),C.beginPath(),C.moveTo(te,oe),C.lineTo(ae,le),C.stroke();const pe=Math.atan2(le-oe,ae-te),be=ae,Ce=le;C.setLineDash([]),C.beginPath(),C.moveTo(be,Ce),C.lineTo(be-Zt*Math.cos(pe-Math.PI/6),Ce-Zt*Math.sin(pe-Math.PI/6)),C.lineTo(be-Zt*Math.cos(pe+Math.PI/6),Ce-Zt*Math.sin(pe+Math.PI/6)),C.closePath(),C.fillStyle=X,C.fill(),C.restore()}}C.restore()},renderDOM(C,P){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const $=document.createElement("span");$.className="ng-whatif-badge",$.textContent="What-If Mode",A.appendChild($);const B=document.createElement("span");B.textContent="Changes are hypothetical",B.style.fontSize="12px",B.style.opacity="0.7",A.appendChild(B);const Q=document.createElement("span");Q.textContent="·",Q.style.opacity="0.4",A.appendChild(Q),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",A.appendChild(p),u.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",c=document.createElement("input"),c.type="text",c.placeholder="Scenario name...",c.addEventListener("keydown",ne=>{ne.key==="Enter"&&N(),ne.key==="Escape"&&O()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",N);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>O()),r.appendChild(c),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const me=document.createElement("button");me.className="ng-whatif-btn",me.textContent="Scenarios",me.addEventListener("click",()=>R()),Z.appendChild(me);const F=document.createElement("button");F.className="ng-whatif-btn ng-whatif-btn--primary",F.textContent="Compare with Baseline",F.addEventListener("click",()=>k()),Z.appendChild(F);const ee=document.createElement("button");ee.className="ng-whatif-btn",ee.textContent="Save Scenario",ee.addEventListener("click",()=>x()),Z.appendChild(ee);const K=document.createElement("button");K.className="ng-whatif-btn ng-whatif-btn--danger",K.textContent="Discard",K.addEventListener("click",()=>h()),Z.appendChild(K);const J=document.createElement("button");J.className="ng-whatif-btn ng-whatif-btn--danger",J.textContent="Exit",J.addEventListener("click",()=>T()),Z.appendChild(J),u.appendChild(Z),C.appendChild(u)}if(g||(g=document.createElement("div"),g.className="ng-whatif-summary ng-hidden",C.appendChild(g)),!d){d=document.createElement("div"),d.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const $=document.createElement("span");$.textContent="Saved Scenarios",A.appendChild($);const B=document.createElement("button");B.className="ng-whatif-panel-close",B.textContent="×",B.addEventListener("click",()=>_()),A.appendChild(B),d.appendChild(A),f=document.createElement("div"),f.addEventListener("click",j),d.appendChild(f),C.appendChild(d),Y()}E(),n&&M()},destroy(){for(const C of l)C();l.length=0,u&&(u.remove(),u=null),d&&(d.remove(),d=null),g&&(g.remove(),g=null),p=null,r=null,c=null,f=null,Ac(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Fn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},Pc=261.63;function $c(e){return Pc*Math.pow(2,e/12)}function _c(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return $c(n?a+12:a)}const Yn="nimbus-gantt-sonification-styles",Un=64,Qt=64,jo=.05,Nc=.1,Oc=.7,Ko=.2,Wn="#F6AD55",Hc=2,xc="rgba(246, 173, 85, 0.35)",qo=12,Bc=`
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
    height: ${Un}px;
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
`;function Xn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Fc(){if(typeof document>"u"||document.getElementById(Yn))return;const e=document.createElement("style");e.id=Yn,e.textContent=Bc,document.head.appendChild(e)}function Yc(){if(typeof document>"u")return;const e=document.getElementById(Yn);e&&e.remove()}function Uc(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,d=null,g=null;const p=new Map;let r="stopped",c=0,f=0,y=0,T=0,h=0,b=0,v=0,m=null,D=null,k=null,w=null,E=null,S=null;const M=[];let I=[],R=[];function _(){if(l)return;const F=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;F&&(l=new F,u=l.createGain(),u.gain.value=i,d=l.createAnalyser(),d.fftSize=256,g=new Uint8Array(d.frequencyBinCount),u.connect(d),d.connect(l.destination))}function x(){l&&l.state==="suspended"&&l.resume()}function O(){if(!a)return;const F=a.getState(),ee=Date.now();let K=1/0,J=-1/0;const ne=[],de=new Set,ie=F.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of F.tasks){const ye=Xn(Te.startDate).getTime(),X=Xn(Te.endDate).getTime();ye<K&&(K=ye),X>J&&(J=X);const L=Te.groupId||"__default__";de.add(L);const H=fe.get(ce)??0,z=!Te.isCompleted&&X<ee&&(Te.progress??0)<1;ne.push({id:ce,startMs:ye,endMs:X,rowIndex:H,progress:Te.progress??0,groupId:L,isCritical:!1,isOverdue:z})}I=ne,R=Array.from(de),h=K===1/0?0:K,b=J===-1/0?0:J,v=Math.max(b-h,1)}function N(F){if(!l||!u||p.has(F.id))return;const ee=Fn[n]||Fn.major,K=_c(F.rowIndex,ee,F.isCritical),J=l.createOscillator();J.type=s,J.frequency.value=K,F.isOverdue&&(J.detune.value=25);const ne=.3+F.progress*.7,de=F.isOverdue?1.3:1,ie=Math.min(ne*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+jo),fe.gain.linearRampToValueAtTime(ie*Oc,l.currentTime+jo+Nc);const ce=l.createStereoPanner();if(R.length<=1)ce.pan.value=0;else{const Te=R.indexOf(F.groupId);ce.pan.value=R.length>1?Te/(R.length-1)*2-1:0}J.connect(fe),fe.connect(ce),ce.connect(u),J.start(),p.set(F.id,{taskId:F.id,oscillator:J,gainNode:fe,panNode:ce})}function Y(F){const ee=p.get(F);if(!ee||!l)return;const K=l.currentTime;ee.gainNode.gain.cancelScheduledValues(K),ee.gainNode.gain.setValueAtTime(ee.gainNode.gain.value,K),ee.gainNode.gain.linearRampToValueAtTime(0,K+Ko),ee.oscillator.stop(K+Ko+.05),p.delete(F)}function W(){for(const F of Array.from(p.keys()))Y(F)}function j(){if(r!=="playing"||!l)return;const F=l.currentTime-c;if(f=Math.min(F/o,1),f>=1){C();return}const ee=h+f*v;for(const K of I){const J=ee>=K.startMs&&ee<K.endMs,ne=p.has(K.id);J&&!ne?N(K):!J&&ne&&Y(K.id)}Z(),T=requestAnimationFrame(j)}function q(){_(),x(),l&&(O(),r==="paused"?c=l.currentTime-y*o:(c=l.currentTime,f=0),r="playing",$(),B(),T=requestAnimationFrame(j))}function U(){r==="playing"&&(r="paused",y=f,W(),cancelAnimationFrame(T),$())}function C(){r="stopped",f=0,y=0,W(),cancelAnimationFrame(T),$(),Q()}function P(){r==="playing"?U():q()}function A(F){const ee=Xn(F).getTime(),K=Math.max(0,Math.min((ee-h)/v,1));r==="playing"&&l?c=l.currentTime-K*o:(y=K,f=K)}function $(){E&&(r==="playing"?(E.innerHTML=ge(),E.classList.add("ng-son-btn--active")):(E.innerHTML=re(),E.classList.remove("ng-son-btn--active")))}function B(){D&&D.classList.remove("ng-hidden")}function Q(){D&&D.classList.add("ng-hidden")}function Z(){if(!d||!g||!w||!k)return;d.getByteFrequencyData(g);const F=k.width,ee=k.height;w.clearRect(0,0,F,ee);const K=w.createLinearGradient(0,0,0,ee);K.addColorStop(0,"rgba(26, 32, 44, 0)"),K.addColorStop(1,"rgba(26, 32, 44, 0.6)"),w.fillStyle=K,w.fillRect(0,0,F,ee);const J=F/Qt*.8,ne=F/Qt*.2,de=Math.floor(g.length/Qt);for(let ie=0;ie<Qt;ie++){let fe=0;for(let z=0;z<de;z++)fe+=g[ie*de+z]??0;const ce=fe/de,Te=ce/255*ee*.85,ye=ie*(J+ne),X=ee-Te,L=30+ce/255*15,H=55+ce/255*15;w.fillStyle=`hsl(${L}, 90%, ${H}%)`,w.fillRect(ye,X,J,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function me(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(F){a=F,Fc(),M.push(F.on("sonification:play",()=>q())),M.push(F.on("sonification:pause",()=>U())),M.push(F.on("sonification:stop",()=>C())),M.push(F.on("sonification:scrub",(...ee)=>{const K=typeof ee[0]=="string"?ee[0]:void 0;K&&A(K)})),M.push(F.on("sonification:configure",(...ee)=>{const K=ee[0];K&&(K.tempo!==void 0&&(t=K.tempo),K.scale!==void 0&&(n=K.scale),K.instrument!==void 0&&(s=K.instrument),K.duration!==void 0&&(o=K.duration),K.volume!==void 0&&(i=K.volume,u&&(u.gain.value=i)))}))},renderCanvas(F,ee,K){if(r==="stopped"||!a)return;const{headerHeight:J}=ee.config,ne=ee.scrollX,de=ee.scrollY,ie=J,fe=a.getTimeScale(),ce=h+f*v,Te=new Date(ce),ye=fe.dateToX(Te);F.save(),F.beginPath(),F.rect(0,ie,F.canvas.width,F.canvas.height-ie),F.clip(),F.translate(-ne,0),F.save(),F.shadowColor=Wn,F.shadowBlur=qo,F.strokeStyle=Wn,F.lineWidth=Hc,F.beginPath(),F.moveTo(ye,ie),F.lineTo(ye,F.canvas.height+de),F.stroke(),F.restore();const X=new Map;for(const L of K)X.set(L.taskId,L);for(const L of p.values()){const H=X.get(L.taskId);if(!H)continue;const z=H.x,G=H.barY-de,V=H.width,te=H.barHeight;if(G+te<ie||G>F.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);F.save(),F.globalAlpha=ae,F.shadowColor=xc,F.shadowBlur=qo,F.fillStyle=Wn;const le=Math.min(ee.config.theme.barBorderRadius,V/2,te/2);F.beginPath(),F.moveTo(z+le,G),F.lineTo(z+V-le,G),F.arcTo(z+V,G,z+V,G+le,le),F.lineTo(z+V,G+te-le),F.arcTo(z+V,G+te,z+V-le,G+te,le),F.lineTo(z+le,G+te),F.arcTo(z,G+te,z,G+te-le,le),F.lineTo(z,G+le),F.arcTo(z,G,z+le,G,le),F.closePath(),F.fill(),F.restore()}F.restore()},renderDOM(F,ee){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=re(),E.title="Play / Pause",E.addEventListener("click",()=>P()),m.appendChild(E),S=document.createElement("button"),S.className="ng-son-btn",S.innerHTML=me(),S.title="Stop",S.addEventListener("click",()=>C()),m.appendChild(S);const K=document.createElement("div");K.className="ng-son-sep",m.appendChild(K);const J=document.createElement("div");J.style.display="flex",J.style.flexDirection="column",J.style.alignItems="center",J.style.gap="2px";const ne=document.createElement("span");ne.className="ng-son-label",ne.textContent="Tempo",J.appendChild(ne);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),J.appendChild(de),m.appendChild(J);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const H of Object.keys(Fn)){const z=document.createElement("option");z.value=H,z.textContent=H.charAt(0).toUpperCase()+H.slice(1),H===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const ye=document.createElement("div");ye.style.display="flex",ye.style.flexDirection="column",ye.style.alignItems="center",ye.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",ye.appendChild(X);const L=document.createElement("input");L.type="range",L.className="ng-son-slider",L.min="0",L.max="100",L.value=String(Math.round(i*100)),L.addEventListener("input",()=>{i=Number(L.value)/100,u&&(u.gain.value=i)}),ye.appendChild(L),m.appendChild(ye),F.appendChild(m)}if(!D){D=document.createElement("div"),D.className="ng-sonification-waveform ng-hidden",k=document.createElement("canvas"),w=k.getContext("2d");const K=(typeof window<"u"?window.devicePixelRatio:1)||1,J=F.getBoundingClientRect();k.width=J.width*K,k.height=Un*K,k.style.width="100%",k.style.height=Un+"px",w&&w.scale(K,K),D.appendChild(k),F.appendChild(D)}},destroy(){for(const F of M)F();M.length=0,C(),W(),l&&(l.close(),l=null),u=null,d=null,g=null,m&&(m.remove(),m=null),D&&(D.remove(),D=null),k=null,w=null,E=null,S=null,Yc(),a=null,I=[],R=[]}}}return se.BaselinePlugin=ra,se.ConfigPanelPlugin=el,se.CriticalPathPlugin=Zi,se.DARK_THEME=ls,se.DarkThemePlugin=Sa,se.DependencyRenderer=is,se.EventBus=Vn,se.ExportPlugin=pa,se.GroupingPlugin=zi,se.HeatmapViewPlugin=ul,se.HitTest=ss,se.KeyboardPlugin=Mi,se.LIGHT_THEME=an,se.LayoutEngine=Jn,se.MSProjectPlugin=Ba,se.MilestonePlugin=_i,se.MiniMapPlugin=El,se.MonteCarloPlugin=dc,se.MotionControlPlugin=$a,se.NarrativePlugin=vc,se.NetworkGraphPlugin=jr,se.NimbusGantt=Ei,se.ResourceLevelingPlugin=or,se.RiskAnalysisPlugin=Lr,se.SonificationPlugin=Uc,se.SplitTaskPlugin=Ka,se.TelemetryPlugin=La,se.TimeScale=qn,se.TimeTravelPlugin=Zl,se.TimelineNotesPlugin=Fl,se.TooltipManager=rs,se.UndoRedoPlugin=ki,se.VirtualScrollPlugin=ua,se.WhatIfPlugin=Rc,se.WorkCalendarPlugin=Ma,se.computeCPM=dn,se.exportMSProjectXML=bn,se.importMSProjectXML=yn,se.parseDate=nn,se.resolveConfig=cs,Object.defineProperty(se,Symbol.toStringTag,{value:"Module"}),se})({});
//# sourceMappingURL=nimbus-gantt.iife.js.map
