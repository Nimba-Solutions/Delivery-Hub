var NimbusGantt=(function(j){"use strict";function $e(e,t){const n=new Map;for(const l of e.values()){const g=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(g);d||(d=[],n.set(g,d)),d.push(l)}const s=[];function o(l,g){const d=l.sortOrder??Number.MAX_SAFE_INTEGER,u=g.sortOrder??Number.MAX_SAFE_INTEGER;return d!==u?d-u:l.name.localeCompare(g.name)}function i(l,g,d){const u=n.get(l);return u?(u.sort(o),u.map(p=>{const c=n.has(p.id)&&t.has(p.id),f=d,y={task:p,children:[],depth:g,expanded:c,visible:f,rowIndex:-1};return f&&(y.rowIndex=s.length,s.push(p.id)),y.children=i(p.id,g+1,f&&c),y})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function at(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class _n{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Ao(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Ao(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=$e(n,e.expandedIds),a=at(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=$e(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=$e(n,e.expandedIds),i=at(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=$e(n,e.expandedIds),i=at(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=$e(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=$e(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=$e(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=at(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}class On{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const jt=864e5,Ro=jt*7,Lo={day:40,week:120,month:180,quarter:200},Nn=["January","February","March","April","May","June","July","August","September","October","November","December"],Hn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class Bn{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=Lo[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/jt)}countWeeks(){return Math.ceil(this.totalMs/Ro)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=xn(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=qt(i),l=this.dateToX(i),g=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${Nn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:g-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=xn(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${Hn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=qt(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,g=this.dateToX(a),d=this.dateToX(l);t.push({label:`${Nn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:g,width:d-g,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:Hn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=qt(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,g=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),u=this.dateToX(g);t.push({label:String(i.getUTCFullYear()),x:d,width:u-d,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,g=a*this.columnWidth;n.push({label:`Q${l}`,x:g,width:this.columnWidth,date:new Date(o)}),o=Po(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,g=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),u=this.dateToX(g);t.push({label:String(i.getUTCFullYear()),x:d,width:u-d,date:new Date(l)}),i=a}return[t,n]}}function xn(e,t){return new Date(e.getTime()+t*jt)}function Po(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function qt(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class Fn{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],g=n.get(l);if(!g)continue;const d=Zt(g.startDate),u=Zt(g.endDate),p=s.dateToX(d),r=s.dateToX(u)-p,c=Math.max(r,o.minBarWidth),f=a*o.rowHeight,y=f+(o.rowHeight-o.barHeight)/2,m=c*(g.progress||0),h=g.color||o.colorMap[g.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:f,width:c,barY:y,barHeight:o.barHeight,progressWidth:m,color:h,textColor:o.theme.barTextColor,label:g.name,isMilestone:g.isMilestone||!1})}return i}}function Zt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Un=864e5,Yn=1,$o=2,_o=.5,Oo=2,Wn=8,No=6,Xn=2;class Ho{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:g}=t,{theme:d}=g,u=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=g.headerHeight,f=a-c;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,f),o.clip(),o.translate(-u,0),g.showWeekends&&this.renderWeekendShading(t,s,c,f,d),this.renderGridLines(s,c,f,d,u),this.renderAltRows(t,n,c,d,u,p);const y=this.getTodayX(t,g,s);g.showToday&&y!==null&&this.renderTodayBackground(y,s,c,f,d),this.renderTaskBars(t,n,g,d,u,p,c,f),g.showToday&&y!==null&&this.renderTodayLine(y,c,f,d),o.restore(),this.renderHeader(s,g,d,u)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,g=new Date(a);g.setUTCHours(0,0,0,0);const d=l.getTime();for(;g.getTime()<=d;){const u=g.getUTCDay();if(u===0||u===6){const p=n.dateToX(g),r=new Date(g.getTime()+Un),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}g.setTime(g.getTime()+Un)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=_o;for(const g of l){const d=this.snapToPixel(g);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:g}=this,d=t.config.rowHeight,u=t.flatVisibleIds.length;for(let p=0;p<u;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,g+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=n.getColumnWidth();this.fillRect(t,s,a,o,i.todayBg)}renderTaskBars(t,n,s,o,i,a,l,g){const{ctx:d}=this,u=o.barBorderRadius;for(const p of n){const r=p.x,c=p.barY-a+l,f=p.width,y=p.barHeight;if(!(c+y<l||c>l+g)){if(p.isMilestone){this.renderMilestone(r,c,y,p.color,o,t.selectedIds.has(p.taskId));continue}if(this.fillRoundedRect(r,c,f,y,u,p.color),s.showProgress&&p.progressWidth>0){const m=this.darkenColor(p.color,.2);d.save(),d.beginPath(),this.roundedRectPath(r,c,f,y,u),d.clip(),d.fillStyle=m,d.fillRect(r,c,p.progressWidth,y),d.restore()}t.selectedIds.has(p.taskId)&&this.strokeRoundedRect(r,c,f,y,u,o.barSelectedBorder,Xn),this.renderBarLabel(p,r,c,f,y,o)}}}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,g=(s-Oo*2)/2,d=n+s/2;l.save(),l.beginPath(),l.moveTo(t,d-g),l.lineTo(t+g,d),l.lineTo(t,d+g),l.lineTo(t-g,d),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=Xn,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const g=`${a.fontSize}px ${a.fontFamily}`;l.font=g,l.textBaseline="middle";const d=l.measureText(t.label).width,u=s+i/2;d+Wn*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+Wn,u)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+No,u)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=$o,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,g=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const d=g.length||2,u=l/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<g.length;c++){const f=g[c],y=c*u;for(const m of f){const h=m.x-o,b=m.width;if(h+b<0||h>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=Yn;const S=this.snapToPixelRaw(h+b);i.moveTo(S,y),i.lineTo(S,y+u),i.stroke(),i.save(),i.beginPath(),i.rect(h,y,b,u),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(m.label,h+b/2,y+u/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=Yn,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:g}=this;g.beginPath(),this.roundedRectPath(t,n,s,o,i),g.strokeStyle=a,g.lineWidth=l,g.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=g=>g.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const Gn="ng-tree-grid-styles";function Bo(e,t){const n=e.querySelector(`#${Gn}`);n&&n.remove();const s=document.createElement("style");s.id=Gn,s.textContent=`
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
  `,e.prepend(s)}function xo(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function wt(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class Fo{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;Bo(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=xo(n),g=l.map(d=>d.task.id);this.updateRows(l,g,t),this.currentVisibleIds=g}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],g=l.querySelector(".ng-th-text");g&&g.textContent!==t[a].header&&(g.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const g=document.createElement("th");g.className="ng-grid-th",g.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,g.appendChild(d);const u=document.createElement("span");u.className="ng-resize-handle",g.appendChild(u),this.attachResizeListener(u,l),i.appendChild(g)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=d=>{const u=d.clientX-o,p=Math.max(a,i+u);this.columnWidths[n]=p;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),c[n]&&(c[n].style.width=`${p}px`)},g=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",g),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",g)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const d of t)l.set(d.task.id,d);for(const[d,u]of this.rows)a.has(d)||(u.remove(),this.rows.delete(d));let g=null;for(let d=0;d<t.length;d++){const u=t[d],p=u.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,u,d,s):(r=this.createRow(u,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,g?g.nextSibling!==r&&this.tbody.insertBefore(r,g.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),g=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const g of i){const d=this.createCell(t,g,s);l.appendChild(d)}return l}createCell(t,n,s){const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const i=t.depth*20+8;if(o.style.paddingLeft=`${i}px`,t.children.length>0){const l=document.createElement("span");l.className="ng-expand-icon",t.expanded&&l.classList.add("ng-expanded"),l.innerHTML="&#9654;",l.setAttribute("data-expand",t.task.id),o.appendChild(l)}else{const l=document.createElement("span");l.className="ng-expand-spacer",o.appendChild(l)}const a=document.createElement("span");a.className="ng-grid-cell-text",a.textContent=wt(t.task,n),o.appendChild(a)}else o.textContent=wt(t.task,n);return o}updateRowContent(t,n,s,o){const{config:i}=o,{columns:a}=i;s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt"),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let g=0;g<a.length;g++){const d=a[g],u=l[g];if(!u){const p=this.createCell(n,d,o);t.appendChild(p);continue}if(d.tree){const p=n.depth*20+8;u.style.paddingLeft=`${p}px`;const r=u.querySelector(".ng-expand-icon"),c=u.querySelector(".ng-expand-spacer");if(n.children.length>0)if(r)n.expanded?r.classList.add("ng-expanded"):r.classList.remove("ng-expanded");else{c&&c.remove();const y=document.createElement("span");y.className="ng-expand-icon",n.expanded&&y.classList.add("ng-expanded"),y.innerHTML="&#9654;",y.setAttribute("data-expand",n.task.id),u.insertBefore(y,u.firstChild)}else if(r){r.remove();const y=document.createElement("span");y.className="ng-expand-spacer",u.insertBefore(y,u.firstChild)}const f=u.querySelector(".ng-grid-cell-text");if(f){const y=wt(n.task,d);f.textContent!==y&&(f.textContent=y)}}else{const p=wt(n.task,d);u.textContent!==p&&(u.textContent=p)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class Uo{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class zn{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:g}=s;if(t<i||t>i+l||n<a||n>a+g)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const Vn=864e5;function Jt(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/Vn)}function rt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Je(e,t){const n=rt(e),s=new Date(n.getTime()+t*Vn),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function Yo(e,t,n){return Math.max(t,Math.min(n,e))}const Wo=3,Xo=300;class Go{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=t,this.options=n,this.hitTest=new zn,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const g=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-g.left,t.clientY-g.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none")return;t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l&&(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(t.pointerId),this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly)){const g=zo(a.type);g&&this.options.dispatch({type:"DRAG_START",drag:{type:g,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s})}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<Wo?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Xo){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var l,g,d,u,p,r,c,f;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale();n.config;const i=this.dragHit.type,a=t.clientX-this.dragStartX;switch(i){case"bar":{const y=Jt(a,o),m=Je(this.dragOriginalStartDate,y),h=Je(this.dragOriginalEndDate,y);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:m,endDate:h}),(g=(l=this.options).onTaskMove)==null||g.call(l,s,m,h);break}case"bar-left-edge":{const y=Jt(a,o),m=Je(this.dragOriginalStartDate,y),h=rt(this.dragOriginalEndDate),S=rt(m).getTime()>=h.getTime()?Je(this.dragOriginalEndDate,-1):m;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:S,endDate:this.dragOriginalEndDate}),(u=(d=this.options).onTaskResize)==null||u.call(d,s,S,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=Jt(a,o),m=Je(this.dragOriginalEndDate,y),h=rt(this.dragOriginalStartDate),S=rt(m).getTime()<=h.getTime()?Je(this.dragOriginalStartDate,1):m;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:S}),(r=(p=this.options).onTaskResize)==null||r.call(p,s,this.dragOriginalStartDate,S);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:m}=this.toCanvasCoords(t),h=m-y.x,b=Yo(h/y.width,0,1),S=Math.round(b*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:S}}),(f=(c=this.options).onTaskProgressChange)==null||f.call(c,s,S);break}}this.options.dispatch({type:"DRAG_END"})}}function zo(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const Qe=12,Et=6,Dt=4,Vo=3;class Kn{render(t,n,s,o,i,a,l){const{dependencies:g}=n;if(g.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const u=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,u,p-l),t.clip(),t.translate(-i,0);for(const r of g.values()){const c=d.get(r.source),f=d.get(r.target);if(!c||!f)continue;const y=r.type||"FS",{sourceX:m,sourceY:h,targetX:b,targetY:S}=this.getConnectionPoints(y,c,f,a,l);this.drawRoutedPath(t,y,m,h,b,S,o),this.drawArrowhead(t,y,b,S,o),this.drawConnectionDot(t,m,h,o),this.drawConnectionDot(t,b,S,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const g=n==="FS"||n==="FF",d=n==="FS"||n==="SS",u=g?s+Qe:s-Qe,p=d?i-Qe:i+Qe;if(g?d?p>=u:i+Qe>=u:d?i-Qe<=u:p<=u)t.lineTo(u,o),t.lineTo(u,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(u,o),t.lineTo(u,c),t.lineTo(p,c),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-Et,o-Dt),t.lineTo(s-Et,o+Dt)):(t.moveTo(s,o),t.lineTo(s+Et,o-Dt),t.lineTo(s+Et,o+Dt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Vo,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Ct=12,Ko=100,jo=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],qo=`
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
`;function et(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function jn(e){const t=e.split("-");if(t.length!==3)return et(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?et(e):`${jo[n]} ${s}`}function lt(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${et(e)}</span><span class="ng-tooltip-value">${et(t)}</span></div>`}function Zo(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=lt("Status",e.status||"None"),i+=lt("Assignee",e.assignee||"Unassigned"),i+=lt("Dates",`${jn(e.startDate)} → ${jn(e.endDate)}`),n>0&&(i+=lt("Progress",`${n}%`)),s!=null&&(i+=lt("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${et(t)}"><span class="ng-tooltip-name">${et(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class qn{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=qo,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const d=this.customRenderer(t);typeof d=="string"?this.tooltipEl.innerHTML=d:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(d))}else this.tooltipEl.innerHTML=Zo(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+Ct,g=s+Ct;l+i.width>a.width&&(l=n-Ct-i.width),g+i.height>a.height&&(g=s-Ct-i.height),l=Math.max(0,l),g=Math.max(0,g),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${g}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Ko))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const Qt={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},Zn={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Jo=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function Jn(e){const t=Qo(e.theme);return{columns:e.columns??Jo,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function Qo(e){return!e||e==="light"?{...Qt}:e==="dark"?{...Zn}:{...Qt,...e}}const Qn="nimbus-gantt-root-styles";function ei(){if(typeof document>"u"||document.getElementById(Qn))return;const e=document.createElement("style");e.id=Qn,e.textContent=`
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
  `,document.head.appendChild(e)}class ti{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.renderScheduled=!1,this.destroyed=!1,this.container=t,this.config=Jn(n),ei(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const u of n.tasks)s.set(u.id,u);const o=new Map;if(n.dependencies)for(const u of n.dependencies)o.set(u.id,u);const i=new Set,{tree:a,flatIds:l}=$e(s,i),g=at(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:g,dragState:null,config:this.config};if(this.eventBus=new On,this.store=new _n(d),this.layoutEngine=new Fn,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new Ho(this.timelinePanel),this.treeGrid=new Fo(this.gridPanel),this.scrollManager=new Uo(this.timelinePanel,(u,p)=>{this.store.dispatch({type:"SET_SCROLL",x:u,y:p})}),this.dependencyRenderer=new Kn,this.tooltipManager=new qn(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const u=this.timelinePanel.querySelector("canvas");u&&(this.dragManager=new Go(u,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,c,f)=>{p?this.tooltipManager.show(p,r,c,f):this.tooltipManager.hide()},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight}))}this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((u,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:u,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(u))}),this.treeGrid.onRowDblClick(u=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(u))}),this.treeGrid.onExpandToggle(u=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:u})}),this.wireCallbacks(n),this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container),this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const g=n.tasks.get(t);g&&this.scrollToDate(g.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const g=l.getContext("2d");g&&this.dependencyRenderer.render(g,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const g=this.timelinePanel.querySelector("canvas");if(g){const d=g.getContext("2d");d&&l.renderCanvas(d,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){this.destroyed=!0,this.resizeObserver.disconnect(),this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new Bn(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()})}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new _n(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}const ni=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function en(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function si(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,g=null;function d(c){s.push(c),s.length>t&&s.shift()}function u(){if(!n||s.length===0)return;const c=en(n.getState()),f=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const c=en(n.getState()),f=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),p()):(c.preventDefault(),u()))}return{name:"UndoRedoPlugin",install(c){n=c,g=c.on("render",()=>{if(l)return;const f=document.querySelector(".nimbus-gantt");f&&(l=f.parentElement??f,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,f){if(i){f(c);return}if(ni.has(c.type)&&n){const y=en(n.getState());d(y),o=[]}f(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),g&&g(),n=null,l=null,a=null,s=[],o=[]}}}const ct=["day","week","month","quarter"];function oi(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function tn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function ii(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,g=oi(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!g)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(g);d>0&&e.dispatch({type:"SELECT_TASK",taskId:l[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!g)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(g);d<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[d+1]})}break}case"ArrowRight":{if(g)if(tn(g,a))if(!a.expandedIds.has(g))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:g});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(g)if(tn(g,a))if(a.expandedIds.has(g))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:g});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!g)return;i.preventDefault();const d=a.tasks.get(g);if(d&&n){const u=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(u)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!g)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const u=a.tasks.get(g);if(u&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:u,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const d=l[l.length-1],u=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,u-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=ct.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:ct[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=ct.indexOf(a.zoomLevel);d<ct.length-1&&e.dispatch({type:"SET_ZOOM",level:ct[d+1]});break}case" ":{if(!g)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;tn(g,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:g}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const es="#D4A017",ai="rgba(212, 160, 23, 0.25)",ri=[6,4],li=1,ci=2,di=4,ts=8,ns=10,ss=16,gi=6;function ui(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,g=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const u=g,p=t.canvas.height/(window.devicePixelRatio||1)-u;t.beginPath(),t.rect(0,u,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const c=r.x,f=r.barY-a,y=r.barHeight,m=f+y/2,h=r.color===l.barDefaultColor?es:r.color||es;t.save(),t.beginPath(),t.strokeStyle=ai,t.lineWidth=li,t.setLineDash(ri),t.moveTo(c,u),t.lineTo(c,u+p),t.stroke(),t.setLineDash([]),t.restore();const b=(y-ci*2)/2;t.save(),t.beginPath(),t.moveTo(c,m-b),t.lineTo(c+b,m),t.lineTo(c,m+b),t.lineTo(c-b,m),t.closePath(),t.fillStyle=h,t.fill(),t.strokeStyle=os(h,.25),t.lineWidth=1,t.stroke(),t.restore();const S=c+b+di,T=m-ss/2;if(t.save(),t.beginPath(),t.strokeStyle=os(h,.15),t.lineWidth=1.5,t.moveTo(S,T),t.lineTo(S,T+ss),t.stroke(),t.beginPath(),t.moveTo(S,T),t.lineTo(S+ts,T+ns/2),t.lineTo(S,T+ns),t.closePath(),t.fillStyle=h,t.fill(),t.restore(),r.label){const E=S+ts+gi,C=m;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,E,C),t.restore()}}t.restore()},destroy(){e=null}}}function os(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const hi="rgba(100, 116, 139, 0.12)",fi="rgba(100, 116, 139, 0.25)",is="#334155",pi="rgba(100, 116, 139, 0.2)",mi="#475569",Ti=8,yi=6,bi=2,_e=5,Si=12,vi=28,wi=8;function Ei(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function g(u){const p=new Map,r=[];for(const c of u.flatVisibleIds){const f=u.tasks.get(c);if(f)if(f.groupId){let y=p.get(f.groupId);y||(y={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,y)),y.taskIds.push(c)}else r.push(c)}n=Array.from(p.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const f=o.length,y=`__group_header__${c.groupId}`;if(o.push(y),s.set(f,c),!c.collapsed)for(const m of c.taskIds)o.push(m)}}function d(u){if(t.has(u)?t.delete(u):t.add(u),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(u){e=u,l=u.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const c=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const y=f.getBoundingClientRect(),m=r.clientY-y.top,h=c.config.headerHeight;if(m<h)return;const b=m-h+c.scrollY,S=Math.floor(b/c.config.rowHeight),T=s.get(S);T&&(r.preventDefault(),r.stopPropagation(),d(T.groupId))},a.addEventListener("click",i))})},middleware(u,p){if(p(u),!e)return;const r=e.getState();let c=!1;for(const f of r.tasks.values())if(f.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(g(r),t.size>0){const f=new Set;for(const y of n)if(y.collapsed)for(const m of y.taskIds)f.add(m);if(f.size>0){const y=r.flatVisibleIds.filter(m=>!f.has(m));if(y.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const m of y)r.flatVisibleIds.push(m)}}}},renderCanvas(u,p,r){if(!e||n.length===0)return;const{config:c,scrollX:f,scrollY:y}=p,{theme:m}=c,h=c.headerHeight,b=c.rowHeight,S=u.canvas.width/(window.devicePixelRatio||1),T=u.canvas.height/(window.devicePixelRatio||1)-h;u.save(),u.beginPath(),u.rect(0,h,S,T),u.clip();let E=0;const C=[];for(const v of p.flatVisibleIds){const D=p.tasks.get(v);D&&!D.groupId&&C.push(v)}E=C.length;for(const v of n){const D=h+E*b-y;if(D+b>=h&&D<h+T){u.fillStyle=hi,u.fillRect(0,D,S,b),u.beginPath(),u.strokeStyle=fi,u.lineWidth=1,u.moveTo(0,Math.round(D+b)+.5),u.lineTo(S,Math.round(D+b)+.5),u.stroke();const w=Si,k=D+b/2;u.save(),u.beginPath(),u.fillStyle=is,v.collapsed?(u.moveTo(w,k-_e),u.lineTo(w+_e,k),u.lineTo(w,k+_e)):(u.moveTo(w-_e/2,k-_e/2),u.lineTo(w+_e/2,k-_e/2),u.lineTo(w,k+_e/2)),u.closePath(),u.fill(),u.restore(),u.save(),u.font=`600 ${m.fontSize}px ${m.fontFamily}`,u.textBaseline="middle",u.textAlign="left",u.fillStyle=is;const M=vi,I=D+b/2;u.fillText(v.groupName,M,I);const A=u.measureText(v.groupName).width;u.restore();const $=`${v.taskIds.length}`;u.save(),u.font=`${m.fontSize-1}px ${m.fontFamily}`;const R=u.measureText($).width+yi*2,N=m.fontSize+bi*2,B=M+A+wi,F=I-N/2;u.beginPath();const G=Ti;u.moveTo(B+G,F),u.lineTo(B+R-G,F),u.arcTo(B+R,F,B+R,F+G,G),u.lineTo(B+R,F+N-G),u.arcTo(B+R,F+N,B+R-G,F+N,G),u.lineTo(B+G,F+N),u.arcTo(B,F+N,B,F+N-G,G),u.lineTo(B,F+G),u.arcTo(B,F,B+G,F,G),u.closePath(),u.fillStyle=pi,u.fill(),u.fillStyle=mi,u.textBaseline="middle",u.textAlign="center",u.fillText($,B+R/2,I),u.restore()}E+=1,v.collapsed||(E+=v.taskIds.length)}u.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const as=864e5,Di=6,Ci=2,ki=2,Mi=.18,Ii=.4;function rs(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function nn(e,t){return Math.round((t.getTime()-e.getTime())/as)}function tt(e,t){return new Date(e.getTime()+t*as)}function sn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const w of n)s.set(w,[]),o.set(w,[]),i.set(w,0);for(const w of t.values()){if((w.type||"FS")!=="FS"||!e.has(w.source)||!e.has(w.target))continue;const M=w.lag||0;s.get(w.source).push({target:w.target,lag:M,depId:w.id}),o.get(w.target).push({source:w.source,lag:M,depId:w.id}),i.set(w.target,(i.get(w.target)||0)+1)}const a=new Map,l=new Map,g=new Map;for(const[w,k]of e){const M=rs(k.startDate),I=rs(k.endDate);l.set(w,M),g.set(w,I),a.set(w,Math.max(nn(M,I),0))}const d=new Map,u=new Map,p=[],r=[],c=new Map(i);for(const w of n)c.get(w)===0&&(r.push(w),d.set(w,l.get(w)),u.set(w,g.get(w)));for(;r.length>0;){const w=r.shift();p.push(w),d.get(w);const k=u.get(w);for(const M of s.get(w)){const{target:I,lag:A}=M,$=tt(k,A),P=d.get(I);(!P||$.getTime()>P.getTime())&&(d.set(I,$),u.set(I,tt($,a.get(I))));const R=c.get(I)-1;c.set(I,R),R===0&&r.push(I)}}for(const w of n)d.has(w)||(d.set(w,l.get(w)),u.set(w,g.get(w)),p.push(w));let f=-1/0;for(const w of u.values())w.getTime()>f&&(f=w.getTime());const y=new Date(f);let m=1/0;for(const w of d.values())w.getTime()<m&&(m=w.getTime());const h=new Date(m),b=nn(h,y),S=new Map,T=new Map;for(const w of n)s.get(w).length===0&&(T.set(w,y),S.set(w,tt(y,-a.get(w))));for(let w=p.length-1;w>=0;w--){const k=p[w];if(!T.has(k)){let M=1/0;for(const I of s.get(k)){const A=S.get(I.target);if(A){const $=tt(A,-I.lag);$.getTime()<M&&(M=$.getTime())}}M===1/0?T.set(k,y):T.set(k,new Date(M)),S.set(k,tt(T.get(k),-a.get(k)))}}for(const w of n)T.has(w)||(T.set(w,y),S.set(w,tt(y,-a.get(w))));const E=.5,C=new Set,v=new Map;for(const w of n){const k=d.get(w),M=u.get(w),I=S.get(w),A=T.get(w),$=nn(k,I),P=Math.abs($)<E;P&&C.add(w),v.set(w,{earlyStart:k,earlyFinish:M,lateStart:I,lateFinish:A,totalFloat:$,isCritical:P})}const D=new Set;for(const w of t.values())(w.type||"FS")==="FS"&&C.has(w.source)&&C.has(w.target)&&D.add(w.id);return{criticalTaskIds:C,criticalDependencyIds:D,taskAnalysis:v,projectDuration:b}}function Ai(){let e,t=null,n=[];function s(){const o=e.getState();t=sn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:g,rowHeight:d,barHeight:u}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,f=g,y=e.getTimeScale(),m=new Map;for(const T of a)m.set(T.taskId,T);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const T of a){const E=t.taskAnalysis.get(T.taskId);if(!E||E.isCritical||E.totalFloat<=0)continue;const C=T.barY-c,v=u*Ii,D=T.x+T.width,k=y.dateToX(E.lateFinish)-D;k>1&&(o.fillStyle=T.color,o.globalAlpha=Mi,o.fillRect(D,C+u-v,k,v),o.globalAlpha=1)}for(const T of a){if(!t.criticalTaskIds.has(T.taskId))continue;const E=T.x,C=T.barY-c,v=T.width,D=T.barHeight;if(!(C+D<f||C>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Di;for(let w=0;w<Ci;w++){o.strokeStyle=p,o.lineWidth=ki,o.beginPath();const k=l.barBorderRadius,M=Math.min(k,v/2,D/2);o.moveTo(E+M,C),o.lineTo(E+v-M,C),o.arcTo(E+v,C,E+v,C+M,M),o.lineTo(E+v,C+D-M),o.arcTo(E+v,C+D,E+v-M,C+D,M),o.lineTo(E+M,C+D),o.arcTo(E,C+D,E,C+D-M,M),o.lineTo(E,C+M),o.arcTo(E,C,E+M,C,M),o.closePath(),o.stroke()}o.restore()}}const h=6,b=4,S=12;for(const T of i.dependencies.values()){if(!t.criticalDependencyIds.has(T.id))continue;const E=m.get(T.source),C=m.get(T.target);if(!E||!C)continue;const v=E.x+E.width,D=E.barY+E.barHeight/2-c,w=C.x,k=C.barY+C.barHeight/2-c;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=v+S,I=w-S;if(o.moveTo(v,D),I>=M)o.lineTo(M,D),o.lineTo(M,k),o.lineTo(w,k);else{const A=(D+k)/2;o.lineTo(M,D),o.lineTo(M,A),o.lineTo(I,A),o.lineTo(I,k),o.lineTo(w,k)}o.stroke(),o.beginPath(),o.moveTo(w,k),o.lineTo(w-h,k-b),o.lineTo(w-h,k+b),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Ri=864e5,Li=.6,ls=.25,Pi="#38A169",$i="#E53E3E",_i="#A0AEC0",Oi=10,Ni=4,Oe=16,Hi=3;function kt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Bi(e,t){return Math.round((t.getTime()-e.getTime())/Ri)}function xi(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:kt(s.startDate),end:kt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var y,m;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:g}=o.config,d=o.scrollX,u=o.scrollY,p=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const f=g*Li;for(const h of i){if(h.isMilestone)continue;const b=t.get(h.taskId);if(!b)continue;const S=h.barY-u;if(S+g+f<p||S>s.canvas.height)continue;const T=r.dateToX(b.start),E=r.dateToX(b.end),C=Math.max(E-T,2),v=S+g+1;kt(((y=o.tasks.get(h.taskId))==null?void 0:y.startDate)||"");const D=kt(((m=o.tasks.get(h.taskId))==null?void 0:m.endDate)||""),w=Bi(b.end,D);let k;w<0?k=Pi:w>0?k=$i:k=_i,s.save(),s.globalAlpha=ls,s.fillStyle=k;const M=Math.min(c,C/2,f/2);if(s.beginPath(),s.moveTo(T+M,v),s.lineTo(T+C-M,v),s.arcTo(T+C,v,T+C,v+M,M),s.lineTo(T+C,v+f-M),s.arcTo(T+C,v+f,T+C-M,v+f,M),s.lineTo(T+M,v+f),s.arcTo(T,v+f,T,v+f-M,M),s.lineTo(T,v+M),s.arcTo(T,v,T+M,v,M),s.closePath(),s.fill(),s.globalAlpha=ls*2,s.strokeStyle=k,s.lineWidth=1,s.stroke(),s.restore(),w!==0){const I=w>0?`+${w}d`:`${w}d`;s.save(),s.font=`600 ${Oi}px ${a.fontFamily}`;const P=s.measureText(I).width+Ni*2,R=h.x+h.width+4,N=v+(f-Oe)/2;s.globalAlpha=.85,s.fillStyle=k;const B=Hi;s.beginPath(),s.moveTo(R+B,N),s.lineTo(R+P-B,N),s.arcTo(R+P,N,R+P,N+B,B),s.lineTo(R+P,N+Oe-B),s.arcTo(R+P,N+Oe,R+P-B,N+Oe,B),s.lineTo(R+B,N+Oe),s.arcTo(R,N+Oe,R,N+Oe-B,B),s.lineTo(R,N+B),s.arcTo(R,N,R+B,N,B),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(I,R+P/2,N+Oe/2),s.restore()}}s.restore()},destroy(){}}}const cs=5,Fi=5,Ui=.3,Yi=15;function Wi(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:u,headerHeight:p}=d.config,r=d.scrollY,c=d.flatVisibleIds.length,f=a(d),y=Math.floor(r/u),m=Math.ceil((r+f)/u);let h=Math.max(0,y-cs),b=Math.min(c,m+cs);if(Math.abs(s)>0){const T=Math.min(Yi,Math.ceil(Math.abs(s*Ui)/u));s>0?b=Math.min(c,b+T):h=Math.max(0,h-T)}const S=new Set;for(let T=h;T<b&&T<d.flatVisibleIds.length;T++)S.add(d.flatVisibleIds[T]);return{startRow:h,endRow:b,totalRows:c,visibleTaskIds:S}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function l(d){const u=performance.now();for(o.push({y:d,time:u});o.length>Fi;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],c=(r.time-p.time)/1e3;c>0&&(s=(r.y-p.y)/c)}n=d}const g={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(l(d.scrollY),t=i(d)),t},filterLayouts(d){const u=g.getVisibleRange();return u.totalRows===0?[]:d.filter(p=>u.visibleTaskIds.has(p.taskId))},isVisible(d){return g.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,u){if(u(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:g}}const ke=864e5,on=1,ds=2,gs=.5,us=2,Mt=8,hs=6,fs=2,It=1e4;function an(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function ps(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Ge(e){return Math.round(e)+.5}function ms(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Ts(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,g=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,g),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,g),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const c=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,c,g/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,g),e.lineTo(n,g),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const u=t.flatVisibleIds;for(let p=0;p<u.length;p++){const r=t.tasks.get(u[p]);if(!r)continue;const c=g+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const y of a){const m=y.width??120,h=ms(r,y.field);e.save(),e.beginPath(),e.rect(f,c,m,l),e.clip(),e.textBaseline="middle";const b=y.tree?8:0;e.textAlign=y.align==="right"?"right":y.align==="center"?"center":"left";const S=y.align==="right"?f+m-8:y.align==="center"?f+m/2:f+8+b;e.fillText(h,S,c+l/2),e.restore(),f+=m}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function ys(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,g=i.rowHeight,d=s.getTotalWidth(),u=t.flatVisibleIds.length*g,p=l+u;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:f,end:y}=t.dateRange,m=new Date(f);m.setUTCHours(0,0,0,0);const h=y.getTime();for(;m.getTime()<=h;){const b=m.getUTCDay();if(b===0||b===6){const S=o+s.dateToX(m),T=new Date(m.getTime()+ke),E=o+s.dateToX(T);e.fillStyle=a.timelineWeekendBg,e.fillRect(S,l,E-S,u)}m.setTime(m.getTime()+ke)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=gs;for(const f of r){const y=Ge(o+f);e.moveTo(y,l),e.lineTo(y,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+f*g,d,g));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:y,end:m}=t.dateRange;if(f.getTime()>=y.getTime()&&f.getTime()<=m.getTime()){const h=o+s.dateToX(f),b=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(h,l,b,u),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=ds,e.moveTo(Ge(h),l),e.lineTo(Ge(h),p),e.stroke()}}const c=a.barBorderRadius;for(const f of n){const y=o+f.x,m=f.barY,h=f.width,b=f.barHeight;if(f.isMilestone){const S=(b-us*2)/2,T=m+b/2;e.beginPath(),e.moveTo(y,T-S),e.lineTo(y+S,T),e.lineTo(y,T+S),e.lineTo(y-S,T),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(rn(e,y,m,h,b,c),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const S=ps(f.color,.2);e.save(),e.beginPath(),rn(e,y,m,h,b,c),e.clip(),e.fillStyle=S,e.fillRect(y,m,f.progressWidth,b),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),rn(e,y,m,h,b,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=fs,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const S=e.measureText(f.label).width,T=m+b/2;S+Mt*2<=h?(e.beginPath(),e.rect(y,m,h,b),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,y+Mt,T)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,y+h+hs,T)),e.restore()}}Xi(e,t,n,a,o),Gi(e,s,i,a,o)}function Xi(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,l=6,g=4;e.save();for(const d of t.dependencies.values()){const u=i.get(d.source),p=i.get(d.target);if(!u||!p)continue;const r=d.type||"FS",c=u.barY+u.barHeight/2,f=p.barY+p.barHeight/2;let y,m;const h=r==="FS"||r==="FF",b=r==="FS"||r==="SS";switch(r){case"FS":y=o+u.x+u.width,m=o+p.x;break;case"SS":y=o+u.x,m=o+p.x;break;case"FF":y=o+u.x+u.width,m=o+p.x+p.width;break;case"SF":y=o+u.x,m=o+p.x+p.width;break}const S=h?y+a:y-a,T=b?m-a:m+a,E=h?b?T>=S:m+a>=S:b?m-a<=S:T<=S;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(y,c),E)e.lineTo(S,c),e.lineTo(S,f),e.lineTo(m,f);else{const C=(c+f)/2;e.lineTo(S,c),e.lineTo(S,C),e.lineTo(T,C),e.lineTo(T,f),e.lineTo(m,f)}e.stroke(),e.beginPath(),b?(e.moveTo(m,f),e.lineTo(m-l,f-g),e.lineTo(m-l,f+g)):(e.moveTo(m,f),e.lineTo(m+l,f-g),e.lineTo(m+l,f+g)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function Gi(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,g=i/l;e.textBaseline="middle";for(let d=0;d<a.length;d++){const u=a[d],p=d*g;for(const r of u){const c=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=on,e.moveTo(Ge(c+f),p),e.lineTo(Ge(c+f),p+g),e.stroke(),e.save(),e.beginPath(),e.rect(c,p,f,g),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+f/2,p+g/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=on,e.moveTo(o,Ge(i)),e.lineTo(o+t.getTotalWidth(),Ge(i)),e.stroke()}function rn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function dt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function zi(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,g=n.getTotalWidth(),d=s+g,u=e.flatVisibleIds.length*l,p=a+u,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),c.push(`<style>text { font-family: ${dt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const T of o.columns){const E=T.width??120;c.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${dt(T.header)}</text>`),c.push(`<line x1="${f+E}" y1="0" x2="${f+E}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=E}for(let T=0;T<e.flatVisibleIds.length;T++){const E=e.tasks.get(e.flatVisibleIds[T]);if(!E)continue;const C=a+T*l;T%2===1&&c.push(`<rect x="0" y="${C}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let v=0;for(const D of o.columns){const w=D.width??120,k=ms(E,D.field),M=D.tree?8:0;c.push(`<text x="${v+8+M}" y="${C+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${k}]]></text>`),v+=w}c.push(`<line x1="0" y1="${C+l}" x2="${s}" y2="${C+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${g}" height="${p}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${g}" height="${a}" fill="${i.timelineHeaderBg}" />`);const y=n.getHeaderRows(),m=y.length||2,h=a/m;for(let T=0;T<y.length;T++){const E=y[T],C=T*h;for(const v of E){const D=s+v.x+v.width/2,w=C+h/2,k=T===0?' font-weight="600"':"";c.push(`<text x="${D}" y="${w}" text-anchor="middle" dominant-baseline="central"${k} fill="${i.timelineHeaderText}">${dt(v.label)}</text>`),c.push(`<line x1="${s+v.x+v.width}" y1="${C}" x2="${s+v.x+v.width}" y2="${C+h}" stroke="${i.timelineGridColor}" stroke-width="${on}" />`)}}const b=n.getGridLines();for(const T of b)c.push(`<line x1="${s+T}" y1="${a}" x2="${s+T}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${gs}" />`);for(let T=0;T<e.flatVisibleIds.length;T++)T%2===1&&c.push(`<rect x="${s}" y="${a+T*l}" width="${g}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:T,end:E}=e.dateRange,C=new Date(T);for(C.setUTCHours(0,0,0,0);C.getTime()<=E.getTime();){if(C.getUTCDay()===0||C.getUTCDay()===6){const v=s+n.dateToX(C),D=new Date(C.getTime()+ke),w=s+n.dateToX(D);c.push(`<rect x="${v}" y="${a}" width="${w-v}" height="${u}" fill="${i.timelineWeekendBg}" />`)}C.setTime(C.getTime()+ke)}}if(o.showToday){const T=new Date;T.setHours(0,0,0,0);const{start:E,end:C}=e.dateRange;if(T.getTime()>=E.getTime()&&T.getTime()<=C.getTime()){const v=s+n.dateToX(T),D=n.getColumnWidth();c.push(`<rect x="${v}" y="${a}" width="${D}" height="${u}" fill="${i.todayBg}" />`),c.push(`<line x1="${v}" y1="${a}" x2="${v}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${ds}" />`)}}for(const T of t){const E=s+T.x,C=T.barY,v=T.width,D=T.barHeight;if(T.isMilestone){const w=(D-us*2)/2,k=C+D/2;c.push(`<polygon points="${E},${k-w} ${E+w},${k} ${E},${k+w} ${E-w},${k}" fill="${T.color}" />`);continue}if(c.push(`<rect x="${E}" y="${C}" width="${v}" height="${D}" rx="${r}" ry="${r}" fill="${T.color}" />`),o.showProgress&&T.progressWidth>0){const w=ps(T.color,.2);c.push(`<clipPath id="clip-${T.taskId}"><rect x="${E}" y="${C}" width="${v}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${E}" y="${C}" width="${T.progressWidth}" height="${D}" fill="${w}" clip-path="url(#clip-${T.taskId})" />`)}if(e.selectedIds.has(T.taskId)&&c.push(`<rect x="${E}" y="${C}" width="${v}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${fs}" />`),T.label){const w=C+D/2;i.fontSize*.6*T.label.length+Mt*2<=v?c.push(`<text x="${E+Mt}" y="${w}" dominant-baseline="central" fill="${T.textColor}">${dt(T.label)}</text>`):c.push(`<text x="${E+v+hs}" y="${w}" dominant-baseline="central" fill="${i.gridTextColor}">${dt(T.label)}</text>`)}}const S=new Map;for(const T of t)S.set(T.taskId,T);for(const T of e.dependencies.values()){const E=S.get(T.source),C=S.get(T.target);if(!E||!C)continue;const v=T.type||"FS",D=E.barY+E.barHeight/2,w=C.barY+C.barHeight/2;let k,M;const I=v==="FS"||v==="FF",A=v==="FS"||v==="SS";switch(v){case"FS":k=s+E.x+E.width,M=s+C.x;break;case"SS":k=s+E.x,M=s+C.x;break;case"FF":k=s+E.x+E.width,M=s+C.x+C.width;break;case"SF":k=s+E.x,M=s+C.x+C.width;break}const $=12,P=6,R=4,N=I?k+$:k-$,B=A?M-$:M+$,F=I?A?B>=N:M+$>=N:A?M-$<=N:B<=N;let G;if(F)G=`M${k},${D} L${N},${D} L${N},${w} L${M},${w}`;else{const O=(D+w)/2;G=`M${k},${D} L${N},${D} L${N},${O} L${B},${O} L${B},${w} L${M},${w}`}c.push(`<path d="${G}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),A?c.push(`<polygon points="${M},${w} ${M-P},${w-R} ${M-P},${w+R}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${M},${w} ${M+P},${w-R} ${M+P},${w+R}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function Vi(){let e=null;function t(){const a=e,l=a.getState(),g=a.getTimeScale(),{start:d,end:u}=l.dateRange,p=u.getTime()-d.getTime(),r=g.getColumnWidth(),c=l.zoomLevel;let f;switch(c){case"day":f=Math.round(p/ke);break;case"week":f=Math.ceil(p/(ke*7));break;case"month":{const m=d.getUTCFullYear(),h=d.getUTCMonth(),b=u.getUTCFullYear(),S=u.getUTCMonth();f=(b-m)*12+(S-h);break}case"quarter":{const m=d.getUTCFullYear(),h=Math.floor(d.getUTCMonth()/3),b=u.getUTCFullYear(),S=Math.floor(u.getUTCMonth()/3);f=(b-m)*4+(S-h);break}}const y=f*r;return{dateToX(m){return(m.getTime()-d.getTime())/p*y},getColumnWidth(){return r},getTotalWidth(){return y},getHeaderRows(){return qi(c,d,u,r,y)},getGridLines(){return this.getHeaderRows()[1].map(h=>h.x).filter(h=>h>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const g of a.config.columns)l+=g.width??120;return l}function s(a){if(!e)return;const l=e.getState(),g=t(),d=e.getLayouts(),u=n(),p=g.getTotalWidth(),r=u+p,c=l.flatVisibleIds.length*l.config.rowHeight,f=l.config.headerHeight+c,y=a??"gantt-export.png";if(r>It||f>It){o(l,d,g,u,r,f,y);return}const m=document.createElement("canvas");m.width=r,m.height=f;const h=m.getContext("2d");h&&(u>0&&Ts(h,l,u,f),ys(h,l,d,g,u),m.toBlob(b=>{b&&an(b,y)},"image/png"))}function o(a,l,g,d,u,p,r){const c=Math.min(1,It/u,It/p),f=Math.ceil(u*c),y=Math.ceil(p*c),m=document.createElement("canvas");m.width=f,m.height=y;const h=m.getContext("2d");h&&(h.scale(c,c),d>0&&Ts(h,a,d,p),ys(h,a,l,g,d),m.toBlob(b=>{b&&an(b,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),g=t(),d=e.getLayouts(),u=n(),p=zi(l,d,g,u),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});an(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const bs=["January","February","March","April","May","June","July","August","September","October","November","December"],Ss=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function vs(e,t){return new Date(e.getTime()+t*ke)}function ln(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Ki(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function ji(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function qi(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>ji(l,t,i,o);switch(e){case"day":{const l=[],g=[],d=Math.round(i/ke);let u=new Date(t);for(let r=0;r<d;r++)g.push({label:String(u.getUTCDate()),x:r*s,width:s,date:new Date(u)}),u=vs(u,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=ln(p),c=a(p),f=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${bs[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:c,width:f-c,date:new Date(p)}),p=r}return[l,g]}case"week":{const l=[],g=[],d=Math.ceil(i/(ke*7));for(let p=0;p<d;p++){const r=vs(t,p*7);g.push({label:`${Ss[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let u=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;u.getTime()<n.getTime();){const p=ln(u),r=u.getTime()<t.getTime()?t:u,c=p.getTime()>n.getTime()?n:p;l.push({label:`${bs[u.getUTCMonth()]} ${u.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),u=p}return[l,g]}case"month":{const l=[],g=[],d=t.getUTCFullYear(),u=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),c=(p-d)*12+(r-u);let f=new Date(Date.UTC(d,u,1));for(let m=0;m<c;m++)g.push({label:Ss[f.getUTCMonth()],x:m*s,width:s,date:new Date(f)}),f=ln(f);let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const m=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),h=y.getTime()<t.getTime()?t:y,b=m.getTime()>n.getTime()?n:m;l.push({label:String(y.getUTCFullYear()),x:a(h),width:a(b)-a(h),date:new Date(h)}),y=m}return[l,g]}case"quarter":{const l=[],g=[],d=t.getUTCFullYear(),u=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(p-d)*4+(r-u);let f=new Date(Date.UTC(d,u*3,1));for(let m=0;m<c;m++){const h=Math.floor(f.getUTCMonth()/3)+1;g.push({label:`Q${h}`,x:m*s,width:s,date:new Date(f)}),f=Ki(f,3)}let y=new Date(Date.UTC(d,0,1));for(;y.getTime()<n.getTime();){const m=new Date(Date.UTC(y.getUTCFullYear()+1,0,1)),h=y.getTime()<t.getTime()?t:y,b=m.getTime()>n.getTime()?n:m;l.push({label:String(y.getUTCFullYear()),x:a(h),width:a(b)-a(h),date:new Date(h)}),y=m}return[l,g]}default:return[[],[]]}}const Zi={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},cn="nimbus-gantt-dark-theme-transition";function Ji(){if(typeof document>"u"||document.getElementById(cn))return;const e=document.createElement("style");e.id=cn,e.textContent=`
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
  `,document.head.appendChild(e)}function Qi(){if(typeof document>"u")return;const e=document.getElementById(cn);e&&e.remove()}function ea(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function g(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const f={...c.config.theme,...Zi};Object.assign(c.config.theme,f),s=!0,p()}function d(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,p()}function u(){s?d():g()}function p(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?g():d()}return{name:"DarkThemePlugin",install(c){n=c,Ji(),c.on("theme:toggle",()=>{u()}),c.on("theme:dark",()=>{g()}),c.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&g()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}Qi(),n=null,o=null,i=null,a=null,s=!1}}}const me=864e5,ta=[1,2,3,4,5],na="rgba(128, 128, 128, 0.06)",sa="rgba(128, 128, 128, 0.04)",oa="#f87171",gt=4;function ut(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function we(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ia(e){const t=new Set((e==null?void 0:e.workDays)??ta),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=we(r);return t.has(c.getUTCDay())}function i(r){const c=ut(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=we(r);for(c=new Date(c.getTime()+me);!i(c);)c=new Date(c.getTime()+me);return ut(c)}function l(r,c){if(c===0)return r;let f=we(r);const y=c>0?1:-1;let m=Math.abs(c);if(!i(f))for(f=new Date(f.getTime()+y*me);!i(f);)f=new Date(f.getTime()+y*me);for(;m>0;)f=new Date(f.getTime()+y*me),i(f)&&m--;return ut(f)}function g(r,c){const f=we(r),y=we(c);if(f.getTime()>y.getTime())return-g(c,r);let m=0,h=new Date(f.getTime());for(;h.getTime()<y.getTime();)i(h)&&m++,h=new Date(h.getTime()+me);return m}function d(r,c="forward"){if(o(r))return r;let f=we(r);const y=c==="forward"?me:-me;for(let m=0;m<30;m++)if(f=new Date(f.getTime()+y),i(f))return ut(f);return r}function u(r,c){if(r.type==="TASK_MOVE"){const f=d(r.startDate,"forward"),y=d(r.endDate,"backward"),m=we(y).getTime()<we(f).getTime()?f:y;c({...r,startDate:f,endDate:m});return}if(r.type==="TASK_RESIZE"){const f=d(r.startDate,"forward"),y=d(r.endDate,"backward"),m=we(y).getTime()<we(f).getTime()?f:y;c({...r,startDate:f,endDate:m});return}c(r)}function p(r,c,f){const{config:y}=c,m=y.headerHeight,h=c.flatVisibleIds.length*y.rowHeight,b=s==null?void 0:s.getTimeScale();if(!b||h===0)return;const{start:S,end:T}=c.dateRange,E=c.scrollX,C=c.scrollY;r.save();const v=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(v,0,0,v,0,0),r.beginPath(),r.rect(0,m,r.canvas.width/v,h),r.clip(),r.translate(-E,0);const D=new Date(S);D.setUTCHours(0,0,0,0);const w=T.getTime();for(b.getColumnWidth();D.getTime()<=w;){const k=ut(D),M=n.has(k),I=!t.has(D.getUTCDay());if(M||I){const A=b.dateToX(D),$=new Date(D.getTime()+me),R=b.dateToX($)-A;if(r.fillStyle=na,r.fillRect(A,m-C,R,h+C),I&&!M){r.save(),r.beginPath(),r.rect(A,m,R,h),r.clip(),r.strokeStyle=sa,r.lineWidth=1;const N=8,B=h;for(let F=-B;F<R+B;F+=N)r.beginPath(),r.moveTo(A+F,m),r.lineTo(A+F+B,m+B),r.stroke();r.restore()}}if(M){const A=b.dateToX(D),$=new Date(D.getTime()+me),P=b.dateToX($),R=(A+P)/2;r.save(),r.setTransform(v,0,0,v,0,0),r.translate(-E,0);const N=m-gt-3;r.beginPath(),r.moveTo(R,N-gt),r.lineTo(R+gt,N),r.lineTo(R,N+gt),r.lineTo(R-gt,N),r.closePath(),r.fillStyle=oa,r.fill(),r.restore()}D.setTime(D.getTime()+me)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const f=c[0],y=c[1],m=c[2],h=l(f,y);m&&m(h)}),r.on("calendar:workDaysBetween",(...c)=>{const f=c[0],y=c[1],m=c[2],h=g(f,y);m&&m(h)}),r.on("calendar:isWorkDay",(...c)=>{const f=c[0],y=c[1],m=o(f);y&&y(m)}),r.on("calendar:nextWorkDay",(...c)=>{const f=c[0],y=c[1],m=a(f);y&&y(m)})},middleware:u,renderCanvas:p,destroy(){s=null}}}function aa(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function ra(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function la(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=aa(),a=[],l=Date.now();let g=null,d=null,u=!1,p=[];const r=[];function c(T,E){if(u)return;const C={type:T,timestamp:Date.now(),sessionId:i,userId:n,data:E};a.push(C),o&&o(C)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const T=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(T),keepalive:!0}).catch(()=>{})}catch{}}function y(){d===null&&(d=setInterval(()=>{f()},s))}function m(){d!==null&&(clearInterval(d),d=null)}const h=ra(()=>{if(!g)return;const T=g.getState();c("gantt.scroll",{scrollX:T.scrollX,scrollY:T.scrollY}),T.scrollX,T.scrollY},1e3);let b=0;function S(T,E){switch(T.type){case"SET_ZOOM":{const C=g?g.getState().zoomLevel:"unknown";E(T),c("gantt.zoom",{oldLevel:C,newLevel:T.level});return}case"TASK_MOVE":{const C=b>0?Date.now()-b:0;E(T),c("gantt.task.move",{taskId:T.taskId,startDate:T.startDate,endDate:T.endDate,dragDurationMs:C}),b=0;return}case"TASK_RESIZE":{E(T),c("gantt.task.resize",{taskId:T.taskId,startDate:T.startDate,endDate:T.endDate});return}case"DRAG_START":{b=Date.now(),E(T);return}case"SELECT_TASK":{E(T),c("gantt.task.click",{taskId:T.taskId,multi:T.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{E(T),h();return}case"TOGGLE_EXPAND":{const C=g?g.getState().expandedIds.has(T.taskId):!1;E(T),c(C?"gantt.collapse":"gantt.expand",{taskId:T.taskId});return}case"EXPAND_ALL":{E(T),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{E(T),c("gantt.collapse",{all:!0});return}default:E(T);return}}return{name:"TelemetryPlugin",install(T){g=T,y();const E=T.getState();c("gantt.init",{taskCount:E.tasks.size,dependencyCount:E.dependencies.size,zoomLevel:E.zoomLevel}),setTimeout(()=>{u||c("gantt.feature.used",{plugins:p})},0);const C=T.on("taskClick",(...v)=>{const D=v[0];D&&c("gantt.task.click",{taskId:D.id})});r.push(C)},middleware:S,destroy(){u=!0;const T=Date.now()-l;c("gantt.session.duration",{durationMs:T,durationMinutes:Math.round(T/6e4*10)/10}),f(),m();for(const E of r)E();r.length=0,g=null}}}const ws=5,dn=.15,gn=.85,ca=2,Es=30,Me=["day","week","month","quarter"];function Ds(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function da(e,t,n){return Math.max(t,Math.min(n,e))}function ga(e){const t=da((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,g=!1,d=0,u=0,p=0,r=null,c=null,f=null,y=null,m=null,h=null,b=0,S=0,T=0,E=!1;function C(P,R,N){T=P,b=R,S=N,E=!0,r===null&&(r=P)}function v(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(y=P=>{g||P.alpha==null||P.beta==null||P.gamma==null||C(P.alpha,P.beta,P.gamma)},window.addEventListener("deviceorientation",y),!0)}function D(){y&&(window.removeEventListener("deviceorientation",y),y=null)}function w(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function k(P){try{const R=JSON.parse(P);R.type==="orientation"?C(R.alpha,R.beta,R.gamma):R.type==="gesture"&&M(R.gesture)}catch{}}function M(P){if(!l)return;const R=l.getState();switch(P){case"tap":{R.selectedIds.size===0&&R.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:R.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const N=Me.indexOf(R.zoomLevel);N<Me.length-1&&l.dispatch({type:"SET_ZOOM",level:Me[N+1]});break}case"swipe-right":{const N=Me.indexOf(R.zoomLevel);N>0&&l.dispatch({type:"SET_ZOOM",level:Me[N-1]});break}}}function I(){if(g||typeof WebSocket>"u")return;const P=w();try{m=new WebSocket(P),m.onmessage=R=>{typeof R.data=="string"&&k(R.data)},m.onclose=()=>{m=null,g||(h=setTimeout(I,3e3))},m.onerror=()=>{m&&m.close()}}catch{g||(h=setTimeout(I,3e3))}}function A(){h!==null&&(clearTimeout(h),h=null),m&&(m.onmessage=null,m.onclose=null,m.onerror=null,m.close(),m=null)}function $(){if(!(g||!l)){if(E){d=d*gn+b*dn,u=u*gn+S*dn,p=p*gn+T*dn;const P=l.getState(),R=ca*a;if(n){const N=Ds(u,ws);if(N!==0){const B=N*R,F=Math.max(0,P.scrollX+B);l.dispatch({type:"SET_SCROLL_X",x:F})}}if(s){const N=Ds(d,ws);if(N!==0){const B=N*R,F=Math.max(0,P.scrollY+B);l.dispatch({type:"SET_SCROLL_Y",y:F})}}if(o&&r!==null){const B=(p-r+540)%360-180,F=Me.indexOf(P.zoomLevel);if(B>Es&&F>0){const G=Me[F-1];c!==G&&(l.dispatch({type:"SET_ZOOM",level:G}),c=G,r=T)}else if(B<-Es&&F<Me.length-1){const G=Me[F+1];c!==G&&(l.dispatch({type:"SET_ZOOM",level:G}),c=G,r=T)}}}f=requestAnimationFrame($)}}return{name:"MotionControlPlugin",install(P){l=P,c=P.getState().zoomLevel,(!v()||i)&&I(),f=requestAnimationFrame($)},destroy(){g=!0,f!==null&&(cancelAnimationFrame(f),f=null),D(),A(),l=null}}}const ht="http://schemas.microsoft.com/project",ua=8,Cs=4800,ha={0:"FF",1:"FS",2:"SF",3:"SS"},fa={FF:0,FS:1,SF:2,SS:3};function ks(e){return e?e.substring(0,10):""}function Ms(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function de(e,t){var s;let n=e.getElementsByTagNameNS(ht,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function pa(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function ma(e){return`PT${e*ua}H0M0S`}function ft(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function un(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(ht,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let h=0;h<l.length;h++){const b=l[h],S=de(b,"UID"),T=de(b,"Name");S&&T&&i.set(S,T)}const g=new Map,d=o.getElementsByTagNameNS(ht,"Assignment"),u=d.length>0?d:o.getElementsByTagName("Assignment");for(let h=0;h<u.length;h++){const b=u[h],S=de(b,"TaskUID"),T=de(b,"ResourceUID");if(S&&T){const E=i.get(T);E&&g.set(S,E)}}const p=[],r=[],c=o.getElementsByTagNameNS(ht,"Task"),f=c.length>0?c:o.getElementsByTagName("Task"),y=[];let m=1;for(let h=0;h<f.length;h++){const b=f[h],S=de(b,"UID"),T=de(b,"Name"),E=de(b,"Start"),C=de(b,"Finish"),v=de(b,"PercentComplete"),D=de(b,"Summary")==="1",w=de(b,"Milestone")==="1",k=parseInt(de(b,"OutlineLevel")||"0",10);if(S==="0"&&!T)continue;const M=`msp-${S}`,I=ks(E),A=ks(C);if(!I&&!w)continue;let $;k>0&&y[k-1]&&($=y[k-1]),y[k]=M,y.length=k+1;const P={id:M,name:T||`Task ${S}`,startDate:I||A,endDate:A||I,progress:v?parseInt(v,10)/100:0,isMilestone:w,parentId:$,sortOrder:h},R=g.get(S);R&&(P.assignee=R),D&&(P.metadata={...P.metadata,isSummary:!0}),p.push(P);const N=b.getElementsByTagNameNS(ht,"PredecessorLink"),B=N.length>0?N:b.getElementsByTagName("PredecessorLink");for(let F=0;F<B.length;F++){const G=B[F],O=de(G,"PredecessorUID"),K=parseInt(de(G,"Type")||"1",10),V=de(G,"LinkLag"),x=V?parseInt(V,10):0;if(!O||O==="0")continue;const H={id:`msp-dep-${m++}`,source:`msp-${O}`,target:M,type:ha[K]??"FS",lag:x!==0?x/Cs:void 0};r.push(H)}}return{tasks:p,dependencies:r}}function hn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function g(S){let T=1,E=S;for(;E!=null&&E.parentId;)T++,E=e.tasks.get(E.parentId);return T}const d=new Map,u=new Map;for(const S of a){const T=S.parentId??"__root__",E=(d.get(T)??0)+1;if(d.set(T,E),!S.parentId)u.set(S.id,String(E));else{const C=u.get(S.parentId)??"0";u.set(S.id,`${C}.${E}`)}}const p=new Set;for(const S of a)S.parentId&&p.add(S.parentId);const r=new Map;a.forEach((S,T)=>{r.set(S.id,T+1)});const c=new Map;for(const S of l){const T=c.get(S.target)??[];T.push(S),c.set(S.target,T)}const f=new Set;for(const S of a)S.assignee&&f.add(S.assignee);const y=Array.from(f),m=new Map;y.forEach((S,T)=>{m.set(S,T+1)});const h=[];h.push('<?xml version="1.0" encoding="UTF-8"?>'),h.push('<Project xmlns="http://schemas.microsoft.com/project">'),h.push(`  <Name>${ft(n)}</Name>`),h.push(`  <Author>${ft(s)}</Author>`),h.push(`  <CreationDate>${o}</CreationDate>`),h.push("  <CalendarUID>1</CalendarUID>"),h.push("  <Calendars>"),h.push("    <Calendar>"),h.push("      <UID>1</UID>"),h.push(`      <Name>${ft(i)}</Name>`),h.push("      <IsBaseCalendar>1</IsBaseCalendar>"),h.push("    </Calendar>"),h.push("  </Calendars>"),h.push("  <Tasks>");for(const S of a){const T=r.get(S.id)??0,E=g(S),C=u.get(S.id)??"1",v=p.has(S.id),D=S.isMilestone??!1,w=Ms(S.startDate),k=Ms(S.endDate),M=pa(w,k),I=ma(M),A=Math.round((S.progress??0)*100);h.push("    <Task>"),h.push(`      <UID>${T}</UID>`),h.push(`      <ID>${T}</ID>`),h.push(`      <Name>${ft(S.name)}</Name>`),h.push(`      <Start>${S.startDate}T08:00:00</Start>`),h.push(`      <Finish>${S.endDate}T17:00:00</Finish>`),h.push(`      <Duration>${I}</Duration>`),h.push(`      <PercentComplete>${A}</PercentComplete>`),h.push(`      <Summary>${v?"1":"0"}</Summary>`),h.push(`      <Milestone>${D?"1":"0"}</Milestone>`),h.push(`      <OutlineLevel>${E}</OutlineLevel>`),h.push(`      <OutlineNumber>${C}</OutlineNumber>`);const $=c.get(S.id);if($)for(const P of $){const R=r.get(P.source)??0;if(R===0)continue;const N=fa[P.type??"FS"]??1,B=Math.round((P.lag??0)*Cs);h.push("      <PredecessorLink>"),h.push(`        <PredecessorUID>${R}</PredecessorUID>`),h.push(`        <Type>${N}</Type>`),h.push(`        <LinkLag>${B}</LinkLag>`),h.push("      </PredecessorLink>")}h.push("    </Task>")}h.push("  </Tasks>"),h.push("  <Resources>");for(const S of y){const T=m.get(S)??0;h.push("    <Resource>"),h.push(`      <UID>${T}</UID>`),h.push(`      <Name>${ft(S)}</Name>`),h.push("    </Resource>")}h.push("  </Resources>"),h.push("  <Assignments>");let b=1;for(const S of a){if(!S.assignee)continue;const T=r.get(S.id)??0,E=m.get(S.assignee)??0;T===0||E===0||(h.push("    <Assignment>"),h.push(`      <UID>${b++}</UID>`),h.push(`      <TaskUID>${T}</TaskUID>`),h.push(`      <ResourceUID>${E}</ResourceUID>`),h.push("    </Assignment>"))}return h.push("  </Assignments>"),h.push("</Project>"),h.join(`
`)}function Ta(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var d;const g=(d=l.target)==null?void 0:d.result;if(!(!g||!e))try{const u=un(g);e.dispatch({type:"SET_DATA",tasks:u.tasks,dependencies:u.dependencies})}catch(u){console.error("[MSProjectPlugin] Import failed:",u)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=un(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],g=o.getState(),d=hn(g,a);l&&l(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",g=o.getState(),d=hn(g,a),u=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(u),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const ya=[4,3],ba=1.5,Sa=.5,va=.06,wa=4,Ea=8,Da=.35,Ca=1,Is=.2,pt=6,As=864e5;function Ee(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Rs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function fn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function pn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function ka(e){let t=0;for(const n of e){const s=Ee(n.startDate).getTime(),o=Ee(n.endDate).getTime();t+=Math.max(o-s,As)}return t}function Ma(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const g=Ee(l.startDate).getTime(),u=Ee(s.startDate).getTime()-g,p=i.segments.map(r=>{const c=new Date(Ee(r.startDate).getTime()+u),f=new Date(Ee(r.endDate).getTime()+u);return{startDate:Rs(c),endDate:Rs(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const g=l.startDate,d=l.endDate;if(s.startDate!==g&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const u=i.segments.length-1;i.segments[u]={...i.segments[u],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:g}=o,{theme:d,headerHeight:u,barHeight:p}=a,r=n.getTimeScale(),c=d.barBorderRadius,f=u;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-l,0);for(const y of i){if(y.isMilestone)continue;const m=t.get(y.taskId);if(!m||m.segments.length===0)continue;const h=y.barY-g,b=y.barHeight,S=h+b/2;if(h+b<f||h>s.canvas.height)continue;const T=[];for(const k of m.segments){const M=r.dateToX(Ee(k.startDate)),I=r.dateToX(Ee(k.endDate)),A=Math.max(I-M,4);T.push({startX:M,endX:M+A,width:A})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(y.x-1,h-1,y.width+2,b+2),s.restore();for(let k=0;k<T.length-1;k++){const M=T[k].endX,I=T[k+1].startX,A=I-M;if(!(A<=0)){s.save(),s.globalAlpha=va,s.strokeStyle=y.color,s.lineWidth=wa,s.beginPath(),s.rect(M,h,A,b),s.clip();for(let $=M-b;$<I+b;$+=Ea)s.beginPath(),s.moveTo($,h+b),s.lineTo($+b,h),s.stroke();s.restore()}}for(let k=0;k<T.length-1;k++){const M=T[k].endX,I=T[k+1].startX;s.save(),s.globalAlpha=Sa,s.strokeStyle=fn(y.color,Is),s.lineWidth=ba,s.setLineDash(ya),s.beginPath(),s.moveTo(M,S),s.lineTo(I,S),s.stroke(),s.setLineDash([]),s.restore()}const E=o.tasks.get(y.taskId),C=(E==null?void 0:E.progress)??0,v=ka(m.segments);let w=C*v;for(let k=0;k<T.length;k++){const M=T[k],I=Math.max(Ee(m.segments[k].endDate).getTime()-Ee(m.segments[k].startDate).getTime(),As);if(s.save(),pn(s,M.startX,h,M.width,b,c),s.fillStyle=y.color,s.fill(),s.strokeStyle=fn(y.color,Is),s.lineWidth=Ca,s.stroke(),s.restore(),w>0&&a.showProgress){const A=Math.min(w,I),$=A/I,P=M.width*$;s.save(),pn(s,M.startX,h,M.width,b,c),s.clip(),s.globalAlpha=Da,s.fillStyle=fn(y.color,.3),s.fillRect(M.startX,h,P,b),s.restore(),w-=A}}if(y.label){const k=T[0],M=T[T.length-1],I=M.endX-k.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const $=s.measureText(y.label).width;s.textBaseline="middle",s.textAlign="left",$+pt*2<=k.width?(s.fillStyle=y.textColor,pn(s,k.startX,h,k.width,b,c),s.clip(),s.fillText(y.label,k.startX+pt,S)):$+pt<=I?(s.fillStyle=y.textColor,s.fillText(y.label,k.startX+pt,S)):(s.fillStyle=d.gridTextColor,s.fillText(y.label,M.endX+pt,S)),s.restore()}}s.restore()},destroy(){n=null}}}const mn=864e5,Ls=1e3,At=4,Ia=.6,Aa="#E53E3E",Ra="#48BB78",La="rgba(0,0,0,0.05)";function te(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function nt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Rt(e,t){return Math.round((t.getTime()-e.getTime())/mn)}function Ps(e,t){return new Date(e.getTime()+t*mn)}function Ne(e,t){return nt(Ps(te(e),t))}function Ie(e,t){const n=te(e),s=te(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(nt(n)),o;for(;i.getTime()<s.getTime();)o.push(nt(i)),i.setTime(i.getTime()+mn);return o}class Tn{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,g;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(l=a.get(d))==null||l.delete(n),((g=a.get(d))==null?void 0:g.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var g;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const d of s){let u=(a==null?void 0:a.get(d))??0;if((g=l==null?void 0:l.get(d))!=null&&g.has(n)&&(u-=o),u+o>i)return!1}return!0}}function Lt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const g=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:g})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Pa(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let g=1/0;if(typeof l=="number")g=l;else if(typeof l=="string"){const d=parseInt(l,10);isNaN(d)||(g=d)}s.set(i,{taskId:i,isCritical:!1,priority:g,totalFloat:1/0,earlyStart:te(a.startDate)})}return s}function $s(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function $a(e,t,n,s,o){const i=new Map;for(const h of s)e.has(h.taskId)&&n.has(h.resourceId)&&(i.has(h.taskId)||i.set(h.taskId,[]),i.get(h.taskId).push({resourceId:h.resourceId,units:h.units||1}));const a=new Map,l=new Map;for(const h of e.keys())a.set(h,[]),l.set(h,[]);for(const h of t.values()){if((h.type||"FS")!=="FS"||!e.has(h.source)||!e.has(h.target))continue;const S=h.lag||0;a.get(h.source).push({target:h.target,lag:S}),l.get(h.target).push({source:h.source,lag:S})}const g=new Map;for(const[h,b]of e){const S=te(b.startDate),T=te(b.endDate);g.set(h,{taskId:h,startDate:b.startDate,endDate:b.endDate,duration:Math.max(Rt(S,T),0)})}const d=new Tn;function u(){d.clear();for(const[h,b]of g){const S=i.get(h);if(!S)continue;const T=Ie(b.startDate,b.endDate);for(const E of S)d.allocate(E.resourceId,h,T,E.units)}}function p(h,b){const S=g.get(h);if(!S)return new Set;const T=new Set,E=S.startDate;if(b===E||te(b).getTime()<te(E).getTime())return T;const C=i.get(h);if(C){const v=Ie(S.startDate,S.endDate);for(const D of C)d.deallocate(D.resourceId,h,v,D.units)}if(S.startDate=b,S.endDate=Ne(b,S.duration),T.add(h),C){const v=Ie(S.startDate,S.endDate);for(const D of C)d.allocate(D.resourceId,h,v,D.units)}return T}function r(h){const b=new Set,S=g.get(h);if(!S)return b;const T=a.get(h)??[];for(const{target:E,lag:C}of T){const v=g.get(E);if(!v)continue;const D=Ne(S.endDate,C);if(te(v.startDate).getTime()<te(D).getTime()){const w=p(E,D);for(const k of w){b.add(k);const M=r(k);for(const I of M)b.add(I)}}}return b}function c(h){const b=l.get(h)??[];let S=g.get(h).startDate;S=e.get(h).startDate;for(const{source:E,lag:C}of b){const v=g.get(E);if(!v)continue;const D=Ne(v.endDate,C);te(D).getTime()>te(S).getTime()&&(S=D)}return S}u();for(let h=0;h<Ls;h++){const b=Lt(d,n);if(b.length===0)break;let S=!1;const T=b[0],E=T.taskIds.map(C=>o.get(C)).filter(C=>C!==void 0).sort($s);if(!(E.length<2))for(let C=1;C<E.length;C++){const v=E[C],D=g.get(v.taskId);if(!D)continue;const w=g.get(E[0].taskId);if(!w)continue;const k=w.endDate,M=c(v.taskId),I=te(k).getTime()>te(M).getTime()?k:M;te(I).getTime()>te(D.startDate).getTime()&&(p(v.taskId,I),r(v.taskId),S=!0);const A=d.getLoad(T.resourceId,T.date),$=n.get(T.resourceId).maxUnits;if(A<=$)break}}const f=new Map;let y=0;for(const[h,b]of g){const S=e.get(h),T=Rt(te(S.startDate),te(b.startDate));T!==0&&(f.set(h,{startDate:b.startDate,endDate:b.endDate,delayDays:T}),y+=T)}const m=Lt(d,n);return{adjustedTasks:f,totalDelay:y,conflicts:m,resolved:m.length===0}}function _a(e,t,n,s,o){const i=new Map;for(const b of s)e.has(b.taskId)&&n.has(b.resourceId)&&(i.has(b.taskId)||i.set(b.taskId,[]),i.get(b.taskId).push({resourceId:b.resourceId,units:b.units||1}));const a=new Map;for(const b of e.keys())a.set(b,[]);for(const b of t.values())(b.type||"FS")==="FS"&&(!e.has(b.source)||!e.has(b.target)||a.get(b.target).push({source:b.source,lag:b.lag||0}));const l=Array.from(e.keys()).map(b=>o.get(b)).filter(b=>b!==void 0).sort($s),g=new Map,d=new Tn,u=new Set,p=new Map;for(const[b,S]of e)p.set(b,Math.max(Rt(te(S.startDate),te(S.endDate)),0));function r(b){let T=e.get(b).startDate;const E=a.get(b)??[];for(const{source:C,lag:v}of E){const D=g.get(C);if(!D)continue;const w=Ne(D.endDate,v);te(w).getTime()>te(T).getTime()&&(T=w)}return T}function c(b,S,T){const E=i.get(b);if(!E||E.length===0)return S;let C=S;const v=365*5;for(let D=0;D<v;D++){const w=Ne(C,T),k=Ie(C,w);let M=!0;for(const I of E){const A=n.get(I.resourceId);if(!A||A.maxUnits===0)continue;const $=A.calendar?new Set(A.calendar):null;if($&&k.some(R=>$.has(R))){M=!1;break}if(!d.canFit(I.resourceId,b,k,I.units,A.maxUnits)){M=!1;break}}if(M)return C;C=Ne(C,1)}return S}const f=new Set(l.map(b=>b.taskId));for(let b=0;b<Ls&&f.size>0;b++){let S=!1;for(const T of l){if(!f.has(T.taskId)||!(a.get(T.taskId)??[]).every(A=>u.has(A.source)))continue;const v=T.taskId,D=p.get(v)??0,w=r(v),k=c(v,w,D),M=Ne(k,D);g.set(v,{taskId:v,startDate:k,endDate:M,duration:D});const I=i.get(v);if(I){const A=Ie(k,M);for(const $ of I)d.allocate($.resourceId,v,A,$.units)}u.add(v),f.delete(v),S=!0}if(!S){for(const T of f){const E=e.get(T),C=p.get(T)??0;g.set(T,{taskId:T,startDate:E.startDate,endDate:E.endDate,duration:C});const v=i.get(T);if(v){const D=Ie(E.startDate,E.endDate);for(const w of v)d.allocate(w.resourceId,T,D,w.units)}u.add(T)}f.clear()}}const y=new Map;let m=0;for(const[b,S]of g){const T=e.get(b),E=Rt(te(T.startDate),te(S.startDate));E!==0&&(y.set(b,{startDate:S.startDate,endDate:S.endDate,delayDays:E}),m+=E)}const h=Lt(d,n);return{adjustedTasks:y,totalDelay:m,conflicts:h,resolved:h.length===0}}function Oa(e,t,n,s){const o=[],i=Ie(n,Ne(s,1)),a=i.length;for(const[l,g]of t){const d=new Map;let u=0,p=0;for(const f of i){const y=e.getLoad(l,f);d.set(f,y),u+=y,y>p&&(p=y)}const r=g.maxUnits===0?1:g.maxUnits,c=a>0?u/(a*r):0;o.push({resourceId:l,resourceName:g.name,dailyLoad:d,overallUtilization:Math.min(c,1),peakUtilization:p})}return o}function _s(e,t,n,s){const o=new Tn,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const g=i.get(a);if(!g)continue;const d=s.get(a),u=(d==null?void 0:d.startDate)??l.startDate,p=(d==null?void 0:d.endDate)??l.endDate,r=Ie(u,p);for(const c of g)o.allocate(c.resourceId,a,r,c.units)}return o}function Na(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function g(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:f}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const y=g(),m=Pa(c,y,n);s==="parallel"?i=_a(c,f,t,e.assignments,m):i=$a(c,f,t,e.assignments,m);const h=u(c,i.adjustedTasks),b=_s(c,t,e.assignments,i.adjustedTasks);return a=Oa(b,t,h.start,h.end),i}function u(r,c){let f=1/0,y=-1/0;for(const[m,h]of r){const b=c.get(m),S=te((b==null?void 0:b.startDate)??h.startDate).getTime(),T=te((b==null?void 0:b.endDate)??h.endDate).getTime();S<f&&(f=S),T>y&&(y=T)}if(f===1/0){const m=nt(new Date);return{start:m,end:m}}return{start:nt(new Date(f)),end:nt(new Date(y))}}function p(r){const c=[];for(const f of e.assignments)f.taskId===r&&c.push(f.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),l.push(r.on("resourceLeveling:run",(...c)=>{const f=c[0],y=d();f&&f(y)})),l.push(r.on("resourceLeveling:result",(...c)=>{const f=c[0];f&&f(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const f=c[0];f&&f(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const f=c[0];if(!f)return;const y=r.getState(),m=_s(y.tasks,t,e.assignments,new Map);f(Lt(m,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,c,f){if(!i||a.length===0)return;const{config:y}=c,{headerHeight:m,rowHeight:h}=y,b=c.scrollX,S=c.scrollY,T=o==null?void 0:o.getTimeScale();if(!T)return;r.save(),r.beginPath(),r.rect(0,m,r.canvas.width,r.canvas.height-m),r.clip(),r.translate(-b,0);const E=new Map;for(const C of a)E.set(C.resourceId,C);for(const C of f){const v=p(C.taskId);if(v.length===0)continue;const D=E.get(v[0]);if(!D)continue;const w=t.get(v[0]);if(!w)continue;const k=w.maxUnits===0?1:w.maxUnits,I=C.barY+C.barHeight-S+1;if(I+At<m||I>r.canvas.height)continue;const A=c.tasks.get(C.taskId);if(!A)continue;const $=i.adjustedTasks.get(C.taskId),P=($==null?void 0:$.startDate)??A.startDate,R=($==null?void 0:$.endDate)??A.endDate,N=T.dateToX(te(P)),F=T.dateToX(te(R))-N;if(F<2)continue;r.fillStyle=La,r.fillRect(N,I,F,At);const G=Ie(P,R);for(const O of G){const K=D.dailyLoad.get(O)??0;if(K===0)continue;const V=T.dateToX(te(O)),H=T.dateToX(Ps(te(O),1))-V,Q=Math.min(K/k,2)/2*At,ne=K>k;r.globalAlpha=Ia,r.fillStyle=ne?Aa:Ra,r.fillRect(V,I+At-Q,H,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const Ha=864e5,Ba=75,xa=50,Os=25,Pt=.3,$t=.25,Ns=.2,yn=.15,_t=.1,Fa=.3,Hs=.5,Ua=20,Bs=40,Ya=3,Wa=5,Xa=30,xs=.25,Fs=4,Ga=2,za=5,bn=5,Us=4,Ys=.4,Va=.003,He=260,st=260,Ws=16,Ae=14,Ka="rgba(30, 30, 46, 0.92)",Sn="#e0e0e0",ja=10,Ot=32,qa=6,Nt="#EF4444",Ht="#F97316",Bt="#EAB308",xt="#22C55E";function ie(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ue(e,t){return Math.round((t.getTime()-e.getTime())/Ha)}function ge(e,t,n){return Math.max(t,Math.min(n,e))}function Za(e){return e>=Ba?"critical":e>=xa?"high":e>=Os?"medium":"low"}function Ja(e){switch(e){case"critical":return Nt;case"high":return Ht;case"medium":return Bt;case"low":return xt}}function Ft(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Qa(e,t){const n=new Map,s=new Map;for(const h of e.keys())n.set(h,[]),s.set(h,[]);for(const h of t.values())!e.has(h.source)||!e.has(h.target)||(n.get(h.source).push(h.target),s.get(h.target).push(h.source));const o=new Map,i=new Set;function a(h){if(o.has(h))return o.get(h);if(i.has(h))return 0;i.add(h);let b=0;for(const S of n.get(h)||[])b+=1+a(S);return o.set(h,b),b}for(const h of e.keys())a(h);const l=new Map;for(const[h,b]of e){const S=ie(b.startDate),T=ie(b.endDate);l.set(h,Math.max(ue(S,T),0))}const g=new Map,d=new Map,u=new Map;for(const h of e.keys())u.set(h,(s.get(h)||[]).length),g.set(h,l.get(h)||0),d.set(h,null);const p=[],r=new Map(u);for(const[h,b]of r)b===0&&p.push(h);for(;p.length>0;){const h=p.shift();for(const b of n.get(h)||[]){const S=g.get(h)+(l.get(b)||0);S>g.get(b)&&(g.set(b,S),d.set(b,h));const T=r.get(b)-1;r.set(b,T),T===0&&p.push(b)}}const c=new Set;let f=0,y=null;for(const[h,b]of g)b>f&&(f=b,y=h);let m=y;for(;m!==null;)c.add(m),m=d.get(m)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function er(e){const t=Ft(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ie(o.startDate),a=ie(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function tr(e,t,n){const s=[],o=Ft(),i=ie(e.startDate),a=ie(e.endDate),l=Math.max(ue(i,a),1),g=Math.max(ue(i,o),0),d=Math.max(ue(o,a),0),u=e.progress??0;if(e.isCompleted||u>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=ue(a,o);p=ge(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*Pt)})}else{const D=d/l;D<.2&&u<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(u*100)}% complete`,impact:Math.round(p*Pt)})):(p=ge(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*Pt)}))}let c=0;const f=ge(g/l,0,1),y=f-u;y>Hs?(c=ge(Math.round(y*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(u*100)}%)`,impact:Math.round(c*$t)})):y>Fa?(c=ge(Math.round(y*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(y*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(u*100)}%)`,impact:Math.round(c*$t)})):y>.1&&(c=ge(Math.round(y*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(u*100)}%`,impact:Math.round(c*$t)}));let m=0;const h=t.downstreamCount.get(e.id)||0,b=t.criticalPathIds.has(e.id);if(h>0){m=ge(Math.round(Math.log2(h+1)*20),0,70),b&&(m=ge(Math.round(m*1.5),0,100));const D=b?" (on critical path)":"";s.push({type:"dependency-chain",description:`${h} downstream dependent${h===1?"":"s"}${D}`,impact:Math.round(m*Ns)})}let S=0;l>Bs?(S=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(S*yn)})):l>Ua&&(S=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(S*yn)}));let T=0;if(!e.assignee)T=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(T*_t)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>Wa?(T=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(T*_t)})):D.length>Ya&&(T=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(T*_t)}))}const E=ge(Math.round(p*Pt+c*$t+m*Ns+S*yn+T*_t),0,100),C=Za(E);let v;return r&&u===0?v="Task is overdue with no progress — escalate immediately":r?v="Task is past its deadline — review scope or extend timeline":y>Hs?v="Task is significantly behind schedule — investigate blockers":l>Bs&&u<xs?v="Large task with little progress — consider splitting into smaller work items":(C==="high"||C==="critical")&&(v="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:C,riskScore:E,factors:s,suggestion:v}}function nr(e,t,n,s,o){const i=Ft();let a=0,l=0,g=0;for(const[b,S]of e){if(S.isCompleted||(S.progress??0)>=1)continue;l++;const T=ie(S.startDate),E=ie(S.endDate),C=Math.max(ue(T,E),1),v=Math.max(ue(T,i),0),D=ge(v/C,0,1);(S.progress??0)>=D-.1&&a++;const k=t.get(b);k&&(k.riskLevel==="high"||k.riskLevel==="critical")&&g++}const d=l>0?a/l:1;let u=0;for(const b of n.criticalPathIds){const S=e.get(b);if(!S||S.isCompleted)continue;const T=ie(S.endDate);i.getTime()>T.getTime()&&(u+=ue(T,i))}const p=[],r=[];for(const[b,S]of s.activeTasks)p.push(S.length),S.length>Fs&&r.push(b);let c=100;if(p.length>1){const b=p.reduce((S,T)=>S+T,0)/p.length;if(b>0){const S=p.reduce((E,C)=>E+(C-b)**2,0)/p.length,T=Math.sqrt(S)/b;c=ge(Math.round(100-T*50),0,100)}}let f=100;if(l>0){let b=0,S=0,T=0;for(const E of e.values()){if(E.isCompleted)continue;const C=ie(E.startDate),v=ie(E.endDate),D=Math.max(ue(C,v),1),w=Math.max(ue(C,i),0),k=ge(w/D,0,2);b+=E.progress??0,S+=k,T++}if(T>0){const E=b/T,C=S/T;if(C>0){const v=E/C;f=ge(Math.round(v*100),0,100)}}}const y=d*100,m=ge(100-u*10,0,100);return{overallScore:ge(Math.round(y*.25+m*.25+c*.25+f*.25),0,100),tasksAtRisk:g,criticalPathDelay:u,resourceBottlenecks:r,recommendations:o}}function sr(e,t,n,s){const o=[],i=Ft();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const c=ie(r.endDate),f=ue(c,i),y=r.progress??0;f>za&&y===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const c=ie(r.startDate),f=ie(r.endDate),y=ue(c,f),m=r.progress??0;if(y>Xa&&m<xs){const h=Math.ceil(y/15);o.push({type:"split",description:`"${r.name}" spans ${y} days — split into ${h} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],g=[];for(const[p,r]of n.activeTasks)r.length>Fs?l.push({assignee:p,taskIds:r}):r.length<Ga&&g.push(p);if(l.length>0&&g.length>0)for(const{assignee:p,taskIds:r}of l){const c=r.filter(f=>!t.criticalPathIds.has(f));c.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${g.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const c=ie(r.endDate),f=ue(i,c);if(f>=0&&f<=5){const y=s.get(p);y&&y.riskScore>=Os&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ie(p.startDate).getTime()-ie(r.startDate).getTime()),u=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const c of r)u.add(`${c}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const c=d[p],f=d[r],y=ie(c.endDate),m=ie(f.startDate);if(y.getTime()<=m.getTime()&&!(u.has(`${c.id}->${f.id}`)||u.has(`${f.id}->${c.id}`))){const b=ue(y,m);b>0&&o.push({type:"parallel",description:`"${c.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${b} days on the critical path`,taskIds:[c.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function or(e,t,n,s,o,i,a){if(e.save(),i){const l=Ys+(1-Ys)*(.5+.5*Math.sin(a*Va));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function ir(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,g=l-a,d=a+g*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const u=i>=75?xt:i>=50?Bt:i>=25?Ht:Nt;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=u,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=Sn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function ar(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Nt,label:"Critical"},{count:o.high,color:Ht,label:"High"},{count:o.medium,color:Bt,label:"Medium"},{count:o.low,color:xt,label:"Low"}];let l=-Math.PI/2;for(const g of a){if(g.count===0)continue;const d=g.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+d),e.closePath(),e.fillStyle=g.color,e.fill(),l+=d}}function rr(e,t,n,s,o){const i=t-He-Ws,a=n+Ws;e.save(),e.beginPath();const l=ja;e.moveTo(i+l,a),e.lineTo(i+He-l,a),e.arcTo(i+He,a,i+He,a+l,l),e.lineTo(i+He,a+st-l),e.arcTo(i+He,a+st,i+He-l,a+st,l),e.lineTo(i+l,a+st),e.arcTo(i,a+st,i,a+st-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Ka,e.fill(),e.fillStyle=Sn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Ae,a+Ae);const g=i+Ae+Ot+4,d=a+Ae+20+Ot+8;ir(e,g,d,Ot,qa,s.overallScore);const u=24,p=i+He-Ae-u-4,r=d;ar(e,p,r,u,o),e.font="9px sans-serif",e.textAlign="center";const c=r+u+8,f=[{count:o.critical,color:Nt,label:"C"},{count:o.high,color:Ht,label:"H"},{count:o.medium,color:Bt,label:"M"},{count:o.low,color:xt,label:"L"}],y=28,m=p-f.length*y/2+y/2;for(let T=0;T<f.length;T++){const E=f[T],C=m+T*y;e.fillStyle=E.color,e.fillText(`${E.label}:${E.count}`,C,c)}const h=d+Ot+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Ae,h);const b=h+18;e.font="10px sans-serif",e.fillStyle=Sn,e.fillText("Recommendations:",i+Ae,b);const S=s.recommendations.slice(0,3);for(let T=0;T<S.length;T++){const E=S[T],C=b+14+T*16,v=E.type==="escalate"?"⚠":E.type==="split"?"✂":E.type==="reassign"?"⇄":E.type==="parallel"?"⇉":E.type==="add-buffer"?"⏱":"ℹ",D=34,w=E.description.length>D?E.description.substring(0,D-1)+"…":E.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${v} ${w}`,i+Ae,C)}S.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Ae,b+14)),e.restore()}function lr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const g=e.getState(),{tasks:d,dependencies:u}=g;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=Qa(d,u),r=er(d),c=new Map;for(const[f,y]of d)c.set(f,tr(y,p,r));n=c,o=sr(d,p,r,n),s=nr(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(g){e=g,a=Date.now(),l(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(g,d){d(g),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(g.type)&&l()},renderCanvas(g,d,u){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,c=d.scrollY,f=p,y=Date.now()-a;g.save(),g.beginPath(),g.rect(0,f,g.canvas.width,g.canvas.height-f),g.clip(),g.translate(-r,0);for(const m of u){const h=n.get(m.taskId);if(!h||h.riskLevel==="low")continue;const b=m.x,S=m.barY-c,T=m.width,E=m.barHeight;if(S+E<f||S>g.canvas.height||b+T<0)continue;const C=b+T-bn-Us,v=S+bn+Us,D=Ja(h.riskLevel),w=h.riskLevel==="critical";or(g,C,v,bn,D,w,y)}if(g.restore(),i){const m={critical:0,high:0,medium:0,low:0};for(const h of n.values())m[h.riskLevel]++;g.save(),rr(g,g.canvas.width,p,s,m),g.restore()}},destroy(){for(const g of t)g();t=[],n=new Map,o=[]}}}const Te=160,Be=80,vn=8,cr=240,dr=160,gr=100,ur=200,Ut=8,Xs=.1,Gs=3,hr=.001,fr=500,pr=5,mr=864e5,Tr={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function zs(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function yr(e,t){return Math.round((t.getTime()-e.getTime())/mr)}function Vs(e,t,n){return e+(t-e)*n}function Yt(e,t,n){return Math.max(t,Math.min(n,e))}function wn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function br(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,g]of i)g===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),g=n.get(l);for(const d of s.get(l)){const u=n.get(d),p=g+1;(u===void 0||p>u)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function Sr(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function vr(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<pr;a++){for(let l=1;l<e.length;l++){const g=e[l],d=new Map;for(const u of g){const p=o.get(u);if(p.size===0){d.set(u,i.get(u)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(u,r/p.size)}g.sort((u,p)=>(d.get(u)??0)-(d.get(p)??0));for(let u=0;u<g.length;u++)i.set(g[u],u)}for(let l=e.length-2;l>=0;l--){const g=e[l],d=new Map;for(const u of g){const p=s.get(u);if(p.size===0){d.set(u,i.get(u)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(u,r/p.size)}g.sort((u,p)=>(d.get(u)??0)-(d.get(p)??0));for(let u=0;u<g.length;u++)i.set(g[u],u)}}}function wr(e,t){const n=new Map;if(t==="radial")return Er(e);const s=t==="lr",o=s?cr:dr,i=s?gr:ur;for(let a=0;a<e.length;a++){const l=e[a],u=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],c=u+p*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function Er(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,g=n*.5;t.set(o[a],{x:Math.cos(l)*g,y:Math.sin(l)*g})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const g=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(g)*i,y:Math.sin(g)*i})}}}return t}function mt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Dr(e,t){return e.color?e.color:e.status&&(t[e.status]||Tr[e.status])||"#94A3B8"}function Cr(e){const t=zs(e.startDate),n=zs(e.endDate);return Math.max(yr(t,n),0)}function kr(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,g=null,d=new Map,u=[],p=null,r=0,c=0,f=1,y=!1,m=0,h=0,b=0,S=0,T=null,E=0,C=0,v=null,D=null,w=new Set,k=!1,M=0,I=0,A=0,$=0;function P(X,L){return{x:(X-r)/f,y:(L-c)/f}}function R(X,L){const{x:_,y:z}=P(X,L);for(const W of d.values()){const Y=W.x,q=W.y;if(_>=Y&&_<=Y+Te&&z>=q&&z<=q+Be)return W}return null}function N(){const X=e.getState(),{tasks:L,dependencies:_,config:z}=X;if(L.size===0){d=new Map,u=[];return}p=sn(L,_);const W=br(L,_),Y=Sr(W);vr(Y,_,L);const q=wr(Y,s);let Z=1/0,ee=-1/0,re=1/0,se=-1/0;for(const{x:J,y:ce}of q.values())Z=Math.min(Z,J),ee=Math.max(ee,J+Te),re=Math.min(re,ce),se=Math.max(se,ce+Be);const le=(Z+ee)/2,Le=(re+se)/2,he=d;d=new Map;for(const[J,ce]of L){const fe=q.get(J);if(!fe)continue;const Pe=fe.x-le,Xe=fe.y-Le,Ce=he.get(J);d.set(J,{id:J,task:ce,layer:W.get(J)??0,orderInLayer:0,x:Ce?Ce.x:Pe,y:Ce?Ce.y:Xe,targetX:Pe,targetY:Xe,isCritical:p.criticalTaskIds.has(J),isDragging:!1})}for(const J of Y)for(let ce=0;ce<J.length;ce++){const fe=d.get(J[ce]);fe&&(fe.orderInLayer=ce)}u=[];for(const J of _.values())!L.has(J.source)||!L.has(J.target)||u.push({id:J.id,dep:J,sourceId:J.source,targetId:J.target,isCritical:p.criticalTaskIds.has(J.source)&&p.criticalTaskIds.has(J.target)})}function B(X){const L=e.getState(),_=new Set;_.add(X);const z=new Map,W=new Map;for(const Z of L.tasks.keys())z.set(Z,[]),W.set(Z,[]);for(const Z of L.dependencies.values())!L.tasks.has(Z.source)||!L.tasks.has(Z.target)||(z.get(Z.source).push(Z.target),W.get(Z.target).push(Z.source));const Y=[X];for(;Y.length>0;){const Z=Y.shift();for(const ee of W.get(Z)||[])_.has(ee)||(_.add(ee),Y.push(ee))}const q=[X];for(;q.length>0;){const Z=q.shift();for(const ee of z.get(Z)||[])_.has(ee)||(_.add(ee),q.push(ee))}return _}function F(){k&&cancelAnimationFrame(I),k=!0,M=performance.now(),G()}function G(){const X=performance.now()-M,L=Yt(X/fr,0,1),_=1-Math.pow(1-L,3);let z=!1;for(const W of d.values()){if(W.isDragging)continue;const Y=Math.abs(W.x-W.targetX),q=Math.abs(W.y-W.targetY);Y>.5||q>.5?(W.x=Vs(W.x,W.targetX,_),W.y=Vs(W.y,W.targetY,_),z=!0):(W.x=W.targetX,W.y=W.targetY)}if(O(),z&&L<1)I=requestAnimationFrame(G);else{k=!1;for(const W of d.values())W.isDragging||(W.x=W.targetX,W.y=W.targetY);O()}}function O(){if(!i||!o)return;const X=e.getState(),{config:L}=X,_=L.theme,z=L.colorMap,W=_.timelineBg==="#1A202C"||_.gridBg==="#1A202C"||_.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(_.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=W?"#1A202C":"#F7F8FA",i.fillRect(0,0,A,$),i.save(),i.translate(r,c),i.scale(f,f);for(const Y of u){const q=d.get(Y.sourceId),Z=d.get(Y.targetId);if(!q||!Z)continue;const ee=w.has(Y.sourceId)&&w.has(Y.targetId),re=v===Y.sourceId||v===Y.targetId,se=v!==null&&!re||D!==null&&!ee,le=q.x+Te,Le=q.y+Be/2,he=Z.x,J=Z.y+Be/2;i.save(),se?i.globalAlpha=.15:(re||ee)&&(i.globalAlpha=1),Y.isCritical?(i.strokeStyle=_.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=re?W?"#A0AEC0":"#4A5568":W?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const ce=(le+he)/2;i.beginPath(),i.moveTo(le,Le),i.quadraticCurveTo(ce,Le,(le+he)/2,(Le+J)/2),i.quadraticCurveTo(ce,J,he,J),i.stroke();const fe=Math.atan2(J-(Le+J)/2,he-ce);i.beginPath(),i.moveTo(he,J),i.lineTo(he-Ut*Math.cos(fe-Math.PI/6),J-Ut*Math.sin(fe-Math.PI/6)),i.lineTo(he-Ut*Math.cos(fe+Math.PI/6),J-Ut*Math.sin(fe+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Pe=Y.dep.type||"FS",Xe=Y.dep.lag||0,Ce=Xe!==0?`${Pe} +${Xe}d`:Pe!=="FS"?Pe:"";if(Ce&&!se){const vt=(le+he)/2,$n=(Le+J)/2-8;i.font=`10px ${_.fontFamily}`,i.fillStyle=W?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ce,vt,$n)}i.restore()}for(const Y of d.values()){const q=v!==null&&v!==Y.id&&!V(v,Y.id)||D!==null&&!w.has(Y.id),Z=v===Y.id,ee=D===Y.id,re=Dr(Y.task,z),se=Y.x,le=Y.y;i.save(),q&&(i.globalAlpha=.25),Y.isCritical&&!q&&(i.save(),i.shadowColor=_.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,mt(i,se,le,Te,Be,vn),i.fillStyle="transparent",i.fill(),i.restore()),mt(i,se,le,Te,Be,vn),i.fillStyle=W?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=re,i.lineWidth=Z||ee?2.5:1.5,i.stroke(),ee&&(i.strokeStyle=_.selectionColor||"#3182CE",i.lineWidth=2,mt(i,se-2,le-2,Te+4,Be+4,vn+2),i.stroke()),i.font=`600 12px ${_.fontFamily}`,i.fillStyle=W?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Le=wn(i,Y.task.name,Te-20);i.fillText(Le,se+10,le+8);const he=le+26;i.beginPath(),i.arc(se+16,he+5,4,0,Math.PI*2),i.fillStyle=re,i.fill(),i.font=`10px ${_.fontFamily}`,i.fillStyle=W?"#A0AEC0":"#718096",i.textBaseline="top";const J=Y.task.status||"No status";i.fillText(wn(i,J,Te-40),se+24,he);const ce=Cr(Y.task),fe=ce===1?"1 day":`${ce} days`;i.font=`10px ${_.fontFamily}`,i.fillStyle=W?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(fe,se+10,le+42),Y.task.assignee&&(i.font=`10px ${_.fontFamily}`,i.fillStyle=W?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(wn(i,Y.task.assignee,Te/2-10),se+Te-10,le+42));const Pe=Y.task.progress??0,Xe=le+Be-6,Ce=Te-20,vt=3;if(mt(i,se+10,Xe,Ce,vt,1.5),i.fillStyle=W?"#4A5568":"#E2E8F0",i.fill(),Pe>0){const $n=Math.max(vt,Ce*Yt(Pe,0,1));mt(i,se+10,Xe,$n,vt,1.5),i.fillStyle=re,i.fill()}i.restore()}i.restore(),K(W,_.fontFamily)}function K(X,L){if(!i)return;const _={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${_[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,A-12,12),i.restore()}function V(X,L){for(const _ of u)if(_.sourceId===X&&_.targetId===L||_.sourceId===L&&_.targetId===X)return!0;return!1}function x(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;g=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const _=o.getContext("2d");_&&(i=_,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",Se),o.addEventListener("mousemove",De),o.addEventListener("mouseup",ve),o.addEventListener("mouseleave",it),o.addEventListener("dblclick",je),o.addEventListener("wheel",bt,{passive:!1}),o.addEventListener("touchstart",qe,{passive:!1}),o.addEventListener("touchmove",Ze,{passive:!1}),o.addEventListener("touchend",St))}function H(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(A=X.clientWidth,$=X.clientHeight,o.width=Math.round(A*a),o.height=Math.round($*a),o.style.width=`${A}px`,o.style.height=`${$}px`)}function U(){if(o){n=!0,o.style.display="block",g&&(g.style.visibility="hidden"),H(),ne(),N();for(const X of d.values())X.x=X.targetX,X.y=X.targetY;O()}}function Q(){o&&(n=!1,o.style.display="none",g&&(g.style.visibility="visible"),v=null,D=null,w=new Set)}function ne(){r=A/2,c=$/2,f=1}function oe(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function Se(X){const{x:L,y:_}=oe(X),z=R(L,_);z?(T=z,z.isDragging=!0,E=P(L,_).x-z.x,C=P(L,_).y-z.y,D=z.id,w=B(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),O()):(y=!0,m=L,h=_,b=r,S=c,D&&(D=null,w=new Set,e.dispatch({type:"DESELECT_ALL"}),O()))}function De(X){if(!o)return;const{x:L,y:_}=oe(X);if(T){const Y=P(L,_);T.x=Y.x-E,T.y=Y.y-C,T.targetX=T.x,T.targetY=T.y,O();return}if(y){const Y=L-m,q=_-h;r=b+Y,c=S+q,O();return}const z=R(L,_),W=z?z.id:null;W!==v&&(v=W,o.style.cursor=v?"pointer":"default",O())}function ve(X){T&&(T.isDragging=!1,T=null),y=!1}function it(X){T&&(T.isDragging=!1,T=null),y=!1,v&&(v=null,O())}function je(X){const{x:L,y:_}=oe(X),z=R(L,_);if(z){const W=e.getState();W.tasks.get(z.id)&&W.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function bt(X){if(X.preventDefault(),!o)return;const{x:L,y:_}=oe(X),z=P(L,_),W=-X.deltaY*hr;f=Yt(f+W*f,Xs,Gs);const Y=P(L,_);r+=(Y.x-z.x)*f,c+=(Y.y-z.y)*f,O()}let pe=0,Ye=0,We=0;function qe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],_=o.getBoundingClientRect(),z=L.clientX-_.left,W=L.clientY-_.top,Y=R(z,W);Y?(T=Y,Y.isDragging=!0,E=P(z,W).x-Y.x,C=P(z,W).y-Y.y,D=Y.id,w=B(Y.id),e.dispatch({type:"SELECT_TASK",taskId:Y.id})):(y=!0,m=z,h=W,b=r,S=c),O()}else if(X.touches.length===2){y=!1,T&&(T.isDragging=!1,T=null);const L=X.touches[0],_=X.touches[1];pe=Math.hypot(_.clientX-L.clientX,_.clientY-L.clientY),Ye=(L.clientX+_.clientX)/2,We=(L.clientY+_.clientY)/2}}}function Ze(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const _=X.touches[0],z=_.clientX-L.left,W=_.clientY-L.top;if(T){const Y=P(z,W);T.x=Y.x-E,T.y=Y.y-C,T.targetX=T.x,T.targetY=T.y,O()}else if(y){const Y=z-m,q=W-h;r=b+Y,c=S+q,O()}}else if(X.touches.length===2){const _=X.touches[0],z=X.touches[1],W=Math.hypot(z.clientX-_.clientX,z.clientY-_.clientY),Y=(_.clientX+z.clientX)/2,q=(_.clientY+z.clientY)/2,Z=Y-L.left,ee=q-L.top;if(pe>0){const re=W/pe,se=P(Z,ee);f=Yt(f*re,Xs,Gs);const le=P(Z,ee);r+=(le.x-se.x)*f,c+=(le.y-se.y)*f}r+=Y-Ye,c+=q-We,pe=W,Ye=Y,We=q,O()}}function St(X){T&&(T.isDragging=!1,T=null),y=!1,pe=0}function Pn(){o&&(o.removeEventListener("mousedown",Se),o.removeEventListener("mousemove",De),o.removeEventListener("mouseup",ve),o.removeEventListener("mouseleave",it),o.removeEventListener("dblclick",je),o.removeEventListener("wheel",bt),o.removeEventListener("touchstart",qe),o.removeEventListener("touchmove",Ze),o.removeEventListener("touchend",St),o.remove(),o=null,i=null),g&&(g.style.visibility="visible",g=null),k&&(cancelAnimationFrame(I),k=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():U()})),t.push(e.on("networkGraph:layout",(...L)=>{const _=L[0];_!==s&&(s=_,n&&(N(),F()))})),t.push(e.on("stateChange",()=>{n&&(N(),F())}))},renderDOM(X,L){o||x(X),n&&(H(),O())},destroy(){for(const X of t)X();t=[],Pn(),d=new Map,u=[],p=null,n=!1}}}const Ks=300,js="nimbus-gantt-config-panel",En="nimbus-gantt-config-panel-styles",qs=300,Dn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],Mr=`
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
    transition: opacity ${qs}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${Ks}px;
    width: ${Ks}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${qs}ms ease;
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
`;function Ir(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(js);return e?JSON.parse(e):{}}catch{return{}}}function Ar(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(js,JSON.stringify(e))}catch{}}function Zs(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Wt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Rr(){if(typeof document>"u"||document.getElementById(En))return;const e=document.createElement("style");e.id=En,e.textContent=Mr,document.head.appendChild(e)}function Lr(){if(typeof document>"u")return;const e=document.getElementById(En);e&&e.remove()}function Xt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const g=document.createElement("input");g.type="range",g.className="ng-config-slider",g.min=String(t),g.max=String(n),g.step=String(o),g.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),g.addEventListener("input",()=>{const u=Number(g.value);d.textContent=String(u),i(u)}),a.appendChild(l),a.appendChild(g),a.appendChild(d),a}function Tt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function Gt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=Js(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function Js(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function Pr(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function g(){if(!e)return;const v=e.getState();e.dispatch({type:"SET_SCROLL",x:v.scrollX,y:v.scrollY})}function d(v){Object.assign(t,v),Ar(t)}function u(v,D,w){v[D]=w}function p(v,D){if(!e)return;const w=e.getState();u(w.config,v,D),d({[v]:D}),g()}function r(v,D){if(!e)return;const w=e.getState();u(w.config.theme,v,D),g()}function c(v){if(!e)return;const D=Dn.find(k=>k.name===v);if(!D)return;const w=e.getState();Object.assign(w.config.theme,D.values),d({themePreset:v}),g()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function y(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function m(v,D){var X;const{config:w}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?y():f()}),v.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",y),v.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",v.appendChild(o)),o.innerHTML="";const k=document.createElement("div");k.className="ng-config-panel-header",k.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",y),k.appendChild(M),o.appendChild(k);const I=h("Display Settings");I.appendChild(Xt("Row height",24,60,w.rowHeight,2,L=>p("rowHeight",L))),I.appendChild(Xt("Bar height",16,40,w.barHeight,2,L=>p("barHeight",L))),I.appendChild(Xt("Grid width",0,500,w.gridWidth,10,L=>p("gridWidth",L))),I.appendChild(Xt("Font size",10,16,w.theme.fontSize,1,L=>{u(D.config.theme,"fontSize",L),d({fontSize:L}),g()})),I.appendChild(Tt("Today marker",w.showToday,L=>{u(D.config,"showToday",L),d({showToday:L}),g()})),I.appendChild(Tt("Weekends",w.showWeekends,L=>{u(D.config,"showWeekends",L),d({showWeekends:L}),g()})),I.appendChild(Tt("Progress bars",w.showProgress,L=>{u(D.config,"showProgress",L),d({showProgress:L}),g()})),I.appendChild(Tt("Dependency arrows",a,L=>{a=L,d({showDependencies:L}),g()})),I.appendChild(Tt("Labels on bars",t.showBarLabels!==!1,L=>{d({showBarLabels:L}),g()})),o.appendChild(I);const A=h("Color Theme"),$=document.createElement("div");$.className="ng-config-row";const P=document.createElement("span");P.className="ng-config-label",P.textContent="Preset";const R=document.createElement("select");R.className="ng-config-select";const N=document.createElement("option");N.value="",N.textContent="Custom",R.appendChild(N);for(const L of Dn){const _=document.createElement("option");_.value=L.name,_.textContent=L.name,t.themePreset===L.name&&(_.selected=!0),R.appendChild(_)}R.addEventListener("change",()=>{R.value&&c(R.value)}),$.appendChild(P),$.appendChild(R),A.appendChild($),A.appendChild(Gt("Bar default",w.theme.barDefaultColor,L=>{r("barDefaultColor",L),d({customColors:{...t.customColors,barDefault:L}})})),A.appendChild(Gt("Today line",w.theme.todayLineColor,L=>{r("todayLineColor",L),d({customColors:{...t.customColors,todayLine:L}})})),A.appendChild(Gt("Grid lines",w.theme.timelineGridColor,L=>{r("timelineGridColor",L),d({customColors:{...t.customColors,gridLines:L}})})),A.appendChild(Gt("Background",w.theme.timelineBg,L=>{r("timelineBg",L),d({customColors:{...t.customColors,background:L}})}));const B=document.createElement("div");B.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",B.textContent="Status Color Map",A.appendChild(B);const F={...w.colorMap,...t.statusColorMap},G=document.createElement("div");function O(){G.innerHTML="";const L=Object.entries(F);for(const[z,W]of L){const Y=document.createElement("div");Y.className="ng-config-color-map-entry";const q=document.createElement("input");q.className="ng-config-color-map-status",q.value=z,q.readOnly=!0;const Z=document.createElement("input");Z.type="color",Z.className="ng-config-color-input",Z.value=Js(W),Z.addEventListener("input",()=>{F[z]=Z.value,w.colorMap[z]=Z.value,d({statusColorMap:{...F}}),g()});const ee=document.createElement("button");ee.className="ng-config-color-map-remove",ee.innerHTML="×",ee.addEventListener("click",()=>{delete F[z],delete w.colorMap[z],d({statusColorMap:{...F}}),O(),g()}),Y.appendChild(q),Y.appendChild(Z),Y.appendChild(ee),G.appendChild(Y)}const _=document.createElement("button");_.className="ng-config-color-map-add",_.textContent="+ Add status color",_.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(F[z.trim()]="#3b82f6",w.colorMap[z.trim()]="#3b82f6",d({statusColorMap:{...F}}),O(),g())}),G.appendChild(_)}O(),A.appendChild(G),o.appendChild(A);const K=h("Zoom & Time"),V=document.createElement("div");V.className="ng-config-row";const x=document.createElement("span");x.className="ng-config-label",x.textContent="Zoom";const H=document.createElement("div");H.className="ng-config-zoom-group";const U=["day","week","month","quarter"];for(const L of U){const _=document.createElement("button");_.className="ng-config-zoom-btn"+(D.zoomLevel===L?" ng-active":""),_.textContent=L.charAt(0).toUpperCase()+L.slice(1),_.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),d({zoomLevel:L}),H.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===_)))}),H.appendChild(_)}V.appendChild(x),V.appendChild(H),K.appendChild(V);const Q=document.createElement("div");Q.className="ng-config-row";const ne=document.createElement("span");ne.className="ng-config-label",ne.textContent="Start date";const oe=document.createElement("input");oe.type="date",oe.className="ng-config-date-input",oe.value=Zs(D.dateRange.start),oe.addEventListener("change",()=>{if(!e||!oe.value)return;const L=Wt(oe.value),_=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:_}),d({dateRangeStart:oe.value})}),Q.appendChild(ne),Q.appendChild(oe),K.appendChild(Q);const Se=document.createElement("div");Se.className="ng-config-row";const De=document.createElement("span");De.className="ng-config-label",De.textContent="End date";const ve=document.createElement("input");ve.type="date",ve.className="ng-config-date-input",ve.value=Zs(D.dateRange.end),ve.addEventListener("change",()=>{if(!e||!ve.value)return;const L=e.getState().dateRange.start,_=Wt(ve.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:_}),d({dateRangeEnd:ve.value})}),Se.appendChild(De),Se.appendChild(ve),K.appendChild(Se);const it=document.createElement("div");it.style.cssText="margin-top: 8px;";const je=document.createElement("button");je.className="ng-config-btn ng-primary",je.textContent="Fit to View",je.addEventListener("click",()=>{e&&(u(e.getState().config,"fitToView",!0),g())}),it.appendChild(je),K.appendChild(it),o.appendChild(K);const bt=h("Export"),pe=document.createElement("div");pe.style.cssText="display: flex; flex-wrap: wrap;";const Ye=document.createElement("button");Ye.className="ng-config-btn",Ye.textContent="PNG",Ye.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),b("export:png"))}),pe.appendChild(Ye);const We=document.createElement("button");We.className="ng-config-btn",We.textContent="SVG",We.addEventListener("click",()=>b("export:svg")),pe.appendChild(We);const qe=document.createElement("button");qe.className="ng-config-btn",qe.textContent="CSV",qe.addEventListener("click",()=>{e&&T(e.getState())}),pe.appendChild(qe);const Ze=document.createElement("button");Ze.className="ng-config-btn",Ze.textContent="Copy Table",Ze.addEventListener("click",()=>{e&&E(e.getState())}),pe.appendChild(Ze),bt.appendChild(pe),o.appendChild(bt);const St=h("Plugin Toggles"),Pn=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of Pn){const _=document.createElement("div");_.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=L.label;const W=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,Y=document.createElement("span");Y.className="ng-config-plugin-status"+(W?" ng-active-status":""),Y.textContent=W?"Active":"Inactive";const q=document.createElement("div");q.className="ng-config-toggle"+(W?" ng-active":"");const Z=document.createElement("div");Z.className="ng-config-toggle-knob",q.appendChild(Z);let ee=W;q.addEventListener("click",()=>{ee=!ee,q.classList.toggle("ng-active",ee),Y.className="ng-config-plugin-status"+(ee?" ng-active-status":""),Y.textContent=ee?"Active":"Inactive";const se={...t.pluginToggles,[L.key]:ee};d({pluginToggles:se}),b(L.event)});const re=document.createElement("div");re.style.cssText="display: flex; align-items: center;",re.appendChild(z),re.appendChild(Y),_.appendChild(re),_.appendChild(q),St.appendChild(_)}o.appendChild(St)}function h(v){const D=document.createElement("div");D.className="ng-config-section";const w=document.createElement("div");return w.className="ng-config-section-title",w.textContent=v,D.appendChild(w),D}function b(v){e&&S.forEach(D=>D(v))}const S=[];function T(v){const D=Array.from(v.tasks.values());if(D.length===0)return;const w=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],k=D.map(P=>[P.id,`"${(P.name||"").replace(/"/g,'""')}"`,P.startDate,P.endDate,String(Math.round((P.progress??0)*100))+"%",P.status||"",P.assignee||"",P.priority||"",P.groupName||""]),M=[w.join(","),...k.map(P=>P.join(","))].join(`
`),I=new Blob([M],{type:"text/csv;charset=utf-8;"}),A=URL.createObjectURL(I),$=document.createElement("a");$.href=A,$.download="gantt-tasks.csv",document.body.appendChild($),$.click(),document.body.removeChild($),URL.revokeObjectURL(A)}function E(v){const D=Array.from(v.tasks.values());if(D.length===0)return;const w=["Name","Start","End","Progress","Status","Assignee"],k=D.map(A=>[A.name,A.startDate,A.endDate,Math.round((A.progress??0)*100)+"%",A.status||"",A.assignee||""]),I=[w.join("	"),...k.map(A=>A.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(I).catch(()=>{})}function C(v){const D=t;if(D.rowHeight!==void 0&&u(v.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&u(v.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&u(v.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&u(v.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&u(v.config,"showToday",D.showToday),D.showWeekends!==void 0&&u(v.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&u(v.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const w=Dn.find(k=>k.name===D.themePreset);w&&Object.assign(v.config.theme,w.values)}D.customColors&&(D.customColors.barDefault&&u(v.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&u(v.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&u(v.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&u(v.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(v.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:Wt(D.dateRangeStart),end:Wt(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(v){e=v,Rr(),t=Ir();const D=v.on("render",()=>{D(),C(v.getState()),g()});l.push(D);const w=v.on("config:open",()=>f()),k=v.on("config:close",()=>y()),M=v.on("config:toggle",()=>{i?y():f()});l.push(w,k,M)},renderDOM(v,D){m(v,D)},destroy(){l.forEach(v=>v()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Lr(),e=null,i=!1}}}const Qs=864e5,Cn="nimbus-gantt-heatmap-styles",ae=28,ye=2,xe=48,be=160,$r=3,eo="#1e1e2e",to="#166534",no="#a16207",so="#b91c1c",_r=`
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
`;function oo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Or(e){return String(e.getUTCDate())}function Nr(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Hr(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function io(e,t){return Math.round((t.getTime()-e.getTime())/Qs)}function ao(e,t){return new Date(e.getTime()+t*Qs)}function ot(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Br(e,t){return e===0?eo:e===1?to:e===2?no:so}function xr(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Fr(){if(typeof document>"u"||document.getElementById(Cn))return;const e=document.createElement("style");e.id=Cn,e.textContent=_r,document.head.appendChild(e)}function Ur(){if(typeof document>"u")return;const e=document.getElementById(Cn);e&&e.remove()}function Yr(e){const t=Array.from(e.tasks.values()),n=new Set;for(const u of t){const p=u.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=io(o,i)+1,l=[];for(let u=0;u<a;u++)l.push(ao(o,u));const g=new Map;let d=0;for(const u of s)for(const p of l){const r=`${u}|${ot(p)}`;g.set(r,{assignee:u,date:p,dateKey:ot(p),tasks:[],count:0})}for(const u of t){const p=u.assignee||"Unassigned",r=oo(u.startDate),c=oo(u.endDate),f=io(r,c)+1;for(let y=0;y<f;y++){const m=ao(r,y),h=`${p}|${ot(m)}`,b=g.get(h);b&&(b.tasks.push(u),b.count++,b.count>d&&(d=b.count))}}return{assignees:s,dates:l,cells:g,maxCount:d}}function Wr(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function g(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=Yr(p);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const f=document.createElement("canvas"),y=be+r.dates.length*(ae+ye),m=xe+r.assignees.length*(ae+ye),h=window.devicePixelRatio||1;f.width=y*h,f.height=m*h,f.style.width=y+"px",f.style.height=m+"px",f.style.cursor="pointer";const b=f.getContext("2d");b.scale(h,h),b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle";let S="",T=be;for(let E=0;E<r.dates.length;E++){const C=r.dates[E],v=Nr(C),D=be+E*(ae+ye);if(v!==S){if(S&&E>0){const w=(T+D)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(S,w,12)}T=D,S=v}}if(S){const E=be+r.dates.length*(ae+ye),C=(T+E)/2;b.fillStyle="#94a3b8",b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.fillText(S,C,12)}b.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let E=0;E<r.dates.length;E++){const C=r.dates[E],v=be+E*(ae+ye)+ae/2,D=C.getUTCDay()===0||C.getUTCDay()===6;b.fillStyle=D?"#475569":"#64748b",b.fillText(Or(C),v,32)}b.beginPath(),b.strokeStyle="#1e293b",b.lineWidth=1,b.moveTo(0,xe-.5),b.lineTo(y,xe-.5),b.stroke();for(let E=0;E<r.assignees.length;E++){const C=r.assignees[E],v=xe+E*(ae+ye);b.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="left",b.textBaseline="middle",b.fillStyle="#cbd5e1",b.save(),b.beginPath(),b.rect(0,v,be-8,ae),b.clip(),b.fillText(C,8,v+ae/2),b.restore();for(let D=0;D<r.dates.length;D++){const w=r.dates[D],k=`${C}|${ot(w)}`,M=r.cells.get(k),I=(M==null?void 0:M.count)??0,A=be+D*(ae+ye),$=Br(I),P=xr(I,r.maxCount);b.globalAlpha=P,b.fillStyle=$,u(b,A,v,ae,ae,$r),b.fill(),I>=2&&(b.globalAlpha=1,b.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',b.textAlign="center",b.textBaseline="middle",b.fillStyle="#fff",b.fillText(String(I),A+ae/2,v+ae/2)),b.globalAlpha=1}}c.appendChild(f),f.addEventListener("mousemove",E=>{if(!n)return;const C=f.getBoundingClientRect(),v=E.clientX-C.left,D=E.clientY-C.top,w=Math.floor((v-be)/(ae+ye)),k=Math.floor((D-xe)/(ae+ye));if(w<0||w>=r.dates.length||k<0||k>=r.assignees.length||v<be||D<xe){n.classList.remove("ng-visible");return}const M=r.dates[w],I=r.assignees[k],A=`${I}|${ot(M)}`,$=r.cells.get(A);if(!$||$.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const P=document.createElement("div");P.className="ng-heatmap-tooltip-date",P.textContent=`${I} - ${Hr(M)}`,n.appendChild(P);for(const B of $.tasks){const F=document.createElement("div");F.className="ng-heatmap-tooltip-task",F.textContent=`• ${B.name}`,n.appendChild(F)}n.classList.add("ng-visible");const R=E.clientX+12,N=E.clientY+12;n.style.left=R+"px",n.style.top=N+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",E=>{if(!e)return;const C=f.getBoundingClientRect(),v=E.clientX-C.left,D=E.clientY-C.top,w=Math.floor((v-be)/(ae+ye)),k=Math.floor((D-xe)/(ae+ye));if(w<0||w>=r.dates.length||k<0||k>=r.assignees.length||v<be||D<xe)return;const M=r.dates[w],A=`${r.assignees[k]}|${ot(M)}`,$=r.cells.get(A);if(!(!$||$.count===0)){g();for(const P of $.tasks)e.dispatch({type:"SELECT_TASK",taskId:P.id,multi:!0})}})}function u(p,r,c,f,y,m){p.beginPath(),p.moveTo(r+m,c),p.lineTo(r+f-m,c),p.quadraticCurveTo(r+f,c,r+f,c+m),p.lineTo(r+f,c+y-m),p.quadraticCurveTo(r+f,c+y,r+f-m,c+y),p.lineTo(r+m,c+y),p.quadraticCurveTo(r,c+y,r,c+y-m),p.lineTo(r,c+m),p.quadraticCurveTo(r,c,r+m,c),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Fr();const r=p.on("heatmap:toggle",()=>a()),c=p.on("heatmap:show",()=>l()),f=p.on("heatmap:hide",()=>g());i.push(r,c,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",c.appendChild(f);const y=document.createElement("div");y.className="ng-heatmap-legend";const m=[{color:eo,label:"None"},{color:to,label:"1 task"},{color:no,label:"2 tasks"},{color:so,label:"3+ tasks"}];for(const b of m){const S=document.createElement("span");S.className="ng-heatmap-legend-swatch",S.style.background=b.color,y.appendChild(S);const T=document.createElement("span");T.textContent=b.label,y.appendChild(T)}c.appendChild(y);const h=document.createElement("button");h.className="ng-heatmap-close",h.textContent="Back to Gantt",h.addEventListener("click",g),c.appendChild(h),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Ur(),e=null,s=!1,o=null}}}const Fe=200,Ue=80,ro=12,lo=6,Xr="#1a1a2e",Gr="#334155",zr="rgba(59, 130, 246, 0.3)",Vr="rgba(59, 130, 246, 0.7)",Kr=1.5,jr=2,qr=1,kn="nimbus-gantt-minimap-styles",Zr=864e5,Jr=`
  .ng-minimap {
    position: absolute;
    bottom: ${ro}px;
    right: ${ro}px;
    width: ${Fe}px;
    height: ${Ue}px;
    z-index: 900;
    border-radius: ${lo}px;
    border: 1px solid ${Gr};
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.35);
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
    border-radius: ${lo}px;
  }
`;function Qr(){if(typeof document>"u"||document.getElementById(kn))return;const e=document.createElement("style");e.id=kn,e.textContent=Jr,document.head.appendChild(e)}function el(){if(typeof document>"u")return;const e=document.getElementById(kn);e&&e.remove()}function tl(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,g=1,d=0,u=0,p=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function y(){o=!1,t&&t.classList.add("ng-hidden")}function m(E,C){const v=E/l-p/2,D=C/g-r/2;return{x:Math.max(0,Math.min(v,d-p)),y:Math.max(0,Math.min(D,u-r))}}function h(E){if(!e||!n)return;E.preventDefault(),i=!0;const C=n.getBoundingClientRect(),v=E.clientX-C.left,D=E.clientY-C.top,w=m(v,D);e.dispatch({type:"SET_SCROLL",x:w.x,y:w.y})}function b(E){if(!i||!e||!n)return;E.preventDefault();const C=n.getBoundingClientRect(),v=Math.max(0,Math.min(E.clientX-C.left,Fe)),D=Math.max(0,Math.min(E.clientY-C.top,Ue)),w=m(v,D);e.dispatch({type:"SET_SCROLL",x:w.x,y:w.y})}function S(){i=!1}function T(E,C){if(!s||!n||!o)return;const v=window.devicePixelRatio||1;n.width=Fe*v,n.height=Ue*v,n.style.width=Fe+"px",n.style.height=Ue+"px",s.scale(v,v);const{config:D,scrollX:w,scrollY:k,dateRange:M}=E,I=e.getTimeScale(),A=Math.round((M.end.getTime()-M.start.getTime())/Zr),$=I.getColumnWidth();if(d=Math.max(A*$,1),u=Math.max(E.flatVisibleIds.length*D.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=u>0?Math.min(u,600):600,t&&t.parentElement){const x=t.parentElement;p=x.clientWidth-D.gridWidth,r=x.clientHeight-D.headerHeight}l=Fe/Math.max(d,1),g=Ue/Math.max(u,1),s.fillStyle=Xr,s.fillRect(0,0,Fe,Ue);const P=new Map;for(const x of C)P.has(x.rowIndex)||P.set(x.rowIndex,[]),P.get(x.rowIndex).push(x);for(const x of C){const H=x.x*l,U=Math.max(x.width*l,1),Q=x.rowIndex*D.rowHeight*g;s.fillStyle=x.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(H,Q,U,Math.max(jr,D.rowHeight*g-qr))}s.globalAlpha=1;const R=w*l,N=k*g,B=p*l,F=r*g,G=Math.max(0,Math.min(R,Fe-1)),O=Math.max(0,Math.min(N,Ue-1)),K=Math.min(B,Fe-G),V=Math.min(F,Ue-O);s.fillStyle=zr,s.fillRect(G,O,K,V),s.strokeStyle=Vr,s.lineWidth=Kr,s.strokeRect(G,O,K,V)}return{name:"MiniMapPlugin",install(E){e=E,Qr();const C=E.on("minimap:toggle",()=>c()),v=E.on("minimap:show",()=>f()),D=E.on("minimap:hide",()=>y());a.push(C,v,D),typeof document<"u"&&(document.addEventListener("mousemove",b),document.addEventListener("mouseup",S))},renderDOM(E,C){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",h),t.appendChild(n),E.appendChild(t));const v=(e==null?void 0:e.getLayouts())??[];T(C,v)},destroy(){a.forEach(E=>E()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",b),document.removeEventListener("mouseup",S)),t&&(t.remove(),t=null),n=null,s=null,el(),e=null,o=!0,i=!1}}}const nl="#f59e0b",sl=[6,4],ol=1,ze=16,il=4,al="rgba(15, 23, 42, 0.95)",rl="#e2e8f0",ll="#334155",cl=6,Ve=10,co=220,go=12,uo=13;function dl(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function yt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function gl(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=yt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function ul(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let g=0;g<l*2;g++){const d=g%2===0?i:a,u=Math.PI/2*-1+Math.PI/l*g,p=t+Math.cos(u)*d,r=n+Math.sin(u)*d;g===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=yt(o,.25),e.lineWidth=.5,e.stroke()}function hl(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=yt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function fl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=yt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function pl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=yt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const ho={flag:gl,star:ul,warning:hl,info:fl,deadline:pl};function ml(e,t,n,s,o){e.save();const i=`${go}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${uo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const g=[];let d=0;if(t.description){const m=t.description.split(" ");let h="";for(const b of m){const S=h?h+" "+b:b;e.measureText(S).width>co-Ve*2&&h?(g.push(h),d=Math.max(d,e.measureText(h).width),h=b):h=S}h&&(g.push(h),d=Math.max(d,e.measureText(h).width))}const u=Math.min(co,Math.max(l,d)+Ve*2),p=go+4,r=uo+4,c=Ve*2+r+(g.length>0?4+g.length*p:0);let f=n-u/2;const y=s-c-8;if(f<4&&(f=4),f+u>o-4&&(f=o-u-4),e.beginPath(),Tl(e,f,y,u,c,cl),e.fillStyle=al,e.fill(),e.strokeStyle=ll,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=rl,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+Ve,y+Ve),g.length>0){e.font=i,e.fillStyle="#94a3b8";let m=y+Ve+r+4;for(const h of g)e.fillText(h,f+Ve,m),m+=p}e.restore()}function Tl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function yl(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,g=null,d=null;function u(h){return n.find(b=>b.id===h)}function p(h){n.push(h),y()}function r(h){n=n.filter(b=>b.id!==h),y()}function c(h,b){const S=u(h);S&&(Object.assign(S,b),y())}function f(){return[...n]}function y(){if(!t)return;const h=t.getState();t.dispatch({type:"SET_SCROLL",x:h.scrollX,y:h.scrollY})}function m(h){const b=h.canvas;d!==b&&(d&&g&&d.removeEventListener("mousemove",g),d=b,g=S=>{const T=b.getBoundingClientRect();a=S.clientX-T.left,l=S.clientY-T.top;let E=null;for(const C of o){const v=a-C.x,D=l-C.y;if(Math.sqrt(v*v+D*D)<=C.size){E=C.note.id;break}}E!==s&&(s=E,b.style.cursor=s?"pointer":"",y())},b.addEventListener("mousemove",g))}return{name:"TimelineNotesPlugin",install(h){t=h;const b=h.on("notes:add",(...C)=>{const v=C[0];v&&v.id&&v.date&&v.label&&p(v)}),S=h.on("notes:remove",(...C)=>{const v=C[0];v&&r(v)}),T=h.on("notes:update",(...C)=>{const v=C[0];if(v&&v.id){const{id:D,...w}=v;c(D,w)}}),E=h.on("notes:list",(...C)=>{const v=C[0];typeof v=="function"&&v(f())});i.push(b,S,T,E)},renderCanvas(h,b,S){if(!t||n.length===0)return;const{config:T,scrollX:E,scrollY:C,dateRange:v}=b,{theme:D}=T,w=T.headerHeight,k=t.getTimeScale();m(h);const M=h.canvas.width/(window.devicePixelRatio||1),I=h.canvas.height/(window.devicePixelRatio||1),A=w,$=I-A;o=[],h.save();for(const P of n){const R=dl(P.date);if(R<v.start||R>v.end)continue;const N=P.color||nl,B=P.icon||"flag",F=k.dateToX(R)-E;if(F<-ze||F>M+ze)continue;h.save(),h.beginPath(),h.setLineDash(sl),h.strokeStyle=N,h.globalAlpha=.5,h.lineWidth=ol,h.moveTo(F,A),h.lineTo(F,A+$),h.stroke(),h.setLineDash([]),h.globalAlpha=1,h.restore();const G=F,O=A+il+ze/2,K=ho[B]||ho.flag;h.save(),h.beginPath(),h.arc(G,O,ze/2+3,0,Math.PI*2),h.fillStyle="rgba(0, 0, 0, 0.4)",h.fill(),h.restore(),h.save(),K(h,G,O,ze,N),h.restore(),o.push({note:P,x:G,y:O,size:ze/2+4}),s===P.id&&ml(h,P,G,O-ze/2-4,M)}h.restore()},destroy(){i.forEach(h=>h()),i.length=0,d&&g&&d.removeEventListener("mousemove",g),t=null,d=null,g=null,s=null,o=[]}}}const bl=500,Sl=40,fo=7,po=3,mo=5,vl=500,Mn="nimbus-gantt-timetravel-styles",To={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},wl=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Sl}px;
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
    width: ${fo*2}px;
    height: ${fo*2}px;
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
    width: ${po*2}px;
    height: ${po*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${mo*2}px;
    height: ${mo*2}px;
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
`;function El(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Dl(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Cl(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function kl(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function Ml(){if(typeof document>"u"||document.getElementById(Mn))return;const e=document.createElement("style");e.id=Mn,e.textContent=wl,document.head.appendChild(e)}function Il(){if(typeof document>"u")return;const e=document.getElementById(Mn);e&&e.remove()}const yo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),zt=[.5,1,2,4];function Al(e){const t=(e==null?void 0:e.maxSnapshots)??bl,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,g=null,d=1;const u=[];let p=null,r=null,c=null,f=null,y=null,m=null,h=null,b=!1;function S(O){if(!s||a)return;const K=s.getState(),V=Cl(K,O);i<o.length-1&&(o.length=i+1),o.push(V),o.length>t&&o.shift(),i=o.length-1}function T(O){if(!s||o.length===0)return;const K=Math.max(0,Math.min(O,o.length-1));i=K;const V=o[K];a=!0;const x=V.tasks.map(U=>({id:U.id,name:U.name,startDate:U.startDate,endDate:U.endDate,progress:U.progress,status:U.status})),H=V.dependencies.map(U=>({id:U.id,source:U.source,target:U.target}));s.dispatch({type:"SET_DATA",tasks:x,dependencies:H}),a=!1,A()}function E(){o.length>0&&T(o.length-1),v()}function C(){if(l||o.length<=1)return;l=!0;const O=zt[d],K=vl/O;g=setInterval(()=>{if(i>=o.length-1){v();return}T(i+1)},K),A()}function v(){l=!1,g!==null&&(clearInterval(g),g=null),A()}function D(){l?v():C()}function w(){d=(d+1)%zt.length,l&&(v(),C()),A()}function k(){v(),i>0&&T(i-1)}function M(){v(),i<o.length-1&&T(i+1)}function I(){v(),o.length=0,i=-1,a=!1,A()}function A(){if(p){if(f){const O=o.length,K=O>0?i+1:0;f.textContent=`${K} / ${O}`}y&&(y.textContent=l?"⏸":"▶",y.classList.toggle("ng-active",l)),m&&(m.textContent=`${zt[d]}x`),$(),P()}}function $(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const O=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${O}%`}function P(){if(!h||!r||(h.innerHTML="",o.length===0))return;const O=200,K=o.length>O?Math.ceil(o.length/O):1;for(let V=0;V<o.length;V+=K){const x=o[V],H=o.length<=1?50:V/(o.length-1)*100,U=El(x.action.split(" ")[0]==="Loaded"?"SET_DATA":R(x.action)),Q=To[U]||To.data,ne=document.createElement("div");ne.className="ng-timetravel-dot",ne.style.left=`${H}%`,ne.style.background=Q;const oe=document.createElement("div");oe.className="ng-timetravel-tooltip",oe.textContent=`${x.action}
${kl(x.timestamp)}`,oe.style.whiteSpace="pre",ne.appendChild(oe);const Se=V;ne.addEventListener("click",De=>{De.stopPropagation(),v(),T(Se)}),h.appendChild(ne)}}function R(O){return O.startsWith("Moved")?"TASK_MOVE":O.startsWith("Resized")?"TASK_RESIZE":O.startsWith("Added task")?"ADD_TASK":O.startsWith("Added dependency")?"ADD_DEPENDENCY":O.startsWith("Removed task")?"REMOVE_TASK":O.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":O.startsWith("Updated")?"UPDATE_TASK":(O.startsWith("Loaded"),"SET_DATA")}function N(O){if(!r||o.length<=1)return;const K=r.getBoundingClientRect(),V=Math.max(0,Math.min(1,(O.clientX-K.left)/K.width)),x=Math.round(V*(o.length-1));v(),T(x)}function B(O){O.preventDefault(),O.stopPropagation(),b=!0,c&&c.classList.add("ng-dragging"),v()}function F(O){if(!b||!r||o.length<=1)return;const K=r.getBoundingClientRect(),V=Math.max(0,Math.min(1,(O.clientX-K.left)/K.width)),x=Math.round(V*(o.length-1));T(x)}function G(){b&&(b=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(O){s=O,Ml(),u.push(O.on("timeTravel:record",()=>{s&&(s.getState(),S("Manual snapshot"))}),O.on("timeTravel:scrub",(...K)=>{const V=K[0];v(),T(V)}),O.on("timeTravel:play",()=>C()),O.on("timeTravel:pause",()=>v()),O.on("timeTravel:present",()=>E()),O.on("timeTravel:clear",()=>I()),O.on("timeTravel:history",(...K)=>{const V=K[0];typeof V=="function"&&V([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",F),document.addEventListener("mouseup",G))},middleware(O,K){let V="";n&&yo.has(O.type)&&s&&!a&&(V=Dl(O,s.getState())),K(O),n&&yo.has(O.type)&&!a&&V&&S(V)},renderDOM(O,K){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const V=document.createElement("button");V.className="ng-timetravel-btn",V.textContent="◀",V.title="Step backward",V.addEventListener("click",()=>k()),p.appendChild(V),y=document.createElement("button"),y.className="ng-timetravel-btn",y.textContent="▶",y.title="Play / Pause",y.addEventListener("click",()=>D()),p.appendChild(y);const x=document.createElement("button");x.className="ng-timetravel-btn",x.textContent="▶",x.title="Step forward",x.addEventListener("click",()=>M()),p.appendChild(x),m=document.createElement("span"),m.className="ng-timetravel-speed ng-timetravel-btn",m.textContent=`${zt[d]}x`,m.title="Click to cycle speed",m.addEventListener("click",()=>w()),p.appendChild(m),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",N);const H=document.createElement("div");H.className="ng-timetravel-rail",r.appendChild(H),h=document.createElement("div"),h.style.position="absolute",h.style.inset="0",r.appendChild(h),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",B),r.appendChild(c),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const U=document.createElement("button");U.className="ng-timetravel-btn ng-present",U.textContent="Present",U.title="Return to latest state",U.addEventListener("click",()=>E()),p.appendChild(U),O.appendChild(p)}A()},destroy(){v();for(const O of u)O();u.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",F),document.removeEventListener("mouseup",G)),p&&(p.remove(),p=null),r=null,c=null,f=null,y=null,m=null,h=null,Il(),o.length=0,i=-1,a=!1,l=!1,b=!1,s=null}}}const bo=864e5,Rl=60,Ll=2,So=[6,4],In="nimbus-gantt-montecarlo-styles",vo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},Pl=.08,$l=`
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
`;function An(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Vt(e,t){return Math.round((t.getTime()-e.getTime())/bo)}function Ke(e,t){return new Date(e.getTime()+t*bo)}function wo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Eo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function _l(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Ol(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Nl(e,t){return e+Math.random()*(t-e)}function Hl(e,t,n,s,o,i,a,l){const g=e.length;if(g===0)return 0;const d=new Float64Array(g),u=new Float64Array(g),p=new Int32Array(l),r=[];for(let y=0;y<g;y++)p[y]===0&&(r.push(y),d[y]=o[y],u[y]=o[y]+s[y]);let c=0;for(;c<r.length;){const y=r[c++],m=u[y],h=i[y];for(let b=0;b<h.length;b++){const S=h[b];m>d[S]&&(d[S]=m,u[S]=m+s[S]),p[S]--,p[S]===0&&r.push(S)}}for(let y=0;y<g;y++)u[y]===0&&s[y]>0&&(d[y]=o[y],u[y]=o[y]+s[y]);let f=0;for(let y=0;y<g;y++)u[y]>f&&(f=u[y]);return f}function Bl(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),g=new Float64Array(e),d=new Float64Array(e),u=new Int32Array(i),p=[],r=[];for(let m=0;m<e;m++)u[m]===0&&(r.push(m),a[m]=n[m],l[m]=n[m]+t[m]);let c=0;for(;c<r.length;){const m=r[c++];p.push(m);const h=l[m];for(const b of s[m])h>a[b]&&(a[b]=h,l[b]=h+t[b]),u[b]--,u[b]===0&&r.push(b)}for(let m=0;m<e;m++)l[m]===0&&t[m]>0&&(a[m]=n[m],l[m]=n[m]+t[m],p.push(m));let f=0;for(let m=0;m<e;m++)l[m]>f&&(f=l[m]);for(let m=0;m<e;m++)s[m].length===0?(d[m]=f,g[m]=f-t[m]):(d[m]=1/0,g[m]=1/0);for(let m=p.length-1;m>=0;m--){const h=p[m];if(d[h]===1/0){let b=1/0;for(const S of s[h])g[S]<b&&(b=g[S]);b===1/0?d[h]=f:d[h]=b,g[h]=d[h]-t[h]}}const y=new Set;for(let m=0;m<e;m++){const h=g[m]-a[m];Math.abs(h)<.5&&y.add(m)}return y}function xl(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],g=new Map;for(const H of e.keys())g.set(H,l.length),l.push(H);const d=l.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const u=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const H of e.values()){const U=An(H.startDate).getTime();U<r&&(r=U)}const c=new Date(r);for(let H=0;H<d;H++){const U=e.get(l[H]),Q=An(U.startDate),ne=An(U.endDate);u[H]=Math.max(Vt(Q,ne),1),p[H]=Vt(c,Q)}const f=Array.from({length:d},()=>[]),y=Array.from({length:d},()=>[]),m=new Int32Array(d);for(const H of t.values()){if((H.type||"FS")!=="FS")continue;const Q=g.get(H.source),ne=g.get(H.target);Q===void 0||ne===void 0||(f[Q].push(ne),y[ne].push(Q),m[ne]++)}const h=f.map(H=>new Int32Array(H)),b=y.map(H=>new Int32Array(H)),S=new Float64Array(s),T=new Float64Array(d),E=new Float64Array(d),C=new Float64Array(d),v=new Float64Array(d),D=new Float64Array(d),w=Math.max(1,Math.floor(s/100));for(let H=0;H<s;H++){for(let U=0;U<d;U++){const Q=u[U];let ne;switch(i){case"triangular":{const oe=Q*(1-o),Se=Q,De=Q*(1+o*1.5);ne=_l(oe,Se,De);break}case"normal":{ne=Ol(Q,Q*o);break}case"uniform":{ne=Nl(Q*(1-o),Q*(1+o));break}}T[U]=Math.max(.5,ne),E[U]+=T[U],C[U]+=T[U]*T[U],T[U]>u[U]&&v[U]++}if(S[H]=Hl(l,g,u,T,p,h,b,m),H%w===0){const U=Bl(d,T,p,h,b,m);for(const Q of U)D[Q]++}}const k=Array.from(S).sort((H,U)=>H-U),M=k.map(H=>Ke(c,H)),I=new Map;for(const H of a){const U=Math.min(Math.floor(H*k.length),k.length-1);I.set(H,Ke(c,k[U]))}let A=0;for(let H=0;H<s;H++)A+=k[H];const $=A/s,P=Ke(c,$),R=Math.floor(s/2),N=Ke(c,k[R]);let B=0;for(let H=0;H<s;H++){const U=k[H]-$;B+=U*U}const F=Math.sqrt(B/s),G=Ke(c,k[0]),O=Ke(c,k[k.length-1]),K=new Map;for(let H=0;H<d;H++){const U=E[H]/s,Q=C[H]/s-U*U;K.set(l[H],{meanDuration:U,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:v[H]/s})}const V=Math.floor(s/w),x=new Map;for(let H=0;H<d;H++)D[H]>0&&x.set(l[H],D[H]/V);return{iterations:s,finishDates:M,percentiles:I,meanFinishDate:P,medianFinishDate:N,earliestFinish:G,latestFinish:O,standardDeviation:F,taskRisk:K,criticalPathFrequency:x}}function Fl(){if(typeof document>"u"||document.getElementById(In))return;const e=document.createElement("style");e.id=In,e.textContent=$l,document.head.appendChild(e)}function Ul(){if(typeof document>"u")return;const e=document.getElementById(In);e&&e.remove()}function Yl(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=xl(f.tasks,f.dependencies,c),u()}function g(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function u(){if(!a||!s)return;let r="",c=0;for(const[h,b]of s.criticalPathFrequency)b>c&&(c=b,r=h);let f=r;if(n){const h=n.getState().tasks.get(r);h&&(f=h.name)}let y=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const h of t.confidenceLevels){const b=s.percentiles.get(h);if(!b)continue;const S=Math.round(h*100),T=vo[h]||"#94A3B8";y+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${S}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${T}">${Eo(b)}</span>
        </div>
      `}if(y+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${Eo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const h=Math.round(c*100);y+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${h}% of runs)
        </div>
      `}a.innerHTML=y;const m=a.querySelector(".ng-montecarlo-close");m&&m.addEventListener("click",()=>g())}function p(r,c){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:y}=c.config,m=c.scrollX,h=r.canvas.width/(window.devicePixelRatio||1),b=r.canvas.height/(window.devicePixelRatio||1),S=y,T=b-S,E=s.earliestFinish,C=s.latestFinish,v=Math.max(Vt(E,C),1),D=f.getColumnWidth(),w=Math.max(D,Ll),k=Math.max(Math.ceil(v),1),M=new Uint32Array(k);for(const R of s.finishDates){const N=Vt(E,R),B=Math.min(Math.max(Math.floor(N),0),k-1);M[B]++}let I=0;for(let R=0;R<k;R++)M[R]>I&&(I=M[R]);if(I===0)return;r.save(),r.beginPath(),r.rect(0,S,h,T),r.clip(),r.translate(-m,0);const A=s.finishDates[Math.floor(s.finishDates.length*.1)],$=s.finishDates[Math.floor(s.finishDates.length*.9)];if(A&&$){const R=f.dateToX(A),N=f.dateToX($),B=r.createLinearGradient(R,0,N,0);B.addColorStop(0,"rgba(34, 197, 94, 0.0)"),B.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),B.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),B.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=B,r.globalAlpha=Pl*5,r.fillRect(R,S,N-R,T),r.globalAlpha=1}const P=b-8;for(let R=0;R<k;R++){if(M[R]===0)continue;const N=Ke(E,R),B=f.dateToX(N),F=M[R]/I*Rl,G=k>1?R/(k-1):.5;let O,K,V;if(G<.5){const x=G*2;O=Math.round(34+200*x),K=Math.round(197+-18*x),V=Math.round(94+-86*x)}else{const x=(G-.5)*2;O=Math.round(234+5*x),K=Math.round(179+-111*x),V=Math.round(8+60*x)}r.fillStyle=`rgba(${O}, ${K}, ${V}, 0.6)`,r.fillRect(B,P-F,Math.max(w-1,1),F)}r.setLineDash(So),r.lineWidth=1.5;for(const[R,N]of s.percentiles){const B=f.dateToX(N),F=vo[R]||"#94A3B8",G=`P${Math.round(R*100)}`;r.strokeStyle=F,r.beginPath(),r.moveTo(B,S),r.lineTo(B,b),r.stroke(),r.setLineDash([]),r.fillStyle=F,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const O=r.measureText(`${G}: ${wo(N)}`).width,K=`${G}: ${wo(N)}`,V=O+8,x=16,H=B-V/2,U=S+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(H+3,U),r.lineTo(H+V-3,U),r.arcTo(H+V,U,H+V,U+3,3),r.lineTo(H+V,U+x-3),r.arcTo(H+V,U+x,H+V-3,U+x,3),r.lineTo(H+3,U+x),r.arcTo(H,U+x,H,U+x-3,3),r.lineTo(H,U+3),r.arcTo(H,U,H+3,U,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=F,r.fillText(K,B,U+3),r.setLineDash(So)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Fl(),i.push(r.on("montecarlo:run",(...c)=>{const f=c[0];l(f)}),r.on("montecarlo:result",(...c)=>{const f=c[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>g()),r.on("montecarlo:configure",(...c)=>{const f=c[0];f&&d(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,f){!o||!s||p(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&u()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Ul(),s=null,n=null}}}const Kt=864e5,Do=400,Rn="nimbus-gantt-narrative-styles",Co=300;function Re(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ln(e,t){return Math.round((t.getTime()-e.getTime())/Kt)}function ko(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Mo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*Kt)}function Io(e,t){return new Date(e.getTime()+t*Kt)}function Wl(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const w of n){const k=Re(w.startDate).getTime(),M=Re(w.endDate).getTime();k<s&&(s=k),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=Ln(i,a),g=new Date;g.setUTCHours(0,0,0,0);const d=new Map,u=new Map;for(const w of t.values())!e.has(w.source)||!e.has(w.target)||(d.has(w.source)||d.set(w.source,[]),d.get(w.source).push(w.target),u.has(w.target)||u.set(w.target,[]),u.get(w.target).push(w.source));const p=Vl(n,t),r=Mo(i),c=Mo(a),f=[];let y=r;for(;y.getTime()<=c.getTime();)f.push({start:new Date(y),end:Io(y,6)}),y=Io(y,7);const m=[];for(let w=0;w<f.length;w++){const k=f[w],M=k.start,I=k.end,A=[],$=[],P=[],R=[],N=[],B=[],F=[];for(const x of n){const H=Re(x.startDate),U=Re(x.endDate);H>=M&&H<=I&&(A.push(x),x.isMilestone?(B.push(x),F.push(`Milestone: ${x.name}`)):F.push(`Started: ${x.name}`)),U>=M&&U<=I&&(x.isCompleted||x.progress!==void 0&&x.progress>=1)&&($.push(x),F.push(`Completed: ${x.name}`)),H<=I&&U>=M&&(N.push(x),H<M&&!x.isCompleted&&(x.progress===void 0||x.progress===0)&&P.push(x),!x.isCompleted&&x.progress!==void 0&&x.progress>0&&x.progress<1&&R.push(x))}for(const x of n)if(x.isMilestone){const H=Re(x.startDate);H>=M&&H<=I&&!B.includes(x)&&(B.push(x),F.push(`Milestone: ${x.name}`))}const G=N.filter(x=>p.has(x.id)),O=Xl(A,$,P,N,G),K=Gl(A,$,P,R,N,G,B,d,e),V=`Week ${w+1} (${ko(M)}–${ko(I)})`;m.push({weekLabel:V,headline:O,body:K,metrics:{started:A.length,completed:$.length,delayed:P.length,onTrack:R.length},events:F})}const h=n.length,b=n.filter(w=>w.isCompleted||w.progress!==void 0&&w.progress>=1).length,S=n.filter(w=>!w.isCompleted&&w.progress!==void 0&&w.progress>0&&w.progress<1).length,T=h-b-S,E=h>0?Math.round(b/h*100):0,C=E>=75?"strong":E>=50?"moderate":E>=25?"early-stage":"just getting started",v=`This project spans ${l} days across ${f.length} weeks with ${h} tasks. Progress is ${C} at ${E}% completion (${b} done, ${S} in progress, ${T} not started).`,D=zl(n,p,d,u,i,a,g);return{title:"Project Narrative",generatedAt:Date.now(),summary:v,chapters:m,insights:D}}function Xl(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Gl(e,t,n,s,o,i,a,l,g){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(f=>f.name).join(", ");d.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const f=l.get(c.id);if(f)for(const y of f){const m=g.get(y);m&&!r.includes(m.name)&&r.push(m.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const u=new Map;for(const r of o)r.assignee&&u.set(r.assignee,(u.get(r.assignee)||0)+1);const p=Array.from(u.entries()).sort((r,c)=>c[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function zl(e,t,n,s,o,i,a){const l=[];if(t.size>0){const m=e.filter(S=>t.has(S.id)),h=m.slice(0,4).map(S=>S.name).join(", "),b=m.length>4?` and ${m.length-4} more`:"";l.push(`The critical path runs through ${h}${b} — any delay here pushes the project finish.`)}const g=new Map;for(const m of e)m.assignee&&!m.isCompleted&&g.set(m.assignee,(g.get(m.assignee)||0)+1);const d=Array.from(g.entries()).sort((m,h)=>h[1]-m[1]);d.length>0&&d[0][1]>=2&&l.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const u=e.filter(m=>m.isCompleted?!1:Re(m.startDate)<a&&(m.progress===void 0||m.progress===0));u.length>0&&l.push(`${u.length} task${u.length>1?"s have":" has"} zero progress despite being past ${u.length>1?"their":"its"} start date${u.length>1?"s":""}.`);const p=Ln(o,i),r=Ln(o,a);if(r>0&&p>0){const m=Math.round(r/p*100),h=e.filter(T=>T.isCompleted||T.progress!==void 0&&T.progress>=1).length,b=Math.round(h/e.length*100),S=b-m;Math.abs(S)>=5?S>0?l.push(`Project is running ahead: ${b}% of tasks completed with ${m}% of time elapsed.`):l.push(`Project is running behind: only ${b}% of tasks completed with ${m}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${b}% complete at ${m}% of elapsed time.`)}const c=e.filter(m=>{if(m.isCompleted||m.progress!==void 0&&m.progress>0)return!1;const h=s.get(m.id);return!h||h.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,y="";for(const m of e){const h=n.get(m.id);h&&h.length>f&&(f=h.length,y=m.name)}return f>=3&&l.push(`"${y}" is a bottleneck with ${f} downstream tasks depending on it.`),l}function Vl(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const f=Re(c.endDate).getTime();i.set(c.id,f)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),f=i.get(c);for(const y of s.get(c)){const m=n.get(y.target),h=Re(m.endDate).getTime()-Re(m.startDate).getTime(),b=f+y.lag*Kt+h;b>i.get(y.target)&&i.set(y.target,b);const S=l.get(y.target)-1;l.set(y.target,S),S===0&&a.push(y.target)}}let g=-1/0,d="";for(const[c,f]of i)f>g&&(g=f,d=c);if(!d)return new Set;const u=new Set,p=new Map;for(const c of e)p.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||p.get(c.target).push({source:c.source,lag:c.lag||0}));let r=d;for(;r;){u.add(r);const c=p.get(r);if(!c||c.length===0)break;let f="",y=-1/0;for(const m of c){const h=i.get(m.source)||0;h>y&&(y=h,f=m.source)}if(!f||u.has(f))break;r=f}return u}const Kl=`
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
    transition: opacity ${Co}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Do}px;
    width: ${Do}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${Co}ms ease;
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
`;function jl(){if(typeof document>"u"||document.getElementById(Rn))return;const e=document.createElement("style");e.id=Rn,e.textContent=Kl,document.head.appendChild(e)}function ql(){if(typeof document>"u")return;const e=document.getElementById(Rn);e&&e.remove()}function Zl(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Jl(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=Wl(r.tasks,r.dependencies)}function g(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),u()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function u(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",c.appendChild(f);const y=document.createElement("span");y.textContent="Project Story",c.appendChild(y),r.appendChild(c);const m=document.createElement("div");m.style.display="flex",m.style.alignItems="center",m.style.gap="4px";const h=document.createElement("button");h.className="ng-narrative-refresh",h.innerHTML="↻",h.title="Regenerate",h.addEventListener("click",()=>{l(),u()}),m.appendChild(h);const b=document.createElement("button");b.className="ng-narrative-close",b.innerHTML="×",b.addEventListener("click",d),m.appendChild(b),r.appendChild(m),a.appendChild(r);const S=document.createElement("div");if(S.className="ng-narrative-summary",S.textContent=t.summary,a.appendChild(S),t.chapters.length===0){const C=document.createElement("div");C.className="ng-narrative-empty",C.textContent="No weekly chapters to display.",a.appendChild(C)}else for(const C of t.chapters){const v=document.createElement("div");v.className="ng-narrative-chapter";const D=Zl(C),w=document.createElement("div");w.className=`ng-narrative-chapter-header ng-${D}`;const k=document.createElement("div");k.className="ng-narrative-week-label",k.textContent=C.weekLabel,w.appendChild(k);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=C.headline,w.appendChild(M),v.appendChild(w);const I=document.createElement("div");if(I.className="ng-narrative-metrics",C.metrics.started>0&&I.appendChild(p("started",`${C.metrics.started} started`)),C.metrics.completed>0&&I.appendChild(p("completed",`${C.metrics.completed} done`)),C.metrics.delayed>0&&I.appendChild(p("delayed",`${C.metrics.delayed} delayed`)),C.metrics.onTrack>0&&I.appendChild(p("ontrack",`${C.metrics.onTrack} on track`)),I.children.length>0&&v.appendChild(I),C.body){const A=document.createElement("div");A.className="ng-narrative-body",A.textContent=C.body,v.appendChild(A)}a.appendChild(v)}if(t.insights.length>0){const C=document.createElement("div");C.className="ng-narrative-insights";const v=document.createElement("div");v.className="ng-narrative-insights-title",v.innerHTML="<span>💡</span> Key Insights",C.appendChild(v);for(const D of t.insights){const w=document.createElement("div");w.className="ng-narrative-insight";const k=document.createElement("span");k.className="ng-narrative-insight-icon",k.textContent="•",w.appendChild(k);const M=document.createElement("span");M.textContent=D,w.appendChild(M),C.appendChild(w)}a.appendChild(C)}const T=document.createElement("div");T.className="ng-narrative-timestamp";const E=new Date(t.generatedAt);T.textContent=`Generated ${E.toLocaleString()}`,a.appendChild(T)}function p(r,c){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=c,f}return{name:"NarrativePlugin",install(r){e=r,jl(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&u()}),r.on("narrative:show",()=>g()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():g()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),u())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),ql(),e=null,t=null,n=!1}}}return j.BaselinePlugin=xi,j.ConfigPanelPlugin=Pr,j.CriticalPathPlugin=Ai,j.DARK_THEME=Zn,j.DarkThemePlugin=ea,j.DependencyRenderer=Kn,j.EventBus=On,j.ExportPlugin=Vi,j.GroupingPlugin=Ei,j.HeatmapViewPlugin=Wr,j.HitTest=zn,j.KeyboardPlugin=ii,j.LIGHT_THEME=Qt,j.LayoutEngine=Fn,j.MSProjectPlugin=Ta,j.MilestonePlugin=ui,j.MiniMapPlugin=tl,j.MonteCarloPlugin=Yl,j.MotionControlPlugin=ga,j.NarrativePlugin=Jl,j.NetworkGraphPlugin=kr,j.NimbusGantt=ti,j.ResourceLevelingPlugin=Na,j.RiskAnalysisPlugin=lr,j.SplitTaskPlugin=Ma,j.TelemetryPlugin=la,j.TimeScale=Bn,j.TimeTravelPlugin=Al,j.TimelineNotesPlugin=yl,j.TooltipManager=qn,j.UndoRedoPlugin=si,j.VirtualScrollPlugin=Wi,j.WorkCalendarPlugin=ia,j.computeCPM=sn,j.exportMSProjectXML=hn,j.importMSProjectXML=un,j.parseDate=Zt,j.resolveConfig=Jn,Object.defineProperty(j,Symbol.toStringTag,{value:"Module"}),j})({});
//# sourceMappingURL=nimbus-gantt.iife.js.map
