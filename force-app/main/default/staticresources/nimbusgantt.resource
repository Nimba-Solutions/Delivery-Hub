var NimbusGantt=(function(J){"use strict";function Ue(e,t){const n=new Map;for(const c of e.values()){const u=c.parentId&&e.has(c.parentId)?c.parentId:void 0;let d=n.get(u);d||(d=[],n.set(u,d)),d.push(c)}const s=[];function o(c,u){const d=c.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return d!==h?d-h:c.name.localeCompare(u.name)}function i(c,u,d){const h=n.get(c);return h?(h.sort(o),h.map(p=>{const l=n.has(p.id)&&t.has(p.id),f=d,T={task:p,children:[],depth:u,expanded:l,visible:f,rowIndex:-1};return f&&(T.rowIndex=s.length,s.push(p.id)),T.children=i(p.id,u+1,f&&l),T})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function yt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class gn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Ci(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Ci(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const c of t.tasks)n.set(c.id,c);const s=new Map;if(t.dependencies)for(const c of t.dependencies)s.set(c.id,c);const{tree:o,flatIds:i}=Ue(n,e.expandedIds),a=yt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:c}=Ue(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:c}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=yt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};case"SET_TIME_CURSOR":return{...e,timeCursorDate:t.date};default:return e}}function os(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class is{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const hn=864e5,Ii=hn*7,Mi={day:40,week:120,month:180,quarter:200},as=["January","February","March","April","May","June","July","August","September","October","November","December"],rs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class ls{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=Mi[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/hn)}countWeeks(){return Math.ceil(this.totalMs/Ii)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const c=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:c,width:this.columnWidth,date:new Date(o)}),o=cs(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=fn(i),c=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${as[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:c,width:u-c,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=cs(this.rangeStart,i*7),c=i*this.columnWidth;n.push({label:`${rs[a.getUTCMonth()]} ${a.getUTCDate()}`,x:c,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=fn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,c=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),d=this.dateToX(c);t.push({label:`${as[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:d-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const c=a*this.columnWidth;n.push({label:rs[o.getUTCMonth()],x:c,width:this.columnWidth,date:new Date(o)}),o=fn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),c=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(c),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(c)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const c=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${c}`,x:u,width:this.columnWidth,date:new Date(o)}),o=Ai(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),c=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(c),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:h-d,date:new Date(c)}),i=a}return[t,n]}}function cs(e,t){return new Date(e.getTime()+t*hn)}function Ai(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function fn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class ds{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const c=t[a],u=n.get(c);if(!u)continue;const d=bt(u.startDate),h=bt(u.endDate),p=s.dateToX(d),r=s.dateToX(h)-p,l=Math.max(r,o.minBarWidth),f=a*o.rowHeight,T=f+(o.rowHeight-o.barHeight)/2,S=l*(u.progress||0),g=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:c,rowIndex:a,x:p,y:f,width:l,barY:T,barHeight:o.barHeight,progressWidth:S,color:g,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function bt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Pt=864e5,us=1,Ri=2,Li=.5,Pi=2,gs=8,$i=6,pn=2;class _i{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:c}=this,{config:u}=t,{theme:d}=u,h=t.scrollX,p=t.scrollY;o.setTransform(c,0,0,c,0,0);const l=u.headerHeight,f=a-l;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,l,i,f),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,l,f,d),this.renderGridLines(s,l,f,d,h),this.renderAltRows(t,n,l,d,h,p);const T=this.getTodayX(t,u,s);u.showToday&&T!==null&&this.renderTodayBackground(T,s,l,f,d),this.renderGroupRowBgs(t,n,u,h,p,l,f),this.renderTaskBars(t,n,u,d,h,p,l,f),this.renderDragSnapGuide(t,n,s,l,f,d),u.showToday&&T!==null&&this.renderTodayLine(T,l,f,d),o.restore(),this.renderHeader(s,u,d,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:c}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const d=c.getTime();for(;u.getTime()<=d;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+Pt),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}u.setTime(u.getTime()+Pt)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,c=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=Li;for(const u of c){const d=this.snapToPixel(u);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:c,displayWidth:u}=this,d=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const c=new Date(a.getTime()+Pt),u=n.dateToX(c)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,c){const{ctx:u,displayWidth:d}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const l=p.y-i+a;l+h<a||l>a+c||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,l,d,h),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,l,d,2)),u.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const c=t.dragState;if(!c||c.type!=="move"&&c.type!=="resize-left"&&c.type!=="resize-right")return;const u=n.find(S=>S.taskId===c.taskId);if(!u)return;const d=new Date;d.setHours(0,0,0,0);const h=new Date(d.getTime()+Pt),p=s.dateToX(h)-s.dateToX(d);if(p<=0)return;const r=c.currentX-c.startX;let l;c.type==="move"||c.type==="resize-left"?l=u.x+r:l=u.x+u.width+r;const f=Math.round(l/p)*p,{ctx:T}=this;T.save(),T.strokeStyle=a.barSelectedBorder||"#3b82f6",T.lineWidth=1,T.setLineDash([4,3]),T.globalAlpha=.85,T.beginPath(),T.moveTo(f+.5,o),T.lineTo(f+.5,o+i),T.stroke(),T.restore()}renderTaskBars(t,n,s,o,i,a,c,u){const{ctx:d}=this,h=o.barBorderRadius,p=t.dragState,r=p?p.currentX-p.startX:0,l=4;for(const f of n){let T=f.x;const S=f.barY-a+c;let g=f.width;const y=f.barHeight;if(S+y<c||S>c+u)continue;const v=p&&p.taskId===f.taskId;if(v){if(p.type==="move")T+=r;else if(p.type==="resize-left"){const k=T+r,D=g-r;D>=l&&(T=k,g=D)}else if(p.type==="resize-right"){const k=g+r;k>=l&&(g=k)}}if(f.isMilestone){this.renderMilestone(T,S,y,f.color,o,t.selectedIds.has(f.taskId));continue}const m=t.tasks.get(f.taskId),b=m&&m.status!=="group-header"&&m.style?m.style:null,w=b?this.resolveFillOpacity(b):1;if(w<1?(d.save(),d.globalAlpha=w,this.fillRoundedRect(T,S,g,y,h,f.color),d.restore()):this.fillRoundedRect(T,S,g,y,h,f.color),s.showProgress&&f.progressWidth>0){const k=this.darkenColor(f.color,.2);d.save(),d.beginPath(),this.roundedRectPath(T,S,g,y,h),d.clip(),d.fillStyle=k,d.fillRect(T,S,f.progressWidth,y),d.restore()}t.selectedIds.has(f.taskId)&&this.strokeRoundedRect(T,S,g,y,h,o.barSelectedBorder,pn),v&&this.strokeRoundedRect(T,S,g,y,h,o.barSelectedBorder,pn),b&&b.borderStyle&&b.borderStyle!=="none"&&this.renderDecoratorBorder(b,T,S,g,y,h,f.color),this.renderBarLabel(f,T,S,g,y,o),b&&b.badge&&b.badge.text&&this.renderDecoratorBadge(b.badge,T,S,g,y,f.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,c){const{ctx:u}=this,d=t.borderWidth??2,h=t.borderColor??this.darkenColor(c,.3),p=t.borderStyle??"solid";let r;switch(p){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(u.save(),u.setLineDash(r),u.strokeStyle=h,u.lineWidth=d,this.roundedRectPath(n,s,o,i,a),u.stroke(),p==="double"){const l=d+1,f=Math.max(0,a-l);u.lineWidth=d,this.roundedRectPath(n+l,s+l,Math.max(0,o-l*2),Math.max(0,i-l*2),f),u.stroke()}u.restore()}renderDecoratorBadge(t,n,s,o,i,a,c){const{ctx:u}=this,d=t.text,h=t.placement??"end",p=Math.max(14,i*.65),r=6;u.save();const l=`${Math.round(c.fontSize*.85)}px ${c.fontFamily}`;u.font=l,u.textBaseline="middle";const T=u.measureText(d).width+r*2,S=s+(i-p)/2,g=h==="start"?n+2:n+o-T-2;u.shadowColor="rgba(0,0,0,0.25)",u.shadowBlur=3,u.shadowOffsetY=1;const y=t.color??"#ffffff";u.fillStyle=y,this.roundedRectPath(g,S,T,p,p/2),u.fill(),u.shadowColor="transparent",u.shadowBlur=0,u.shadowOffsetY=0,u.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),u.textAlign="center",u.fillText(d,g+T/2,S+p/2),u.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:c}=this,u=(s-Pi*2)/2,d=n+s/2;c.save(),c.beginPath(),c.moveTo(t,d-u),c.lineTo(t+u,d),c.lineTo(t,d+u),c.lineTo(t-u,d),c.closePath(),c.fillStyle=o,c.fill(),a&&(c.strokeStyle=i.barSelectedBorder,c.lineWidth=pn,c.stroke()),c.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:c}=this;if(!t.label)return;c.save();const u=`${a.fontSize}px ${a.fontFamily}`;c.font=u,c.textBaseline="middle";const d=c.measureText(t.label).width,h=s+i/2;d+gs*2<=o?(c.beginPath(),c.rect(n,s,o,i),c.clip(),c.fillStyle=t.textColor,c.textAlign="left",c.fillText(t.label,n+gs,h)):(c.fillStyle=a.gridTextColor,c.textAlign="left",c.fillText(t.label,n+o+$i,h)),c.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=Ri,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,c=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,c,s.timelineHeaderBg);const d=u.length||2,h=c/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let l=0;l<u.length;l++){const f=u[l],T=l*h;for(const S of f){const g=S.x-o,y=S.width;if(g+y<0||g>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=us;const v=this.snapToPixelRaw(g+y);i.moveTo(v,T),i.lineTo(v,T+h),i.stroke(),i.save(),i.beginPath(),i.rect(g,T,y,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=l===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(S.label,g+y/2,T+h/2),i.restore()}}const r=this.snapToPixelRaw(c);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=us,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,c=Math.min(i,s/2,o/2);a.moveTo(t+c,n),a.lineTo(t+s-c,n),a.arcTo(t+s,n,t+s,n+c,c),a.lineTo(t+s,n+o-c),a.arcTo(t+s,n+o,t+s-c,n+o,c),a.lineTo(t+c,n+o),a.arcTo(t,n+o,t,n+o-c,c),a.lineTo(t,n+c),a.arcTo(t,n,t+c,n,c),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:c}=this;c.beginPath(),this.roundedRectPath(t,n,s,o,i),c.fillStyle=a,c.fill()}strokeRoundedRect(t,n,s,o,i,a,c){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=c,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const c=u=>u.toString(16).padStart(2,"0");return`#${c(s)}${c(o)}${c(i)}`}}const hs="ng-tree-grid-styles";function Ni(e,t){const n=e.querySelector(`#${hs}`);n&&n.remove();const s=document.createElement("style");s.id=hs,s.textContent=`
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
    /*  0.185.4 — widened to 8px + faint default indicator so the grip is
     *  discoverable without a pixel-perfect hover. The th element has
     *  overflow:hidden so the handle stays within column bounds; a faint
     *  vertical line at right:2px makes the grip visible without hover. */

    .ng-resize-handle {
      position: absolute;
      top: 20%;
      right: 0;
      width: 8px;
      height: 60%;
      cursor: col-resize;
      z-index: 3;
      opacity: 0.35;
      transition: opacity 120ms ease, background 120ms ease;
    }

    .ng-resize-handle::before {
      content: '';
      position: absolute;
      top: 0;
      right: 2px;
      width: 2px;
      height: 100%;
      background: ${t.gridBorderColor};
      border-radius: 1px;
    }

    .ng-resize-handle:hover {
      background: ${t.selectionColor};
      opacity: 1;
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
  `,e.insertBefore(s,e.firstChild)}function Oi(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function $t(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class Hi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;Ni(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const c=Oi(n),u=c.map(d=>d.task.id);this.updateRows(c,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const c=o.children[a],u=c.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),c.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,c)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,u.appendChild(d);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,c),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,c=d=>{const h=d.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,l=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),l[n]&&(l[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",c),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",c),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),c=new Map;for(const d of t)c.set(d.task.id,d);for(const[d,h]of this.rows)a.has(d)||(h.remove(),this.rows.delete(d));let u=null;for(let d=0;d<t.length;d++){const h=t[d],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,d,s):(r=this.createRow(h,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,c=document.createElement("tr");c.className="ng-grid-row",c.setAttribute("data-task-id",t.task.id),c.style.height=`${a}px`,t.task.status==="group-header"?(c.classList.add("ng-group-row"),t.task.groupBg&&(c.style.background=t.task.groupBg)):n%2===1&&c.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&c.classList.add("ng-row-selected");for(const u of i){const d=this.createCell(t,u,s);c.appendChild(d)}return c}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const d=document.createElement("span");d.className="ng-expand-icon",t.expanded&&d.classList.add("ng-expanded"),d.innerHTML="&#9654;",d.setAttribute("data-expand",t.task.id),o.appendChild(d)}else{const d=document.createElement("span");d.className="ng-expand-spacer",o.appendChild(d)}if(t.children.length===0&&!t.task.groupBg){const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",o.appendChild(d)}const c=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(c&&t.children.length===0){const d=document.createElement("span");d.className="ng-status-dot",d.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${c};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(d)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=$t(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=$t(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const c=t.querySelectorAll("td.ng-grid-cell");for(let d=0;d<a.length;d++){const h=a[d],p=c[d];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const l=`${n.depth*20+8}px`;p.style.paddingLeft!==l&&(p.style.paddingLeft=l);const f=p.querySelector(".ng-expand-icon"),T=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(f)n.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{T&&T.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(f){f.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const S=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!S){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const b=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");b?p.insertBefore(m,b):p.appendChild(m)}}else S&&S.remove();const g=p.querySelector(".ng-status-dot"),y=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(y&&n.children.length===0)if(g)g.style.background=y;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${y};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const b=p.querySelector(".ng-grid-cell-text");b?p.insertBefore(m,b):p.appendChild(m)}else g&&g.remove();const v=p.querySelector(".ng-grid-cell-text");if(v){const m=$t(n.task,h);v.textContent!==m&&(v.textContent=m)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const l=document.createElement("span");l.className="ng-drag-handle",l.innerHTML="&#9776;",p.appendChild(l)}}else r&&(p.textContent="")}else{const r=$t(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class xi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class fs{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],c=this.testLayout(t,n,a,o);if(c!==null)return{type:c,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:c,barHeight:u}=s;if(t<i||t>i+c||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+c-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const ps=864e5;function _t(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/ps)}function Tt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Oe(e,t){const n=Tt(e),s=new Date(n.getTime()+t*ps),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function ms(e,t,n){return Math.max(t,Math.min(n,e))}const Bi=3,Fi=300;class Ui{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new fs,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,c=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:c}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,c=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:c}}handlePointerMove(t){if(this.panning){t.preventDefault();const c=t.clientX-this.panStartClientX,u=t.clientY-this.panStartClientY,d=this.options.scrollManager;if(d){const h=Math.max(0,this.panOrigScrollX-c),p=Math.max(0,this.panOrigScrollY-u);d.setScrollPosition(h,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const c=o.tasks.get(a.taskId);if(c){const u=this.canvas.getBoundingClientRect();this.options.onHover(c,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const u=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=u.x,this.panOrigScrollY=u.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const c=o.tasks.get(a.taskId);if(c){this.dragOriginalStartDate=c.startDate,this.dragOriginalEndDate=c.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const u=Yi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:c.startDate,originalEndDate:c.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=_t(i,o);let c="";if(this.dragHit.type==="bar"){const l=Oe(this.dragOriginalStartDate,a),f=Oe(this.dragOriginalEndDate,a);c=`${l} → ${f}`}else if(this.dragHit.type==="bar-left-edge")c=`Start → ${Oe(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")c=`End → ${Oe(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const l=this.dragHit.layout,{canvasX:f}=this.toCanvasCoords(t),T=f-l.x;c=`${Math.round(ms(T/l.width,0,1)*100)}%`}if(!c)return;if(!this.gestureLabelEl){const l=document.createElement("div");l.setAttribute("data-nga-gesture-label","1"),l.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(l),this.gestureLabelEl=l,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=c;const u=12,d=window.innerWidth||document.documentElement.clientWidth,h=this.gestureLabelEl.offsetWidth,p=Math.min(t.clientX+u,d-h-4),r=t.clientY+u;this.gestureLabelEl.style.left=`${p}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,c=this.options.getState().tasks.get(i.taskId);o<Bi?(this.options.dispatch({type:"DRAG_END"}),c&&this.handleClick(c)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Fi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var u,d,h,p,r,l,f,T,S,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,c=t.clientX-this.dragStartX;switch(a){case"bar":{const y=t.clientY-this.dragStartY,v=Math.abs(c),m=Math.abs(y),b=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),w=m>v*1.5&&m>12;if(b&&w){const C=this.options.getLayouts(),A=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),M=C.find($=>$.rowIndex===A),L=M?M.taskId:null;let N=null;const R=C.slice().sort(($,_)=>$.rowIndex-_.rowIndex);for(const $ of R){if($.rowIndex>A)break;const _=$.taskId;typeof _=="string"&&_.indexOf("__bucket_header__")===0&&(N=_.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",A,"target=",L,"bucket=",N)}catch{}(d=(u=this.options).onBarReorderDrag)==null||d.call(u,s,L,A,N);break}const k=_t(c,o),D=Oe(this.dragOriginalStartDate,k),E=Oe(this.dragOriginalEndDate,k);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:D,endDate:E});try{console.log("[NG engine] drag commit move",s.id,D,E,"hasCb=",!!this.options.onTaskMove)}catch{}(p=(h=this.options).onTaskMove)==null||p.call(h,s,D,E);break}case"bar-left-edge":{const y=_t(c,o),v=Oe(this.dragOriginalStartDate,y),m=Tt(this.dragOriginalEndDate),w=Tt(v).getTime()>=m.getTime()?Oe(this.dragOriginalEndDate,-1):v;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:w,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,w,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(l=(r=this.options).onTaskResize)==null||l.call(r,s,w,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=_t(c,o),v=Oe(this.dragOriginalEndDate,y),m=Tt(this.dragOriginalStartDate),w=Tt(v).getTime()<=m.getTime()?Oe(this.dragOriginalStartDate,1):v;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:w});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,w,"hasCb=",!!this.options.onTaskResize)}catch{}(T=(f=this.options).onTaskResize)==null||T.call(f,s,this.dragOriginalStartDate,w);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:v}=this.toCanvasCoords(t),m=v-y.x,b=ms(m/y.width,0,1),w=Math.round(b*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:w}}),(g=(S=this.options).onTaskProgressChange)==null||g.call(S,s,w);break}}this.options.dispatch({type:"DRAG_END"})}}function Yi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const He=12,vt=6,Nt=4,Wi=3;class ys{render(t,n,s,o,i,a,c){const{dependencies:u}=n;if(u.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,c,h,p-c),t.clip(),t.translate(-i,0);for(const r of u.values()){const l=d.get(r.source),f=d.get(r.target);if(!l||!f)continue;const T=r.type||"FS",{sourceX:S,sourceY:g,targetX:y,targetY:v}=this.getConnectionPoints(T,l,f,a,c);this.drawRoutedPath(t,T,S,g,y,v,o),this.drawArrowhead(t,T,y,v,o),this.drawConnectionDot(t,S,g,o),this.drawConnectionDot(t,y,v,o)}t.restore()}hitTest(t,n,s,o,i,a,c=8){const{dependencies:u}=s;if(u.size===0||n<a)return null;const d=new Map;for(const p of o)d.set(p.taskId,p);let h=null;for(const p of u.values()){const r=d.get(p.source),l=d.get(p.target);if(!r||!l)continue;const f=p.type||"FS",{sourceX:T,sourceY:S,targetX:g,targetY:y}=this.getConnectionPoints(f,r,l,i,a),v=t-g,m=n-y,b=Math.sqrt(v*v+m*m);if(b<=c+vt){(!h||b<h.dist)&&(h={depId:p.id,dist:b});continue}const w=f==="FS"||f==="SS"?g-He:g+He,k=Math.min(w,g),D=Math.max(w,g);if(t>=k-c&&t<=D+c&&Math.abs(n-y)<=c){const M=Math.abs(n-y);(!h||M<h.dist)&&(h={depId:p.id,dist:M})}const E=f==="FS"||f==="FF"?T+He:T-He,C=Math.min(T,E),A=Math.max(T,E);if(t>=C-c&&t<=A+c&&Math.abs(n-S)<=c){const M=Math.abs(n-S);(!h||M<h.dist)&&(h={depId:p.id,dist:M})}}return(h==null?void 0:h.depId)??null}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,c=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:c};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:c};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:c};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:c}}}drawRoutedPath(t,n,s,o,i,a,c){t.beginPath(),t.strokeStyle=c.dependencyColor,t.lineWidth=c.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",d=n==="FS"||n==="SS",h=u?s+He:s-He,p=d?i-He:i+He;if(u?d?p>=h:i+He>=h:d?i-He<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const l=(o+a)/2;t.lineTo(h,o),t.lineTo(h,l),t.lineTo(p,l),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-vt,o-Nt),t.lineTo(s-vt,o+Nt)):(t.moveTo(s,o),t.lineTo(s+vt,o-Nt),t.lineTo(s+vt,o+Nt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Wi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Ot=12,Xi=100,zi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Gi=`
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
.ng-tooltip-id {
  margin-top: 2px;
  font-weight: 400;
  font-size: 10px;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  color: #9ca3af;
  user-select: all;
  word-break: break-all;
}
.ng-tooltip-body {
  padding: 6px 10px;
}
.ng-tooltip-divider {
  border-top: 1px solid #f3f4f6;
}
.ng-tooltip-row {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 2px 0;
}
.ng-tooltip-label {
  color: #6b7280;
}
.ng-tooltip-value {
  color: #111827;
  font-weight: 500;
}
.ng-tooltip-value.ng-tooltip-over {
  color: #dc2626;
}
`;function at(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function bs(e){const t=e.split("-");if(t.length!==3)return at(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?at(e):`${zi[n]} ${s}`}function Me(e,t,n){const s=n?` ${n}`:"";return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${at(e)}</span><span class="ng-tooltip-value${s}">${at(t)}</span></div>`}function Ht(e){return Number.isInteger(e)?String(e):e.toFixed(1)}function Ts(e,...t){var s;const n=e;for(const o of t){const i=n[o];if(typeof i=="number"&&!Number.isNaN(i))return i;const a=(s=e.metadata)==null?void 0:s[o];if(typeof a=="number"&&!Number.isNaN(a))return a}}function Vi(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.max(1,Math.round((s-n)/864e5)+1)}function vs(e,...t){var n;for(const s of t){const o=(n=e.metadata)==null?void 0:n[s];if(typeof o=="string"&&o.length>0)return o}}function Ss(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.round((s-n)/864e5)}function ws(e){return e===0?"on time":e>0?`+${e}d`:`−${Math.abs(e)}d`}function Ki(e,t,n){const s=Math.round((e.progress??0)*100),o=Ts(e,"estimatedHours","estimateHours","hours"),i=Ts(e,"loggedHours","actualHours");let a="";e.status&&(a+=Me("Status",e.status)),e.priority&&(a+=Me("Priority",e.priority)),a+=Me("Assignee",e.assignee||"Unassigned");const c=Vi(e.startDate,e.endDate),u=`${bs(e.startDate)} → ${bs(e.endDate)}`;a+=Me("Dates",c?`${u} (${c}d)`:u),s>0&&(a+=Me("Progress",`${s}%`));let d="";if(o!=null&&(d+=Me("Estimate",`${Ht(o)}h`)),i!=null&&(d+=Me("Logged",`${Ht(i)}h`)),o!=null&&i!=null&&o>0){const v=Math.round(i/o*100),m=i>o,b=o-i,w=m?`${v}% (${Ht(i-o)}h over)`:`${v}% (${Ht(b)}h left)`;d+=Me("Used",w,m?"ng-tooltip-over":void 0)}const h=n==null?void 0:n.depSummary;h&&(h.blocks>0||h.blockedBy>0)&&(h.blockedBy>0&&(a+=Me("Blocked by",`${h.blockedBy} task${h.blockedBy===1?"":"s"}`)),h.blocks>0&&(a+=Me("Blocks",`${h.blocks} task${h.blocks===1?"":"s"}`)));let p="";const r=vs(e,"baselineStart","baselineStartDate"),l=vs(e,"baselineEnd","baselineEndDate");if(r){const v=Ss(r,e.startDate);v!=null&&(p+=Me("Start vs plan",ws(v),v>0?"ng-tooltip-over":void 0))}if(l){const v=Ss(l,e.endDate);v!=null&&(p+=Me("Finish vs plan",ws(v),v>0?"ng-tooltip-over":void 0))}let f="";if(Array.isArray(e.tooltipRows))for(const v of e.tooltipRows)!v||typeof v.label!="string"||typeof v.value!="string"||(f+=Me(v.label,v.value,v.emphasis?"ng-tooltip-over":void 0));const T=`<div class="ng-tooltip-id" title="Work item ID">${at(e.id)}</div>`,S=e.title||e.name,g=`<div class="ng-tooltip-header" style="border-left: 3px solid ${at(t)}"><span class="ng-tooltip-name">${at(S)}</span>${T}</div>`,y=v=>v?`<div class="ng-tooltip-divider"></div><div class="ng-tooltip-body">${v}</div>`:"";return`${g}<div class="ng-tooltip-body">${a}</div>${y(d)}${y(p)}${y(f)}`}class ks{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Gi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o,i){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const h=this.customRenderer(t);typeof h=="string"?this.tooltipEl.innerHTML=h:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(h))}else this.tooltipEl.innerHTML=Ki(t,o,i);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const a=this.tooltipEl.getBoundingClientRect(),c=this.container.getBoundingClientRect();let u=n+Ot,d=s+Ot;u+a.width>c.width&&(u=n-Ot-a.width),d+a.height>c.height&&(d=s-Ot-a.height),u=Math.max(0,u),d=Math.max(0,d),this.tooltipEl.style.left=`${u}px`,this.tooltipEl.style.top=`${d}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Xi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const mn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},Ds={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},ji=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function Es(e){const t=qi(e.theme);return{columns:e.columns??ji,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function qi(e){return!e||e==="light"?{...mn}:e==="dark"?{...Ds}:{...mn,...e}}function ut(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const Cs="nimbus-gantt-root-styles";function Zi(){if(typeof document>"u"||document.getElementById(Cs))return;const e=document.createElement("style");e.id=Cs,e.textContent=`
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
  `,document.head.appendChild(e)}class Ji{constructor(t,n){this.lastRenderedZoom=null,this.renderRetries=0,this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.replayProvider=null,this.agent={getSnapshot:()=>{const h=this.getDisplayState();return{cursorDate:h.timeCursorDate?h.timeCursorDate.toISOString():null,zoomLevel:h.zoomLevel,tasks:Array.from(h.tasks.values()),dependencies:Array.from(h.dependencies.values()),selectedIds:Array.from(h.selectedIds),expandedIds:Array.from(h.expandedIds),flatVisibleIds:h.flatVisibleIds.slice()}},updateTask:(h,p)=>{this.store.dispatch({type:"UPDATE_TASK",taskId:h,changes:p})},addTask:h=>{this.store.dispatch({type:"ADD_TASK",task:h})},removeTask:h=>{this.store.dispatch({type:"REMOVE_TASK",taskId:h})},moveTask:(h,p,r)=>{this.store.dispatch({type:"TASK_MOVE",taskId:h,startDate:p,endDate:r})},addDependency:h=>{this.store.dispatch({type:"ADD_DEPENDENCY",dependency:h})},removeDependency:h=>{this.store.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:h})},setSelection:h=>{this.store.dispatch({type:"DESELECT_ALL"});for(const p of h)this.store.dispatch({type:"SELECT_TASK",taskId:p,multi:!0})},setZoom:h=>{this.store.dispatch({type:"SET_ZOOM",level:h})},scrubTo:h=>{this.store.dispatch({type:"SET_TIME_CURSOR",date:h?new Date(h):null})},history:()=>{const h=this.history;return h?{entries:h.entries().map(p=>({ts:p.ts,wallTs:p.wallTs,actionType:p.action.type,source:p.source,actor:p.actor})),annotations:h.annotations().slice(),lastWallTs:h.lastWallTs()}:null},appendAnnotation:(h,p,r)=>{const l=this.history;return l?(l.appendAnnotation({kind:h,taskId:p,payload:r}),!0):!1}},this.container=t,this.config=Es(n),Zi(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:c}=Ue(s,i),u=yt(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:c,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new is,this.store=new gn(d),this.layoutEngine=new ds,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new _i(this.timelinePanel),this.treeGrid=new Hi(this.gridPanel),this.scrollManager=new xi(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new ys,this.tooltipManager=new ks(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new Ui(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,l,f)=>{var T;p?this.tooltipManager.show(p,r,l,f,{depSummary:this.computeDepSummary(p.id)}):this.tooltipManager.hide();try{(T=n.onHover)==null||T.call(n,p,r,l,f)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){ut("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){ut("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(ut("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const u=os(this.store.getState(),t);for(const d of u)this.store.dispatch(d);ut("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=os(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,c=0;for(const u of n){let d=null;if(u.type==="UPDATE_TASK"?d=u.taskId:u.type==="ADD_TASK"?d=u.task.id:u.type==="REMOVE_TASK"&&(d=u.taskId),d&&typeof s=="number"){const h=this.lastAppliedTs.get(d);if(h!==void 0&&s<h){c++;continue}}this.store.dispatch(u),d&&typeof s=="number"&&this.lastAppliedTs.set(d,s),u.type==="UPDATE_TASK"?o++:u.type==="ADD_TASK"?i++:u.type==="REMOVE_TASK"&&a++}c>0&&ut("remote:dropped-stale",{kind:t.kind,count:c}),o+i+a>0&&ut("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getDisplayState(){const t=this.store.getState(),n=t.timeCursorDate;return!n||!this.replayProvider?t:this.replayProvider.snapshotAt(n)??t}registerReplayProvider(t){return this.replayProvider=t,()=>{this.replayProvider===t&&(this.replayProvider=null)}}setTimeCursor(t){this.store.dispatch({type:"SET_TIME_CURSOR",date:t})}getTimeCursor(){return this.store.getState().timeCursorDate??null}getState(){return this.store.getState()}computeDepSummary(t){let n=0,s=0;return this.store.getState().dependencies.forEach(i=>{i.source===t?n++:i.target===t&&s++}),{blocks:n,blockedBy:s}}hitTestAt(t,n){const s=this.rootEl.getBoundingClientRect();if(!(t>=s.left&&t<=s.right&&n>=s.top&&n<=s.bottom))return{zone:"outside"};const i=this.getDisplayState(),{config:a,scrollX:c,scrollY:u,flatVisibleIds:d,tasks:h}=i,{headerHeight:p,rowHeight:r}=a,l=this.gridPanel.getBoundingClientRect(),f=this.timelinePanel.getBoundingClientRect(),T=t>=l.left&&t<=l.right&&n>=l.top&&n<=l.bottom&&l.width>0,S=t>=f.left&&t<=f.right&&n>=f.top&&n<=f.bottom;if(S&&n-f.top<p){const w=t-f.left+c;let k;try{k=this.timeScale.xToDate(w)}catch{k=new Date}const D=n-f.top,E=(()=>{try{return this.timeScale.getHeaderRows()}catch{return[]}})(),C=Math.max(1,E.length),A=p/C,M=Math.min(C-1,Math.max(0,Math.floor(D/A))),L=Qi(i.zoomLevel,C,M);return{zone:"date-header",date:k,level:L}}const g=p,y=(S?n-f.top:n-l.top)-g;if(y<0)return{zone:"outside"};const v=Math.floor((y+u)/r),b=(w=>w<0||w>=d.length?null:h.get(d[w])??null)(v);if(S&&b){if(b.status==="group-header")return{zone:"bucket-header",bucketTask:b,bucketId:b.groupId??null,rowIndex:v};const w=this.layouts.find(k=>k.taskId===b.id)??null;if(w){const k=t-f.left+c,D=6;if(w.isMilestone){const E=w.barHeight/2;if(Math.abs(k-w.x)<=E)return{zone:"bar",task:b,rowIndex:v,barType:"body"}}else if(k>=w.x-D&&k<=w.x+w.width+D){const A=k<=w.x+6?"left-edge":k>=w.x+w.width-6?"right-edge":"body";return{zone:"bar",task:b,rowIndex:v,barType:A}}}}if(T&&b)return b.status==="group-header"?{zone:"bucket-header",bucketTask:b,bucketId:b.groupId??null,rowIndex:v}:{zone:"row-label",task:b,rowIndex:v};if(S){const w=t-f.left+c,k=n-f.top;try{const D=this.dependencyRenderer.hitTest(w,k,i,this.layouts,u,p);if(D)return{zone:"dependency",depId:D}}catch{}}if(v>=d.length){let w;try{w=this.timeScale.xToDate(t-f.left+c)}catch{w=new Date}return{zone:"below-rows",date:w}}if(S){let w;try{w=this.timeScale.xToDate(t-f.left+c)}catch{w=new Date}const k=ea(i,v);return{zone:"canvas-empty",date:w,rowIndex:v,nearestTask:b,bucketId:k}}return{zone:"outside"}}capabilities(){const t=this;return{version:"0.204.0",pushRemoteEvent:typeof this.pushRemoteEvent=="function",timeCursor:!0,history:!!t.history,replayProvider:!!this.replayProvider,pluginsInstalled:this.plugins.map(n=>n.name).join(",")}}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,c=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(c);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}emit(t,...n){this.eventBus.emit(t,...n)}on(t,n){return this.eventBus.on(t,n)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.getDisplayState();if((this.timelinePanel.clientWidth<=0||this.timelinePanel.clientHeight<=0)&&this.renderRetries<90){this.renderRetries++,typeof requestAnimationFrame=="function"?requestAnimationFrame(()=>{this.destroyed||this.render()}):setTimeout(()=>{this.destroyed||this.render()},16);return}this.renderRetries=0;const n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;this.canvasRenderer.resize(i,a);const c=Math.max(0,s-i),u=Math.max(0,o-a);let d=t.scrollX;if(this.lastRenderedZoom!==null&&this.lastRenderedZoom!==t.zoomLevel){const l=this.timeScale.dateToX(new Date);Number.isFinite(l)&&(d=l-i/2)}this.lastRenderedZoom=t.zoomLevel;const h=Math.min(Math.max(0,d),c),p=Math.min(Math.max(0,t.scrollY),u);let r=t;if((h!==t.scrollX||p!==t.scrollY)&&(r={...t,scrollX:h,scrollY:p},this.scrollManager.setScrollPosition(h,p),this.store.dispatch({type:"SET_SCROLL",x:h,y:p})),this.canvasRenderer.render(r,this.layouts,this.timeScale),r.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const f=l.getContext("2d");f&&this.dependencyRenderer.render(f,r,this.layouts,r.config.theme,r.scrollX,r.scrollY,r.config.headerHeight)}}this.treeGrid.render(r,r.tree),this.treeGrid.setScrollY(r.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const f=this.timelinePanel.querySelector("canvas");if(f){const T=f.getContext("2d");T&&l.renderCanvas(T,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new ls(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){const t=this,n={getState:()=>this.store.getState(),dispatch:s=>this.store.dispatch(s),on:(s,o)=>this.eventBus.on(s,o),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:s=>this.timeScale.dateToX(s),xToDate:s=>this.timeScale.xToDate(s),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const s=this.store.getState(),{tree:o,flatIds:i}=Ue(s.tasks,s.expandedIds);s.tree=o,s.flatVisibleIds.length=0;for(const a of i)s.flatVisibleIds.push(a)}};return n.__gantt=t,n}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new gn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function Qi(e,t,n){if(t===2){if(e==="day")return n===0?"month":"day";if(e==="week")return n===0?"month":"week";if(e==="month")return n===0?"year":"month";if(e==="quarter")return n===0?"year":"quarter"}return e}function ea(e,t){if(t<0||t>=e.flatVisibleIds.length)return null;let n=e.tasks.get(e.flatVisibleIds[t]);for(;n;){if(n.status==="group-header")return n.groupId??n.id;if(!n.parentId)break;n=e.tasks.get(n.parentId)}const s=e.tasks.get(e.flatVisibleIds[t]);return(s==null?void 0:s.groupId)??null}function Is(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function Ms(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const c of Is(a)){let u=s.get(c);u||(u=[],s.set(c,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),c=s.get(a);if(c)for(const u of c)o.has(u)||(o.add(u),i.push(u))}return o}function ta(e,t){const n=Ms(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const na=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function yn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function sa(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,c=null,u=null;function d(l){s.push(l),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const l=yn(n.getState()),f=s.pop();o.push(l),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const l=yn(n.getState()),f=o.pop();s.push(l),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(l){(l.ctrlKey||l.metaKey)&&(l.key==="z"||l.key==="Z")&&(l.shiftKey?(l.preventDefault(),p()):(l.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(l){n=l,u=l.on("render",()=>{if(c)return;const f=document.querySelector(".nimbus-gantt");f&&(c=f.parentElement??f,c.getAttribute("tabindex")||c.setAttribute("tabindex","-1"),a=r,c.addEventListener("keydown",a))})},middleware(l,f){if(i){f(l);return}if(na.has(l.type)&&n){const T=yn(n.getState());d(T),o=[]}f(l)},destroy(){a&&c&&c.removeEventListener("keydown",a),u&&u(),n=null,c=null,a=null,s=[],o=[]}}}const St=["day","week","month","quarter"];function oa(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function bn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function ia(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:c}=a,u=oa(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),c.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:c[0]});else{const d=c.indexOf(u);d>0&&e.dispatch({type:"SELECT_TASK",taskId:c[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),c.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:c[0]});else{const d=c.indexOf(u);d<c.length-1&&e.dispatch({type:"SELECT_TASK",taskId:c[d+1]})}break}case"ArrowRight":{if(u)if(bn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(u)if(bn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!u)return;i.preventDefault();const d=a.tasks.get(u);if(d&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),c.length>0&&e.dispatch({type:"SELECT_TASK",taskId:c[0]});break}case"End":{if(i.preventDefault(),c.length>0){const d=c[c.length-1],h=(c.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=St.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:St[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=St.indexOf(a.zoomLevel);d<St.length-1&&e.dispatch({type:"SET_ZOOM",level:St[d+1]});break}case" ":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;bn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const As="#D4A017",aa="rgba(212, 160, 23, 0.25)",ra=[6,4],la=1,ca=2,da=4,Rs=8,Ls=10,Ps=16,ua=6;function ga(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:c}=o,u=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const l=r.x,f=r.barY-a,T=r.barHeight,S=f+T/2,g=r.color===c.barDefaultColor?As:r.color||As;t.save(),t.beginPath(),t.strokeStyle=aa,t.lineWidth=la,t.setLineDash(ra),t.moveTo(l,h),t.lineTo(l,h+p),t.stroke(),t.setLineDash([]),t.restore();const y=(T-ca*2)/2;t.save(),t.beginPath(),t.moveTo(l,S-y),t.lineTo(l+y,S),t.lineTo(l,S+y),t.lineTo(l-y,S),t.closePath(),t.fillStyle=g,t.fill(),t.strokeStyle=$s(g,.25),t.lineWidth=1,t.stroke(),t.restore();const v=l+y+da,m=S-Ps/2;if(t.save(),t.beginPath(),t.strokeStyle=$s(g,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+Ps),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+Rs,m+Ls/2),t.lineTo(v,m+Ls),t.closePath(),t.fillStyle=g,t.fill(),t.restore(),r.label){const b=v+Rs+ua,w=S;t.save(),t.font=`600 ${c.fontSize}px ${c.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=c.gridTextColor,t.fillText(r.label,b,w),t.restore()}}t.restore()},destroy(){e=null}}}function $s(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const ha="rgba(100, 116, 139, 0.12)",fa="rgba(100, 116, 139, 0.25)",_s="#334155",pa="rgba(100, 116, 139, 0.2)",ma="#475569",ya=8,ba=6,Ta=2,qe=5,va=12,Sa=28,wa=8;function ka(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,c=null;function u(h){const p=new Map,r=[];for(const l of h.flatVisibleIds){const f=h.tasks.get(l);if(f)if(f.groupId){let T=p.get(f.groupId);T||(T={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,T)),T.taskIds.push(l)}else r.push(l)}n=Array.from(p.values()),o=[],s=new Map;for(const l of r)o.push(l);for(const l of n){const f=o.length,T=`__group_header__${l.groupId}`;if(o.push(T),s.set(f,l),!l.collapsed)for(const S of l.taskIds)o.push(S)}}function d(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,c=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const l=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const T=f.getBoundingClientRect(),S=r.clientY-T.top,g=l.config.headerHeight;if(S<g)return;const y=S-g+l.scrollY,v=Math.floor(y/l.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),d(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let l=!1;for(const f of r.tasks.values())if(f.groupId){l=!0;break}if(!l){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const f=new Set;for(const T of n)if(T.collapsed)for(const S of T.taskIds)f.add(S);if(f.size>0){const T=r.flatVisibleIds.filter(S=>!f.has(S));if(T.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const S of T)r.flatVisibleIds.push(S)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:l,scrollX:f,scrollY:T}=p,{theme:S}=l,g=l.headerHeight,y=l.rowHeight,v=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-g;h.save(),h.beginPath(),h.rect(0,g,v,m),h.clip();let b=0;const w=[];for(const k of p.flatVisibleIds){const D=p.tasks.get(k);D&&!D.groupId&&w.push(k)}b=w.length;for(const k of n){const D=g+b*y-T;if(D+y>=g&&D<g+m){h.fillStyle=ha,h.fillRect(0,D,v,y),h.beginPath(),h.strokeStyle=fa,h.lineWidth=1,h.moveTo(0,Math.round(D+y)+.5),h.lineTo(v,Math.round(D+y)+.5),h.stroke();const E=va,C=D+y/2;h.save(),h.beginPath(),h.fillStyle=_s,k.collapsed?(h.moveTo(E,C-qe),h.lineTo(E+qe,C),h.lineTo(E,C+qe)):(h.moveTo(E-qe/2,C-qe/2),h.lineTo(E+qe/2,C-qe/2),h.lineTo(E,C+qe/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${S.fontSize}px ${S.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=_s;const A=Sa,M=D+y/2;h.fillText(k.groupName,A,M);const L=h.measureText(k.groupName).width;h.restore();const N=`${k.taskIds.length}`;h.save(),h.font=`${S.fontSize-1}px ${S.fontFamily}`;const $=h.measureText(N).width+ba*2,_=S.fontSize+Ta*2,U=A+L+wa,Y=M-_/2;h.beginPath();const K=ya;h.moveTo(U+K,Y),h.lineTo(U+$-K,Y),h.arcTo(U+$,Y,U+$,Y+K,K),h.lineTo(U+$,Y+_-K),h.arcTo(U+$,Y+_,U+$-K,Y+_,K),h.lineTo(U+K,Y+_),h.arcTo(U,Y+_,U,Y+_-K,K),h.lineTo(U,Y+K),h.arcTo(U,Y,U+K,Y,K),h.closePath(),h.fillStyle=pa,h.fill(),h.fillStyle=ma,h.textBaseline="middle",h.textAlign="center",h.fillText(N,U+$/2,M),h.restore()}b+=1,k.collapsed||(b+=k.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),c&&c(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const gt="__bucket_header__";function Ns(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Da(e){return e.groupId??null}function Ea(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function Ca(e){const t=[...e.buckets].sort((r,l)=>r.order-l.order),n=new Map;t.forEach((r,l)=>n.set(r.id,l));const s=e.getBucket??Da,o=e.getBucketProgress??Ea,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,c=[],u=null;function d(r,l){c=t.map(f=>({config:f,taskIds:[],allTaskIds:[],collapsed:i.has(f.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const f of l){const T=r.tasks.get(f);if(!T)continue;const S=s(T);if(!S)continue;const g=n.get(S);g!==void 0&&c[g].taskIds.push(f)}for(const[f,T]of r.tasks){if(f.startsWith(gt))continue;const S=s(T);if(!S)continue;const g=n.get(S);g!==void 0&&c[g].allTaskIds.push(f)}for(const f of c){if(f.allTaskIds.length===0){f.progress=0,f.startDate=null,f.endDate=null,f.totalHours=0,f.totalLogged=0;continue}const T=[];let S=1/0,g=-1/0,y=0,v=0;for(const m of f.allTaskIds){const b=r.tasks.get(m);if(!b)continue;if(T.push(b),b.startDate){const k=bt(b.startDate).getTime();!isNaN(k)&&k<S&&(S=k)}if(b.endDate){const k=bt(b.endDate).getTime();!isNaN(k)&&k>g&&(g=k)}const w=b.metadata;typeof(w==null?void 0:w.hoursHigh)=="number"&&(y+=w.hoursHigh),typeof(w==null?void 0:w.hoursLogged)=="number"&&(v+=w.hoursLogged)}f.startDate=isFinite(S)?new Date(S):null,f.endDate=isFinite(g)?new Date(g):null,f.totalHours=y,f.totalLogged=v,f.progress=Math.max(0,Math.min(1,o(T)))}}function h(r){if(!r.startDate||!r.endDate)return null;const l=r.totalHours>0&&r.totalLogged>=r.totalHours,f=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),T=r.totalHours>0?`${r.totalHours}h (${f}% budget)`:`${r.allTaskIds.length} items`;return{id:`${gt}${r.config.id}`,name:T,startDate:Ns(r.startDate),endDate:Ns(r.endDate),progress:r.progress,color:l?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const l=a.getState();a.dispatch({type:"SET_SCROLL",x:l.scrollX,y:l.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...l)=>{const f=l[0];let T=null;typeof f=="string"?T=f:f&&typeof f=="object"&&"id"in f&&(T=String(f.id)),T&&T.startsWith(gt)&&p(T.substring(gt.length))}))},middleware(r,l){if(l(r),!a)return;const f=a.getState(),T=[];for(const y of f.tasks.keys())y.startsWith(gt)&&T.push(y);for(const y of T)f.tasks.delete(y);const S=f.flatVisibleIds.filter(y=>!y.startsWith(gt));let g=!1;for(const y of f.tasks.values())if(s(y)!=null){g=!0;break}if(!g){if(c=[],S.length!==f.flatVisibleIds.length){f.flatVisibleIds.length=0;for(const y of S)f.flatVisibleIds.push(y)}return}d(f,S);for(const y of c){if(y.allTaskIds.length===0)continue;const v=h(y);if(v){f.tasks.set(v.id,v);for(const m of y.allTaskIds){const b=f.tasks.get(m);b&&(b.parentId=v.id)}y.collapsed?f.expandedIds.delete(v.id):f.expandedIds.add(v.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,c=[],u=null,i.clear()}}}const Ia=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function Ma(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,c=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=c,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Os=864e5,Aa=6,Ra=2,La=2,Pa=.18,$a=.4;function Hs(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Tn(e,t){return Math.round((t.getTime()-e.getTime())/Os)}function ht(e,t){return new Date(e.getTime()+t*Os)}function vn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const A=E.lag||0;s.get(E.source).push({target:E.target,lag:A,depId:E.id}),o.get(E.target).push({source:E.source,lag:A,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,c=new Map,u=new Map;for(const[E,C]of e){const A=Hs(C.startDate),M=Hs(C.endDate);c.set(E,A),u.set(E,M),a.set(E,Math.max(Tn(A,M),0))}const d=new Map,h=new Map,p=[],r=[],l=new Map(i);for(const E of n)l.get(E)===0&&(r.push(E),d.set(E,c.get(E)),h.set(E,u.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),d.get(E);const C=h.get(E);for(const A of s.get(E)){const{target:M,lag:L}=A,N=ht(C,L),R=d.get(M);(!R||N.getTime()>R.getTime())&&(d.set(M,N),h.set(M,ht(N,a.get(M))));const $=l.get(M)-1;l.set(M,$),$===0&&r.push(M)}}for(const E of n)d.has(E)||(d.set(E,c.get(E)),h.set(E,u.get(E)),p.push(E));let f=-1/0;for(const E of h.values())E.getTime()>f&&(f=E.getTime());const T=new Date(f);let S=1/0;for(const E of d.values())E.getTime()<S&&(S=E.getTime());const g=new Date(S),y=Tn(g,T),v=new Map,m=new Map;for(const E of n)s.get(E).length===0&&(m.set(E,T),v.set(E,ht(T,-a.get(E))));for(let E=p.length-1;E>=0;E--){const C=p[E];if(!m.has(C)){let A=1/0;for(const M of s.get(C)){const L=v.get(M.target);if(L){const N=ht(L,-M.lag);N.getTime()<A&&(A=N.getTime())}}A===1/0?m.set(C,T):m.set(C,new Date(A)),v.set(C,ht(m.get(C),-a.get(C)))}}for(const E of n)m.has(E)||(m.set(E,T),v.set(E,ht(T,-a.get(E))));const b=.5,w=new Set,k=new Map;for(const E of n){const C=d.get(E),A=h.get(E),M=v.get(E),L=m.get(E),N=Tn(C,M),R=Math.abs(N)<b;R&&w.add(E),k.set(E,{earlyStart:C,earlyFinish:A,lateStart:M,lateFinish:L,totalFloat:N,isCritical:R})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&w.has(E.source)&&w.has(E.target)&&D.add(E.id);return{criticalTaskIds:w,criticalDependencyIds:D,taskAnalysis:k,projectDuration:y}}function _a(){let e,t=null,n=[];function s(){const o=e.getState();t=vn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:c,headerHeight:u,rowHeight:d,barHeight:h}=i.config,p=c.criticalPathColor||"#E53E3E",r=i.scrollX,l=i.scrollY,f=u,T=e.getTimeScale(),S=new Map;for(const m of a)S.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const m of a){const b=t.taskAnalysis.get(m.taskId);if(!b||b.isCritical||b.totalFloat<=0)continue;const w=m.barY-l,k=h*$a,D=m.x+m.width,C=T.dateToX(b.lateFinish)-D;C>1&&(o.fillStyle=m.color,o.globalAlpha=Pa,o.fillRect(D,w+h-k,C,k),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const b=m.x,w=m.barY-l,k=m.width,D=m.barHeight;if(!(w+D<f||w>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Aa;for(let E=0;E<Ra;E++){o.strokeStyle=p,o.lineWidth=La,o.beginPath();const C=c.barBorderRadius,A=Math.min(C,k/2,D/2);o.moveTo(b+A,w),o.lineTo(b+k-A,w),o.arcTo(b+k,w,b+k,w+A,A),o.lineTo(b+k,w+D-A),o.arcTo(b+k,w+D,b+k-A,w+D,A),o.lineTo(b+A,w+D),o.arcTo(b,w+D,b,w+D-A,A),o.lineTo(b,w+A),o.arcTo(b,w,b+A,w,A),o.closePath(),o.stroke()}o.restore()}}const g=6,y=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const b=S.get(m.source),w=S.get(m.target);if(!b||!w)continue;const k=b.x+b.width,D=b.barY+b.barHeight/2-l,E=w.x,C=w.barY+w.barHeight/2-l;o.beginPath(),o.strokeStyle=p,o.lineWidth=c.dependencyWidth+1;const A=k+v,M=E-v;if(o.moveTo(k,D),M>=A)o.lineTo(A,D),o.lineTo(A,C),o.lineTo(E,C);else{const L=(D+C)/2;o.lineTo(A,D),o.lineTo(A,L),o.lineTo(M,L),o.lineTo(M,C),o.lineTo(E,C)}o.stroke(),o.beginPath(),o.moveTo(E,C),o.lineTo(E-g,C-y),o.lineTo(E-g,C+y),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Na=864e5,Oa=.6,xs=.25,Ha="#38A169",xa="#E53E3E",Ba="#A0AEC0",Fa=10,Ua=4,Ze=16,Ya=3;function xt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Wa(e,t){return Math.round((t.getTime()-e.getTime())/Na)}function Xa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:xt(s.startDate),end:xt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var T,S;if(t.size===0)return;const{theme:a,headerHeight:c,barHeight:u}=o.config,d=o.scrollX,h=o.scrollY,p=c,r=n.getTimeScale(),l=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const f=u*Oa;for(const g of i){if(g.isMilestone)continue;const y=t.get(g.taskId);if(!y)continue;const v=g.barY-h;if(v+u+f<p||v>s.canvas.height)continue;const m=r.dateToX(y.start),b=r.dateToX(y.end),w=Math.max(b-m,2),k=v+u+1;xt(((T=o.tasks.get(g.taskId))==null?void 0:T.startDate)||"");const D=xt(((S=o.tasks.get(g.taskId))==null?void 0:S.endDate)||""),E=Wa(y.end,D);let C;E<0?C=Ha:E>0?C=xa:C=Ba,s.save(),s.globalAlpha=xs,s.fillStyle=C;const A=Math.min(l,w/2,f/2);if(s.beginPath(),s.moveTo(m+A,k),s.lineTo(m+w-A,k),s.arcTo(m+w,k,m+w,k+A,A),s.lineTo(m+w,k+f-A),s.arcTo(m+w,k+f,m+w-A,k+f,A),s.lineTo(m+A,k+f),s.arcTo(m,k+f,m,k+f-A,A),s.lineTo(m,k+A),s.arcTo(m,k,m+A,k,A),s.closePath(),s.fill(),s.globalAlpha=xs*2,s.strokeStyle=C,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const M=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${Fa}px ${a.fontFamily}`;const R=s.measureText(M).width+Ua*2,$=g.x+g.width+4,_=k+(f-Ze)/2;s.globalAlpha=.85,s.fillStyle=C;const U=Ya;s.beginPath(),s.moveTo($+U,_),s.lineTo($+R-U,_),s.arcTo($+R,_,$+R,_+U,U),s.lineTo($+R,_+Ze-U),s.arcTo($+R,_+Ze,$+R-U,_+Ze,U),s.lineTo($+U,_+Ze),s.arcTo($,_+Ze,$,_+Ze-U,U),s.lineTo($,_+U),s.arcTo($,_,$+U,_,U),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(M,$+R/2,_+Ze/2),s.restore()}}s.restore()},destroy(){}}}const Bs=5,za=5,Ga=.3,Va=15;function Ka(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:h,headerHeight:p}=d.config,r=d.scrollY,l=d.flatVisibleIds.length,f=a(d),T=Math.floor(r/h),S=Math.ceil((r+f)/h);let g=Math.max(0,T-Bs),y=Math.min(l,S+Bs);if(Math.abs(s)>0){const m=Math.min(Va,Math.ceil(Math.abs(s*Ga)/h));s>0?y=Math.min(l,y+m):g=Math.max(0,g-m)}const v=new Set;for(let m=g;m<y&&m<d.flatVisibleIds.length;m++)v.add(d.flatVisibleIds[m]);return{startRow:g,endRow:y,totalRows:l,visibleTaskIds:v}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function c(d){const h=performance.now();for(o.push({y:d,time:h});o.length>za;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],l=(r.time-p.time)/1e3;l>0&&(s=(r.y-p.y)/l)}n=d}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(c(d.scrollY),t=i(d)),t},filterLayouts(d){const h=u.getVisibleRange();return h.totalRows===0?[]:d.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(d){return u.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,h){if(h(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();c(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const Ye=864e5,Sn=1,Fs=2,Us=.5,Ys=2,Bt=8,Ws=6,Xs=2,Ft=1e4;function wn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function zs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function rt(e){return Math.round(e)+.5}function Gs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Vs(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,c=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const l=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,l,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const l=u+p*c;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,l,n,c)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,l+c),e.lineTo(n,l+c),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const T of a){const S=T.width??120,g=Gs(r,T.field);e.save(),e.beginPath(),e.rect(f,l,S,c),e.clip(),e.textBaseline="middle";const y=T.tree?8:0;e.textAlign=T.align==="right"?"right":T.align==="center"?"center":"left";const v=T.align==="right"?f+S-8:T.align==="center"?f+S/2:f+8+y;e.fillText(g,v,l+c/2),e.restore(),f+=S}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Ks(e,t,n,s,o){const{config:i}=t,a=i.theme,c=i.headerHeight,u=i.rowHeight,d=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=c+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:f,end:T}=t.dateRange,S=new Date(f);S.setUTCHours(0,0,0,0);const g=T.getTime();for(;S.getTime()<=g;){const y=S.getUTCDay();if(y===0||y===6){const v=o+s.dateToX(S),m=new Date(S.getTime()+Ye),b=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,c,b-v,h)}S.setTime(S.getTime()+Ye)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Us;for(const f of r){const T=rt(o+f);e.moveTo(T,c),e.lineTo(T,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,c+f*u,d,u));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:T,end:S}=t.dateRange;if(f.getTime()>=T.getTime()&&f.getTime()<=S.getTime()){const g=o+s.dateToX(f),y=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(g,c,y,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Fs,e.moveTo(rt(g),c),e.lineTo(rt(g),p),e.stroke()}}const l=a.barBorderRadius;for(const f of n){const T=o+f.x,S=f.barY,g=f.width,y=f.barHeight;if(f.isMilestone){const v=(y-Ys*2)/2,m=S+y/2;e.beginPath(),e.moveTo(T,m-v),e.lineTo(T+v,m),e.lineTo(T,m+v),e.lineTo(T-v,m),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(kn(e,T,S,g,y,l),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const v=zs(f.color,.2);e.save(),e.beginPath(),kn(e,T,S,g,y,l),e.clip(),e.fillStyle=v,e.fillRect(T,S,f.progressWidth,y),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),kn(e,T,S,g,y,l),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Xs,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(f.label).width,m=S+y/2;v+Bt*2<=g?(e.beginPath(),e.rect(T,S,g,y),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,T+Bt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,T+g+Ws,m)),e.restore()}}ja(e,t,n,a,o),qa(e,s,i,a,o)}function ja(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,c=6,u=4;e.save();for(const d of t.dependencies.values()){const h=i.get(d.source),p=i.get(d.target);if(!h||!p)continue;const r=d.type||"FS",l=h.barY+h.barHeight/2,f=p.barY+p.barHeight/2;let T,S;const g=r==="FS"||r==="FF",y=r==="FS"||r==="SS";switch(r){case"FS":T=o+h.x+h.width,S=o+p.x;break;case"SS":T=o+h.x,S=o+p.x;break;case"FF":T=o+h.x+h.width,S=o+p.x+p.width;break;case"SF":T=o+h.x,S=o+p.x+p.width;break}const v=g?T+a:T-a,m=y?S-a:S+a,b=g?y?m>=v:S+a>=v:y?S-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(T,l),b)e.lineTo(v,l),e.lineTo(v,f),e.lineTo(S,f);else{const w=(l+f)/2;e.lineTo(v,l),e.lineTo(v,w),e.lineTo(m,w),e.lineTo(m,f),e.lineTo(S,f)}e.stroke(),e.beginPath(),y?(e.moveTo(S,f),e.lineTo(S-c,f-u),e.lineTo(S-c,f+u)):(e.moveTo(S,f),e.lineTo(S+c,f-u),e.lineTo(S+c,f+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function qa(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const c=a.length||2,u=i/c;e.textBaseline="middle";for(let d=0;d<a.length;d++){const h=a[d],p=d*u;for(const r of h){const l=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=Sn,e.moveTo(rt(l+f),p),e.lineTo(rt(l+f),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(l,p,f,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,l+f/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=Sn,e.moveTo(o,rt(i)),e.lineTo(o+t.getTotalWidth(),rt(i)),e.stroke()}function kn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function wt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Za(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,c=o.rowHeight,u=n.getTotalWidth(),d=s+u,h=e.flatVisibleIds.length*c,p=a+h,r=i.barBorderRadius,l=[];l.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),l.push(`<style>text { font-family: ${wt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),l.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),l.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const m of o.columns){const b=m.width??120;l.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${wt(m.header)}</text>`),l.push(`<line x1="${f+b}" y1="0" x2="${f+b}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=b}for(let m=0;m<e.flatVisibleIds.length;m++){const b=e.tasks.get(e.flatVisibleIds[m]);if(!b)continue;const w=a+m*c;m%2===1&&l.push(`<rect x="0" y="${w}" width="${s}" height="${c}" fill="${i.gridAltRowBg}" />`);let k=0;for(const D of o.columns){const E=D.width??120,C=Gs(b,D.field),A=D.tree?8:0;l.push(`<text x="${k+8+A}" y="${w+c/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${C}]]></text>`),k+=E}l.push(`<line x1="0" y1="${w+c}" x2="${s}" y2="${w+c}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}l.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),l.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),l.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),l.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const T=n.getHeaderRows(),S=T.length||2,g=a/S;for(let m=0;m<T.length;m++){const b=T[m],w=m*g;for(const k of b){const D=s+k.x+k.width/2,E=w+g/2,C=m===0?' font-weight="600"':"";l.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${C} fill="${i.timelineHeaderText}">${wt(k.label)}</text>`),l.push(`<line x1="${s+k.x+k.width}" y1="${w}" x2="${s+k.x+k.width}" y2="${w+g}" stroke="${i.timelineGridColor}" stroke-width="${Sn}" />`)}}const y=n.getGridLines();for(const m of y)l.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Us}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&l.push(`<rect x="${s}" y="${a+m*c}" width="${u}" height="${c}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:b}=e.dateRange,w=new Date(m);for(w.setUTCHours(0,0,0,0);w.getTime()<=b.getTime();){if(w.getUTCDay()===0||w.getUTCDay()===6){const k=s+n.dateToX(w),D=new Date(w.getTime()+Ye),E=s+n.dateToX(D);l.push(`<rect x="${k}" y="${a}" width="${E-k}" height="${h}" fill="${i.timelineWeekendBg}" />`)}w.setTime(w.getTime()+Ye)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:b,end:w}=e.dateRange;if(m.getTime()>=b.getTime()&&m.getTime()<=w.getTime()){const k=s+n.dateToX(m),D=n.getColumnWidth();l.push(`<rect x="${k}" y="${a}" width="${D}" height="${h}" fill="${i.todayBg}" />`),l.push(`<line x1="${k}" y1="${a}" x2="${k}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${Fs}" />`)}}for(const m of t){const b=s+m.x,w=m.barY,k=m.width,D=m.barHeight;if(m.isMilestone){const E=(D-Ys*2)/2,C=w+D/2;l.push(`<polygon points="${b},${C-E} ${b+E},${C} ${b},${C+E} ${b-E},${C}" fill="${m.color}" />`);continue}if(l.push(`<rect x="${b}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const E=zs(m.color,.2);l.push(`<clipPath id="clip-${m.taskId}"><rect x="${b}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),l.push(`<rect x="${b}" y="${w}" width="${m.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&l.push(`<rect x="${b}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Xs}" />`),m.label){const E=w+D/2;i.fontSize*.6*m.label.length+Bt*2<=k?l.push(`<text x="${b+Bt}" y="${E}" dominant-baseline="central" fill="${m.textColor}">${wt(m.label)}</text>`):l.push(`<text x="${b+k+Ws}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${wt(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const b=v.get(m.source),w=v.get(m.target);if(!b||!w)continue;const k=m.type||"FS",D=b.barY+b.barHeight/2,E=w.barY+w.barHeight/2;let C,A;const M=k==="FS"||k==="FF",L=k==="FS"||k==="SS";switch(k){case"FS":C=s+b.x+b.width,A=s+w.x;break;case"SS":C=s+b.x,A=s+w.x;break;case"FF":C=s+b.x+b.width,A=s+w.x+w.width;break;case"SF":C=s+b.x,A=s+w.x+w.width;break}const N=12,R=6,$=4,_=M?C+N:C-N,U=L?A-N:A+N,Y=M?L?U>=_:A+N>=_:L?A-N<=_:U<=_;let K;if(Y)K=`M${C},${D} L${_},${D} L${_},${E} L${A},${E}`;else{const B=(D+E)/2;K=`M${C},${D} L${_},${D} L${_},${B} L${U},${B} L${U},${E} L${A},${E}`}l.push(`<path d="${K}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),L?l.push(`<polygon points="${A},${E} ${A-R},${E-$} ${A-R},${E+$}" fill="${i.dependencyColor}" />`):l.push(`<polygon points="${A},${E} ${A+R},${E-$} ${A+R},${E+$}" fill="${i.dependencyColor}" />`)}return l.push("</svg>"),l.join(`
`)}function Ja(){let e=null;function t(){const a=e,c=a.getState(),u=a.getTimeScale(),{start:d,end:h}=c.dateRange,p=h.getTime()-d.getTime(),r=u.getColumnWidth(),l=c.zoomLevel;let f;switch(l){case"day":f=Math.round(p/Ye);break;case"week":f=Math.ceil(p/(Ye*7));break;case"month":{const S=d.getUTCFullYear(),g=d.getUTCMonth(),y=h.getUTCFullYear(),v=h.getUTCMonth();f=(y-S)*12+(v-g);break}case"quarter":{const S=d.getUTCFullYear(),g=Math.floor(d.getUTCMonth()/3),y=h.getUTCFullYear(),v=Math.floor(h.getUTCMonth()/3);f=(y-S)*4+(v-g);break}}const T=f*r;return{dateToX(S){return(S.getTime()-d.getTime())/p*T},getColumnWidth(){return r},getTotalWidth(){return T},getHeaderRows(){return tr(l,d,h,r,T)},getGridLines(){return this.getHeaderRows()[1].map(g=>g.x).filter(g=>g>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let c=0;for(const u of a.config.columns)c+=u.width??120;return c}function s(a){if(!e)return;const c=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,l=c.flatVisibleIds.length*c.config.rowHeight,f=c.config.headerHeight+l,T=a??"gantt-export.png";if(r>Ft||f>Ft){o(c,d,u,h,r,f,T);return}const S=document.createElement("canvas");S.width=r,S.height=f;const g=S.getContext("2d");g&&(h>0&&Vs(g,c,h,f),Ks(g,c,d,u,h),S.toBlob(y=>{y&&wn(y,T)},"image/png"))}function o(a,c,u,d,h,p,r){const l=Math.min(1,Ft/h,Ft/p),f=Math.ceil(h*l),T=Math.ceil(p*l),S=document.createElement("canvas");S.width=f,S.height=T;const g=S.getContext("2d");g&&(g.scale(l,l),d>0&&Vs(g,a,d,p),Ks(g,a,c,u,d),S.toBlob(y=>{y&&wn(y,r)},"image/png"))}function i(a){if(!e)return;const c=e.getState(),u=t(),d=e.getLayouts(),h=n(),p=Za(c,d,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});wn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...c)=>{s(c[0])}),a.on("export:svg",(...c)=>{i(c[0])})},destroy(){e=null}}}const js=["January","February","March","April","May","June","July","August","September","October","November","December"],qs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Zs(e,t){return new Date(e.getTime()+t*Ye)}function Dn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Qa(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function er(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function tr(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=c=>er(c,t,i,o);switch(e){case"day":{const c=[],u=[],d=Math.round(i/Ye);let h=new Date(t);for(let r=0;r<d;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Zs(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=Dn(p),l=a(p),f=r.getTime()>=n.getTime()?o:a(r);c.push({label:`${js[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:l,width:f-l,date:new Date(p)}),p=r}return[c,u]}case"week":{const c=[],u=[],d=Math.ceil(i/(Ye*7));for(let p=0;p<d;p++){const r=Zs(t,p*7);u.push({label:`${qs[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=Dn(h),r=h.getTime()<t.getTime()?t:h,l=p.getTime()>n.getTime()?n:p;c.push({label:`${js[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(l)-a(r),date:new Date(r)}),h=p}return[c,u]}case"month":{const c=[],u=[],d=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),l=(p-d)*12+(r-h);let f=new Date(Date.UTC(d,h,1));for(let S=0;S<l;S++)u.push({label:qs[f.getUTCMonth()],x:S*s,width:s,date:new Date(f)}),f=Dn(f);let T=new Date(Date.UTC(d,0,1));for(;T.getTime()<n.getTime();){const S=new Date(Date.UTC(T.getUTCFullYear()+1,0,1)),g=T.getTime()<t.getTime()?t:T,y=S.getTime()>n.getTime()?n:S;c.push({label:String(T.getUTCFullYear()),x:a(g),width:a(y)-a(g),date:new Date(g)}),T=S}return[c,u]}case"quarter":{const c=[],u=[],d=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),l=(p-d)*4+(r-h);let f=new Date(Date.UTC(d,h*3,1));for(let S=0;S<l;S++){const g=Math.floor(f.getUTCMonth()/3)+1;u.push({label:`Q${g}`,x:S*s,width:s,date:new Date(f)}),f=Qa(f,3)}let T=new Date(Date.UTC(d,0,1));for(;T.getTime()<n.getTime();){const S=new Date(Date.UTC(T.getUTCFullYear()+1,0,1)),g=T.getTime()<t.getTime()?t:T,y=S.getTime()>n.getTime()?n:S;c.push({label:String(T.getUTCFullYear()),x:a(g),width:a(y)-a(g),date:new Date(g)}),T=S}return[c,u]}default:return[[],[]]}}const nr={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},En="nimbus-gantt-dark-theme-transition";function sr(){if(typeof document>"u"||document.getElementById(En))return;const e=document.createElement("style");e.id=En,e.textContent=`
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
  `,document.head.appendChild(e)}function or(){if(typeof document>"u")return;const e=document.getElementById(En);e&&e.remove()}function ir(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,c=null;function u(){if(!n||s)return;const l=n.getState();o={...l.config.theme};const f={...l.config.theme,...nr};Object.assign(l.config.theme,f),s=!0,p()}function d(){if(!n||!s||!o)return;const l=n.getState();Object.assign(l.config.theme,o),s=!1,p()}function h(){s?d():u()}function p(){if(!n)return;const l=n.getState();n.dispatch({type:"SET_SCROLL",x:l.scrollX,y:l.scrollY})}function r(l){l.matches?u():d()}return{name:"DarkThemePlugin",install(l){n=l,sr(),l.on("theme:toggle",()=>{h()}),l.on("theme:dark",()=>{u()}),l.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(c=l.on("render",()=>{c&&(c(),c=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),c&&c(),s&&n&&o){const l=n.getState();Object.assign(l.config.theme,o)}or(),n=null,o=null,i=null,a=null,s=!1}}}const Pe=864e5,ar=[1,2,3,4,5],rr="rgba(128, 128, 128, 0.06)",lr="rgba(128, 128, 128, 0.04)",cr="#f87171",kt=4;function Dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function xe(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function dr(e){const t=new Set((e==null?void 0:e.workDays)??ar),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const l=xe(r);return t.has(l.getUTCDay())}function i(r){const l=Dt(r);return n.has(l)?!1:t.has(r.getUTCDay())}function a(r){let l=xe(r);for(l=new Date(l.getTime()+Pe);!i(l);)l=new Date(l.getTime()+Pe);return Dt(l)}function c(r,l){if(l===0)return r;let f=xe(r);const T=l>0?1:-1;let S=Math.abs(l);if(!i(f))for(f=new Date(f.getTime()+T*Pe);!i(f);)f=new Date(f.getTime()+T*Pe);for(;S>0;)f=new Date(f.getTime()+T*Pe),i(f)&&S--;return Dt(f)}function u(r,l){const f=xe(r),T=xe(l);if(f.getTime()>T.getTime())return-u(l,r);let S=0,g=new Date(f.getTime());for(;g.getTime()<T.getTime();)i(g)&&S++,g=new Date(g.getTime()+Pe);return S}function d(r,l="forward"){if(o(r))return r;let f=xe(r);const T=l==="forward"?Pe:-Pe;for(let S=0;S<30;S++)if(f=new Date(f.getTime()+T),i(f))return Dt(f);return r}function h(r,l){if(r.type==="TASK_MOVE"){const f=d(r.startDate,"forward"),T=d(r.endDate,"backward"),S=xe(T).getTime()<xe(f).getTime()?f:T;l({...r,startDate:f,endDate:S});return}if(r.type==="TASK_RESIZE"){const f=d(r.startDate,"forward"),T=d(r.endDate,"backward"),S=xe(T).getTime()<xe(f).getTime()?f:T;l({...r,startDate:f,endDate:S});return}l(r)}function p(r,l,f){const{config:T}=l,S=T.headerHeight,g=l.flatVisibleIds.length*T.rowHeight,y=s==null?void 0:s.getTimeScale();if(!y||g===0)return;const{start:v,end:m}=l.dateRange,b=l.scrollX,w=l.scrollY;r.save();const k=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(k,0,0,k,0,0),r.beginPath(),r.rect(0,S,r.canvas.width/k,g),r.clip(),r.translate(-b,0);const D=new Date(v);D.setUTCHours(0,0,0,0);const E=m.getTime();for(y.getColumnWidth();D.getTime()<=E;){const C=Dt(D),A=n.has(C),M=!t.has(D.getUTCDay());if(A||M){const L=y.dateToX(D),N=new Date(D.getTime()+Pe),$=y.dateToX(N)-L;if(r.fillStyle=rr,r.fillRect(L,S-w,$,g+w),M&&!A){r.save(),r.beginPath(),r.rect(L,S,$,g),r.clip(),r.strokeStyle=lr,r.lineWidth=1;const _=8,U=g;for(let Y=-U;Y<$+U;Y+=_)r.beginPath(),r.moveTo(L+Y,S),r.lineTo(L+Y+U,S+U),r.stroke();r.restore()}}if(A){const L=y.dateToX(D),N=new Date(D.getTime()+Pe),R=y.dateToX(N),$=(L+R)/2;r.save(),r.setTransform(k,0,0,k,0,0),r.translate(-b,0);const _=S-kt-3;r.beginPath(),r.moveTo($,_-kt),r.lineTo($+kt,_),r.lineTo($,_+kt),r.lineTo($-kt,_),r.closePath(),r.fillStyle=cr,r.fill(),r.restore()}D.setTime(D.getTime()+Pe)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...l)=>{const f=l[0],T=l[1],S=l[2],g=c(f,T);S&&S(g)}),r.on("calendar:workDaysBetween",(...l)=>{const f=l[0],T=l[1],S=l[2],g=u(f,T);S&&S(g)}),r.on("calendar:isWorkDay",(...l)=>{const f=l[0],T=l[1],S=o(f);T&&T(S)}),r.on("calendar:nextWorkDay",(...l)=>{const f=l[0],T=l[1],S=a(f);T&&T(S)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function ur(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function gr(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function hr(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=ur(),a=[],c=Date.now();let u=null,d=null,h=!1,p=[];const r=[];function l(m,b){if(h)return;const w={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:b};a.push(w),o&&o(w)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function T(){d===null&&(d=setInterval(()=>{f()},s))}function S(){d!==null&&(clearInterval(d),d=null)}const g=gr(()=>{if(!u)return;const m=u.getState();l("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let y=0;function v(m,b){switch(m.type){case"SET_ZOOM":{const w=u?u.getState().zoomLevel:"unknown";b(m),l("gantt.zoom",{oldLevel:w,newLevel:m.level});return}case"TASK_MOVE":{const w=y>0?Date.now()-y:0;b(m),l("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:w}),y=0;return}case"TASK_RESIZE":{b(m),l("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{y=Date.now(),b(m);return}case"SELECT_TASK":{b(m),l("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{b(m),g();return}case"TOGGLE_EXPAND":{const w=u?u.getState().expandedIds.has(m.taskId):!1;b(m),l(w?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{b(m),l("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{b(m),l("gantt.collapse",{all:!0});return}default:b(m);return}}return{name:"TelemetryPlugin",install(m){u=m,T();const b=m.getState();l("gantt.init",{taskCount:b.tasks.size,dependencyCount:b.dependencies.size,zoomLevel:b.zoomLevel}),setTimeout(()=>{h||l("gantt.feature.used",{plugins:p})},0);const w=m.on("taskClick",(...k)=>{const D=k[0];D&&l("gantt.task.click",{taskId:D.id})});r.push(w)},middleware:v,destroy(){h=!0;const m=Date.now()-c;l("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),f(),S();for(const b of r)b();r.length=0,u=null}}}const Js=5,Cn=.15,In=.85,fr=2,Qs=30,We=["day","week","month","quarter"];function eo(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function pr(e,t,n){return Math.max(t,Math.min(n,e))}function mr(e){const t=pr((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let c=null,u=!1,d=0,h=0,p=0,r=null,l=null,f=null,T=null,S=null,g=null,y=0,v=0,m=0,b=!1;function w(R,$,_){m=R,y=$,v=_,b=!0,r===null&&(r=R)}function k(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(T=R=>{u||R.alpha==null||R.beta==null||R.gamma==null||w(R.alpha,R.beta,R.gamma)},window.addEventListener("deviceorientation",T),!0)}function D(){T&&(window.removeEventListener("deviceorientation",T),T=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function C(R){try{const $=JSON.parse(R);$.type==="orientation"?w($.alpha,$.beta,$.gamma):$.type==="gesture"&&A($.gesture)}catch{}}function A(R){if(!c)return;const $=c.getState();switch(R){case"tap":{$.selectedIds.size===0&&$.flatVisibleIds.length>0&&c.dispatch({type:"SELECT_TASK",taskId:$.flatVisibleIds[0]});break}case"doubletap":{c.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const _=We.indexOf($.zoomLevel);_<We.length-1&&c.dispatch({type:"SET_ZOOM",level:We[_+1]});break}case"swipe-right":{const _=We.indexOf($.zoomLevel);_>0&&c.dispatch({type:"SET_ZOOM",level:We[_-1]});break}}}function M(){if(u||typeof WebSocket>"u")return;const R=E();try{S=new WebSocket(R),S.onmessage=$=>{typeof $.data=="string"&&C($.data)},S.onclose=()=>{S=null,u||(g=setTimeout(M,3e3))},S.onerror=()=>{S&&S.close()}}catch{u||(g=setTimeout(M,3e3))}}function L(){g!==null&&(clearTimeout(g),g=null),S&&(S.onmessage=null,S.onclose=null,S.onerror=null,S.close(),S=null)}function N(){if(!(u||!c)){if(b){d=d*In+y*Cn,h=h*In+v*Cn,p=p*In+m*Cn;const R=c.getState(),$=fr*a;if(n){const _=eo(h,Js);if(_!==0){const U=_*$,Y=Math.max(0,R.scrollX+U);c.dispatch({type:"SET_SCROLL_X",x:Y})}}if(s){const _=eo(d,Js);if(_!==0){const U=_*$,Y=Math.max(0,R.scrollY+U);c.dispatch({type:"SET_SCROLL_Y",y:Y})}}if(o&&r!==null){const U=(p-r+540)%360-180,Y=We.indexOf(R.zoomLevel);if(U>Qs&&Y>0){const K=We[Y-1];l!==K&&(c.dispatch({type:"SET_ZOOM",level:K}),l=K,r=m)}else if(U<-Qs&&Y<We.length-1){const K=We[Y+1];l!==K&&(c.dispatch({type:"SET_ZOOM",level:K}),l=K,r=m)}}}f=requestAnimationFrame(N)}}return{name:"MotionControlPlugin",install(R){c=R,l=R.getState().zoomLevel,(!k()||i)&&M(),f=requestAnimationFrame(N)},destroy(){u=!0,f!==null&&(cancelAnimationFrame(f),f=null),D(),L(),c=null}}}const Et="http://schemas.microsoft.com/project",yr=8,to=4800,br={0:"FF",1:"FS",2:"SF",3:"SS"},Tr={FF:0,FS:1,SF:2,SS:3};function no(e){return e?e.substring(0,10):""}function so(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(Et,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function vr(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function Sr(e){return`PT${e*yr}H0M0S`}function Ct(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Mn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(Et,"Resource"),c=a.length>0?a:o.getElementsByTagName("Resource");for(let g=0;g<c.length;g++){const y=c[g],v=Ee(y,"UID"),m=Ee(y,"Name");v&&m&&i.set(v,m)}const u=new Map,d=o.getElementsByTagNameNS(Et,"Assignment"),h=d.length>0?d:o.getElementsByTagName("Assignment");for(let g=0;g<h.length;g++){const y=h[g],v=Ee(y,"TaskUID"),m=Ee(y,"ResourceUID");if(v&&m){const b=i.get(m);b&&u.set(v,b)}}const p=[],r=[],l=o.getElementsByTagNameNS(Et,"Task"),f=l.length>0?l:o.getElementsByTagName("Task"),T=[];let S=1;for(let g=0;g<f.length;g++){const y=f[g],v=Ee(y,"UID"),m=Ee(y,"Name"),b=Ee(y,"Start"),w=Ee(y,"Finish"),k=Ee(y,"PercentComplete"),D=Ee(y,"Summary")==="1",E=Ee(y,"Milestone")==="1",C=parseInt(Ee(y,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const A=`msp-${v}`,M=no(b),L=no(w);if(!M&&!E)continue;let N;C>0&&T[C-1]&&(N=T[C-1]),T[C]=A,T.length=C+1;const R={id:A,name:m||`Task ${v}`,startDate:M||L,endDate:L||M,progress:k?parseInt(k,10)/100:0,isMilestone:E,parentId:N,sortOrder:g},$=u.get(v);$&&(R.assignee=$),D&&(R.metadata={...R.metadata,isSummary:!0}),p.push(R);const _=y.getElementsByTagNameNS(Et,"PredecessorLink"),U=_.length>0?_:y.getElementsByTagName("PredecessorLink");for(let Y=0;Y<U.length;Y++){const K=U[Y],B=Ee(K,"PredecessorUID"),I=parseInt(Ee(K,"Type")||"1",10),O=Ee(K,"LinkLag"),P=O?parseInt(O,10):0;if(!B||B==="0")continue;const x={id:`msp-dep-${S++}`,source:`msp-${B}`,target:A,type:br[I]??"FS",lag:P!==0?P/to:void 0};r.push(x)}}return{tasks:p,dependencies:r}}function An(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),c=Array.from(e.dependencies.values());function u(v){let m=1,b=v;for(;b!=null&&b.parentId;)m++,b=e.tasks.get(b.parentId);return m}const d=new Map,h=new Map;for(const v of a){const m=v.parentId??"__root__",b=(d.get(m)??0)+1;if(d.set(m,b),!v.parentId)h.set(v.id,String(b));else{const w=h.get(v.parentId)??"0";h.set(v.id,`${w}.${b}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const l=new Map;for(const v of c){const m=l.get(v.target)??[];m.push(v),l.set(v.target,m)}const f=new Set;for(const v of a)v.assignee&&f.add(v.assignee);const T=Array.from(f),S=new Map;T.forEach((v,m)=>{S.set(v,m+1)});const g=[];g.push('<?xml version="1.0" encoding="UTF-8"?>'),g.push('<Project xmlns="http://schemas.microsoft.com/project">'),g.push(`  <Name>${Ct(n)}</Name>`),g.push(`  <Author>${Ct(s)}</Author>`),g.push(`  <CreationDate>${o}</CreationDate>`),g.push("  <CalendarUID>1</CalendarUID>"),g.push("  <Calendars>"),g.push("    <Calendar>"),g.push("      <UID>1</UID>"),g.push(`      <Name>${Ct(i)}</Name>`),g.push("      <IsBaseCalendar>1</IsBaseCalendar>"),g.push("    </Calendar>"),g.push("  </Calendars>"),g.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,b=u(v),w=h.get(v.id)??"1",k=p.has(v.id),D=v.isMilestone??!1,E=so(v.startDate),C=so(v.endDate),A=vr(E,C),M=Sr(A),L=Math.round((v.progress??0)*100);g.push("    <Task>"),g.push(`      <UID>${m}</UID>`),g.push(`      <ID>${m}</ID>`),g.push(`      <Name>${Ct(v.name)}</Name>`),g.push(`      <Start>${v.startDate}T08:00:00</Start>`),g.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),g.push(`      <Duration>${M}</Duration>`),g.push(`      <PercentComplete>${L}</PercentComplete>`),g.push(`      <Summary>${k?"1":"0"}</Summary>`),g.push(`      <Milestone>${D?"1":"0"}</Milestone>`),g.push(`      <OutlineLevel>${b}</OutlineLevel>`),g.push(`      <OutlineNumber>${w}</OutlineNumber>`);const N=l.get(v.id);if(N)for(const R of N){const $=r.get(R.source)??0;if($===0)continue;const _=Tr[R.type??"FS"]??1,U=Math.round((R.lag??0)*to);g.push("      <PredecessorLink>"),g.push(`        <PredecessorUID>${$}</PredecessorUID>`),g.push(`        <Type>${_}</Type>`),g.push(`        <LinkLag>${U}</LinkLag>`),g.push("      </PredecessorLink>")}g.push("    </Task>")}g.push("  </Tasks>"),g.push("  <Resources>");for(const v of T){const m=S.get(v)??0;g.push("    <Resource>"),g.push(`      <UID>${m}</UID>`),g.push(`      <Name>${Ct(v)}</Name>`),g.push("    </Resource>")}g.push("  </Resources>"),g.push("  <Assignments>");let y=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,b=S.get(v.assignee)??0;m===0||b===0||(g.push("    <Assignment>"),g.push(`      <UID>${y++}</UID>`),g.push(`      <TaskUID>${m}</TaskUID>`),g.push(`      <ResourceUID>${b}</ResourceUID>`),g.push("    </Assignment>"))}return g.push("  </Assignments>"),g.push("</Project>"),g.join(`
`)}function wr(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=c=>{var d;const u=(d=c.target)==null?void 0:d.result;if(!(!u||!e))try{const h=Mn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const c=Mn(a);o.dispatch({type:"SET_DATA",tasks:c.tasks,dependencies:c.dependencies})}catch(c){console.error("[MSProjectPlugin] Import failed:",c)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},c=i[1],u=o.getState(),d=An(u,a);c&&c(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},c=i[1]??"project-export.xml",u=o.getState(),d=An(u,a),h=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=c,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const kr=[4,3],Dr=1.5,Er=.5,Cr=.06,Ir=4,Mr=8,Ar=.35,Rr=1,oo=.2,It=6,io=864e5;function Be(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ao(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Rn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Ln(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Lr(e){let t=0;for(const n of e){const s=Be(n.startDate).getTime(),o=Be(n.endDate).getTime();t+=Math.max(o-s,io)}return t}function Pr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const c=n.getState().tasks.get(s.taskId);if(c){const u=Be(c.startDate).getTime(),h=Be(s.startDate).getTime()-u,p=i.segments.map(r=>{const l=new Date(Be(r.startDate).getTime()+h),f=new Date(Be(r.endDate).getTime()+h);return{startDate:ao(l),endDate:ao(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const c=n.getState().tasks.get(s.taskId);if(c){const u=c.startDate,d=c.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:c,scrollY:u}=o,{theme:d,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),l=d.barBorderRadius,f=h;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-c,0);for(const T of i){if(T.isMilestone)continue;const S=t.get(T.taskId);if(!S||S.segments.length===0)continue;const g=T.barY-u,y=T.barHeight,v=g+y/2;if(g+y<f||g>s.canvas.height)continue;const m=[];for(const C of S.segments){const A=r.dateToX(Be(C.startDate)),M=r.dateToX(Be(C.endDate)),L=Math.max(M-A,4);m.push({startX:A,endX:A+L,width:L})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(T.x-1,g-1,T.width+2,y+2),s.restore();for(let C=0;C<m.length-1;C++){const A=m[C].endX,M=m[C+1].startX,L=M-A;if(!(L<=0)){s.save(),s.globalAlpha=Cr,s.strokeStyle=T.color,s.lineWidth=Ir,s.beginPath(),s.rect(A,g,L,y),s.clip();for(let N=A-y;N<M+y;N+=Mr)s.beginPath(),s.moveTo(N,g+y),s.lineTo(N+y,g),s.stroke();s.restore()}}for(let C=0;C<m.length-1;C++){const A=m[C].endX,M=m[C+1].startX;s.save(),s.globalAlpha=Er,s.strokeStyle=Rn(T.color,oo),s.lineWidth=Dr,s.setLineDash(kr),s.beginPath(),s.moveTo(A,v),s.lineTo(M,v),s.stroke(),s.setLineDash([]),s.restore()}const b=o.tasks.get(T.taskId),w=(b==null?void 0:b.progress)??0,k=Lr(S.segments);let E=w*k;for(let C=0;C<m.length;C++){const A=m[C],M=Math.max(Be(S.segments[C].endDate).getTime()-Be(S.segments[C].startDate).getTime(),io);if(s.save(),Ln(s,A.startX,g,A.width,y,l),s.fillStyle=T.color,s.fill(),s.strokeStyle=Rn(T.color,oo),s.lineWidth=Rr,s.stroke(),s.restore(),E>0&&a.showProgress){const L=Math.min(E,M),N=L/M,R=A.width*N;s.save(),Ln(s,A.startX,g,A.width,y,l),s.clip(),s.globalAlpha=Ar,s.fillStyle=Rn(T.color,.3),s.fillRect(A.startX,g,R,y),s.restore(),E-=L}}if(T.label){const C=m[0],A=m[m.length-1],M=A.endX-C.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const N=s.measureText(T.label).width;s.textBaseline="middle",s.textAlign="left",N+It*2<=C.width?(s.fillStyle=T.textColor,Ln(s,C.startX,g,C.width,y,l),s.clip(),s.fillText(T.label,C.startX+It,v)):N+It<=M?(s.fillStyle=T.textColor,s.fillText(T.label,C.startX+It,v)):(s.fillStyle=d.gridTextColor,s.fillText(T.label,A.endX+It,v)),s.restore()}}s.restore()},destroy(){n=null}}}const Pn=864e5,ro=1e3,Ut=4,$r=.6,_r="#E53E3E",Nr="#48BB78",Or="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ft(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Yt(e,t){return Math.round((t.getTime()-e.getTime())/Pn)}function lo(e,t){return new Date(e.getTime()+t*Pn)}function Je(e,t){return ft(lo(he(e),t))}function Xe(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ft(n)),o;for(;i.getTime()<s.getTime();)o.push(ft(i)),i.setTime(i.getTime()+Pn);return o}class $n{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const c of s)i.set(c,(i.get(c)??0)+o),a.has(c)||a.set(c,new Set),a.get(c).add(n)}deallocate(t,n,s,o){var c,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(c=a.get(d))==null||c.delete(n),((u=a.get(d))==null?void 0:u.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),c=this.taskGrid.get(t);for(const d of s){let h=(a==null?void 0:a.get(d))??0;if((u=c==null?void 0:c.get(d))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Wt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,c]of i)if(c>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:c-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Hr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const c=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof c=="number")u=c;else if(typeof c=="string"){const d=parseInt(c,10);isNaN(d)||(u=d)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function co(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function xr(e,t,n,s,o){const i=new Map;for(const g of s)e.has(g.taskId)&&n.has(g.resourceId)&&(i.has(g.taskId)||i.set(g.taskId,[]),i.get(g.taskId).push({resourceId:g.resourceId,units:g.units||1}));const a=new Map,c=new Map;for(const g of e.keys())a.set(g,[]),c.set(g,[]);for(const g of t.values()){if((g.type||"FS")!=="FS"||!e.has(g.source)||!e.has(g.target))continue;const v=g.lag||0;a.get(g.source).push({target:g.target,lag:v}),c.get(g.target).push({source:g.source,lag:v})}const u=new Map;for(const[g,y]of e){const v=he(y.startDate),m=he(y.endDate);u.set(g,{taskId:g,startDate:y.startDate,endDate:y.endDate,duration:Math.max(Yt(v,m),0)})}const d=new $n;function h(){d.clear();for(const[g,y]of u){const v=i.get(g);if(!v)continue;const m=Xe(y.startDate,y.endDate);for(const b of v)d.allocate(b.resourceId,g,m,b.units)}}function p(g,y){const v=u.get(g);if(!v)return new Set;const m=new Set,b=v.startDate;if(y===b||he(y).getTime()<he(b).getTime())return m;const w=i.get(g);if(w){const k=Xe(v.startDate,v.endDate);for(const D of w)d.deallocate(D.resourceId,g,k,D.units)}if(v.startDate=y,v.endDate=Je(y,v.duration),m.add(g),w){const k=Xe(v.startDate,v.endDate);for(const D of w)d.allocate(D.resourceId,g,k,D.units)}return m}function r(g){const y=new Set,v=u.get(g);if(!v)return y;const m=a.get(g)??[];for(const{target:b,lag:w}of m){const k=u.get(b);if(!k)continue;const D=Je(v.endDate,w);if(he(k.startDate).getTime()<he(D).getTime()){const E=p(b,D);for(const C of E){y.add(C);const A=r(C);for(const M of A)y.add(M)}}}return y}function l(g){const y=c.get(g)??[];let v=u.get(g).startDate;v=e.get(g).startDate;for(const{source:b,lag:w}of y){const k=u.get(b);if(!k)continue;const D=Je(k.endDate,w);he(D).getTime()>he(v).getTime()&&(v=D)}return v}h();for(let g=0;g<ro;g++){const y=Wt(d,n);if(y.length===0)break;let v=!1;const m=y[0],b=m.taskIds.map(w=>o.get(w)).filter(w=>w!==void 0).sort(co);if(!(b.length<2))for(let w=1;w<b.length;w++){const k=b[w],D=u.get(k.taskId);if(!D)continue;const E=u.get(b[0].taskId);if(!E)continue;const C=E.endDate,A=l(k.taskId),M=he(C).getTime()>he(A).getTime()?C:A;he(M).getTime()>he(D.startDate).getTime()&&(p(k.taskId,M),r(k.taskId),v=!0);const L=d.getLoad(m.resourceId,m.date),N=n.get(m.resourceId).maxUnits;if(L<=N)break}}const f=new Map;let T=0;for(const[g,y]of u){const v=e.get(g),m=Yt(he(v.startDate),he(y.startDate));m!==0&&(f.set(g,{startDate:y.startDate,endDate:y.endDate,delayDays:m}),T+=m)}const S=Wt(d,n);return{adjustedTasks:f,totalDelay:T,conflicts:S,resolved:S.length===0}}function Br(e,t,n,s,o){const i=new Map;for(const y of s)e.has(y.taskId)&&n.has(y.resourceId)&&(i.has(y.taskId)||i.set(y.taskId,[]),i.get(y.taskId).push({resourceId:y.resourceId,units:y.units||1}));const a=new Map;for(const y of e.keys())a.set(y,[]);for(const y of t.values())(y.type||"FS")==="FS"&&(!e.has(y.source)||!e.has(y.target)||a.get(y.target).push({source:y.source,lag:y.lag||0}));const c=Array.from(e.keys()).map(y=>o.get(y)).filter(y=>y!==void 0).sort(co),u=new Map,d=new $n,h=new Set,p=new Map;for(const[y,v]of e)p.set(y,Math.max(Yt(he(v.startDate),he(v.endDate)),0));function r(y){let m=e.get(y).startDate;const b=a.get(y)??[];for(const{source:w,lag:k}of b){const D=u.get(w);if(!D)continue;const E=Je(D.endDate,k);he(E).getTime()>he(m).getTime()&&(m=E)}return m}function l(y,v,m){const b=i.get(y);if(!b||b.length===0)return v;let w=v;const k=365*5;for(let D=0;D<k;D++){const E=Je(w,m),C=Xe(w,E);let A=!0;for(const M of b){const L=n.get(M.resourceId);if(!L||L.maxUnits===0)continue;const N=L.calendar?new Set(L.calendar):null;if(N&&C.some($=>N.has($))){A=!1;break}if(!d.canFit(M.resourceId,y,C,M.units,L.maxUnits)){A=!1;break}}if(A)return w;w=Je(w,1)}return v}const f=new Set(c.map(y=>y.taskId));for(let y=0;y<ro&&f.size>0;y++){let v=!1;for(const m of c){if(!f.has(m.taskId)||!(a.get(m.taskId)??[]).every(L=>h.has(L.source)))continue;const k=m.taskId,D=p.get(k)??0,E=r(k),C=l(k,E,D),A=Je(C,D);u.set(k,{taskId:k,startDate:C,endDate:A,duration:D});const M=i.get(k);if(M){const L=Xe(C,A);for(const N of M)d.allocate(N.resourceId,k,L,N.units)}h.add(k),f.delete(k),v=!0}if(!v){for(const m of f){const b=e.get(m),w=p.get(m)??0;u.set(m,{taskId:m,startDate:b.startDate,endDate:b.endDate,duration:w});const k=i.get(m);if(k){const D=Xe(b.startDate,b.endDate);for(const E of k)d.allocate(E.resourceId,m,D,E.units)}h.add(m)}f.clear()}}const T=new Map;let S=0;for(const[y,v]of u){const m=e.get(y),b=Yt(he(m.startDate),he(v.startDate));b!==0&&(T.set(y,{startDate:v.startDate,endDate:v.endDate,delayDays:b}),S+=b)}const g=Wt(d,n);return{adjustedTasks:T,totalDelay:S,conflicts:g,resolved:g.length===0}}function Fr(e,t,n,s){const o=[],i=Xe(n,Je(s,1)),a=i.length;for(const[c,u]of t){const d=new Map;let h=0,p=0;for(const f of i){const T=e.getLoad(c,f);d.set(f,T),h+=T,T>p&&(p=T)}const r=u.maxUnits===0?1:u.maxUnits,l=a>0?h/(a*r):0;o.push({resourceId:c,resourceName:u.name,dailyLoad:d,overallUtilization:Math.min(l,1),peakUtilization:p})}return o}function uo(e,t,n,s){const o=new $n,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,c]of e){const u=i.get(a);if(!u)continue;const d=s.get(a),h=(d==null?void 0:d.startDate)??c.startDate,p=(d==null?void 0:d.endDate)??c.endDate,r=Xe(h,p);for(const l of u)o.allocate(l.resourceId,a,r,l.units)}return o}function Ur(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const c=[];function u(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:l,dependencies:f}=r;if(l.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const T=u(),S=Hr(l,T,n);s==="parallel"?i=Br(l,f,t,e.assignments,S):i=xr(l,f,t,e.assignments,S);const g=h(l,i.adjustedTasks),y=uo(l,t,e.assignments,i.adjustedTasks);return a=Fr(y,t,g.start,g.end),i}function h(r,l){let f=1/0,T=-1/0;for(const[S,g]of r){const y=l.get(S),v=he((y==null?void 0:y.startDate)??g.startDate).getTime(),m=he((y==null?void 0:y.endDate)??g.endDate).getTime();v<f&&(f=v),m>T&&(T=m)}if(f===1/0){const S=ft(new Date);return{start:S,end:S}}return{start:ft(new Date(f)),end:ft(new Date(T))}}function p(r){const l=[];for(const f of e.assignments)f.taskId===r&&l.push(f.resourceId);return l}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),c.push(r.on("resourceLeveling:run",(...l)=>{const f=l[0],T=d();f&&f(T)})),c.push(r.on("resourceLeveling:result",(...l)=>{const f=l[0];f&&f(i)})),c.push(r.on("resourceLeveling:utilization",(...l)=>{const f=l[0];f&&f(a)})),c.push(r.on("resourceLeveling:conflicts",(...l)=>{const f=l[0];if(!f)return;const T=r.getState(),S=uo(T.tasks,t,e.assignments,new Map);f(Wt(S,t))}))},middleware(r,l){l(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,l,f){if(!i||a.length===0)return;const{config:T}=l,{headerHeight:S,rowHeight:g}=T,y=l.scrollX,v=l.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,S,r.canvas.width,r.canvas.height-S),r.clip(),r.translate(-y,0);const b=new Map;for(const w of a)b.set(w.resourceId,w);for(const w of f){const k=p(w.taskId);if(k.length===0)continue;const D=b.get(k[0]);if(!D)continue;const E=t.get(k[0]);if(!E)continue;const C=E.maxUnits===0?1:E.maxUnits,M=w.barY+w.barHeight-v+1;if(M+Ut<S||M>r.canvas.height)continue;const L=l.tasks.get(w.taskId);if(!L)continue;const N=i.adjustedTasks.get(w.taskId),R=(N==null?void 0:N.startDate)??L.startDate,$=(N==null?void 0:N.endDate)??L.endDate,_=m.dateToX(he(R)),Y=m.dateToX(he($))-_;if(Y<2)continue;r.fillStyle=Or,r.fillRect(_,M,Y,Ut);const K=Xe(R,$);for(const B of K){const I=D.dailyLoad.get(B)??0;if(I===0)continue;const O=m.dateToX(he(B)),x=m.dateToX(lo(he(B),1))-O,ee=Math.min(I/C,2)/2*Ut,Z=I>C;r.globalAlpha=$r,r.fillStyle=Z?_r:Nr,r.fillRect(O,M+Ut-ee,x,ee),r.globalAlpha=1}}r.restore()},destroy(){for(const r of c)r();c.length=0,o=null,i=null,a=[]}}}const Xt=864e5;function ye(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ze(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function go(e,t){return Math.round((ye(t).getTime()-ye(e).getTime())/Xt)}function ho(e,t){return ze(new Date(ye(e).getTime()+t*Xt))}function fo(){return{addDays:ho,daysBetween:go}}function _n(e,t,...n){try{const s=e;if(typeof s.emit=="function")return s.emit(t,...n),!0}catch{}return!1}function po(e,t){const n=new Map,s=new Map,o=new Map;for(const d of e)n.set(d,[]),s.set(d,[]),o.set(d,0);for(const d of t.values()){if(!e.has(d.source)||!e.has(d.target))continue;const h={source:d.source,target:d.target,type:d.type||"FS",lag:d.lag||0,depId:d.id};n.get(d.source).push(h),s.get(d.target).push(h),o.set(d.target,(o.get(d.target)||0)+1)}const i=new Map(o),a=[],c=[];for(const d of e)i.get(d)===0&&a.push(d);for(;a.length>0;){const d=a.shift();c.push(d);for(const h of n.get(d)){const p=i.get(h.target)-1;i.set(h.target,p),p===0&&a.push(h.target)}}const u=new Set;for(const d of e)c.includes(d)||u.add(d);return{successors:n,predecessors:s,inDegree:o,circularTaskIds:u,topoOrder:c}}function Nn(e,t,n,s){const o=new Set(e.keys()),i=[],a=new Map;if(o.size===0)return{scheduledTasks:a,violations:i,projectStart:n.projectStart||ze(new Date),projectEnd:n.projectStart||ze(new Date),totalDuration:0};const c=n.constraints||new Map,u=n.capacity,d=(u==null?void 0:u.pace)??1,h=u!=null&&u.hoursPerMonth&&u.hoursPerMonth>0&&d>0?u.hoursPerMonth*12/365*d:0,p=(u==null?void 0:u.demandOf)??(M=>{const L=M,N=typeof L.estimatedHours=="number"?L.estimatedHours:0,R=typeof L.loggedHours=="number"?L.loggedHours:0;return Math.max(0,N-R)}),r=new Map,l=M=>Math.floor(ye(M).getTime()/Xt);function f(M,L,N){if(h<=0||N<=0)return;const R=Math.max(1,L),$=Math.min(N/R,h),_=l(M);for(let U=_;U<_+R;U++)r.set(U,(r.get(U)||0)+$)}function T(M,L,N){if(h<=0||N<=0)return M;const R=Math.max(1,L),$=Math.min(N/R,h);let _=l(M),U=0;e:for(;U++<3650;){for(let Y=_;Y<_+R;Y++)if((r.get(Y)||0)+$>h+1e-6){_=Y+1;continue e}break}for(let Y=_;Y<_+R;Y++)r.set(Y,(r.get(Y)||0)+$);return ze(new Date(_*Xt))}let S=o;if(h>0&&(u!=null&&u.priorityOf)){const M=u.priorityOf;S=new Set([...o].sort((L,N)=>{const R=M(e.get(L)),$=M(e.get(N));return R!==$?R-$:e.get(L).startDate<e.get(N).startDate?-1:1}))}const g=po(S,t);for(const M of g.circularTaskIds){const L=e.get(M);i.push({taskId:M,type:"circular",message:`Task "${(L==null?void 0:L.name)||M}" is part of a circular dependency chain`})}const y=new Map;for(const[M,L]of e){const N=s.daysBetween(L.startDate,L.endDate);y.set(M,Math.max(N,0))}let v;if(n.projectStart)v=n.projectStart;else{let M=1/0;for(const R of e.values()){const $=ye(R.startDate).getTime();Number.isFinite($)&&$<M&&(M=$)}const L=Date.now(),N=Number.isFinite(M)?Math.max(M,L):L;v=ze(new Date(N))}const m=new Map,b=new Map,w=new Set;for(const[M,L]of e)m.set(M,L.startDate),b.set(M,L.endDate);for(const M of g.topoOrder){const L=e.get(M),N=y.get(M),R=c.get(M),$=g.predecessors.get(M);let _;if($.length===0)_=v;else{let Y=v;for(const K of $){const B=m.get(K.source),I=b.get(K.source);let O;switch(K.type){case"FS":O=s.addDays(I,K.lag);break;case"SS":O=s.addDays(B,K.lag);break;case"FF":{const P=s.addDays(I,K.lag);O=s.addDays(P,-N);break}case"SF":{const P=s.addDays(B,K.lag);O=s.addDays(P,-N);break}default:O=s.addDays(I,K.lag)}ye(O).getTime()>ye(Y).getTime()&&(Y=O)}_=Y}if(R)switch(R.type){case"ASAP":break;case"ALAP":w.add(M);break;case"SNET":R.date&&ye(_).getTime()<ye(R.date).getTime()&&(_=R.date);break;case"SNLT":R.date&&ye(_).getTime()>ye(R.date).getTime()&&i.push({taskId:M,type:"constraint",message:`Task "${L.name}" cannot start by ${R.date} (earliest possible: ${_}). SNLT constraint violated.`});break;case"MSO":R.date&&(ye(_).getTime()>ye(R.date).getTime()&&i.push({taskId:M,type:"constraint",message:`Task "${L.name}" has MSO constraint ${R.date} but dependencies require start no earlier than ${_}.`}),_=R.date);break;case"FNET":{if(R.date){const Y=s.addDays(R.date,-N);ye(_).getTime()<ye(Y).getTime()&&(_=Y)}break}case"FNLT":{if(R.date){const Y=s.addDays(_,N);ye(Y).getTime()>ye(R.date).getTime()&&i.push({taskId:M,type:"constraint",message:`Task "${L.name}" cannot finish by ${R.date} (earliest finish: ${Y}). FNLT constraint violated.`})}break}case"MFO":if(R.date){const Y=s.addDays(R.date,-N);ye(_).getTime()>ye(Y).getTime()&&i.push({taskId:M,type:"constraint",message:`Task "${L.name}" has MFO constraint ${R.date} but dependencies require start no earlier than ${_} (finish would be ${s.addDays(_,N)}).`}),_=Y}break}if(h>0&&!w.has(M)){const Y=p(L);R&&(R.type==="MSO"||R.type==="MFO")?f(_,N,Y):_=T(_,N,Y)}const U=s.addDays(_,N);m.set(M,_),b.set(M,U)}if(w.size>0){let M=-1/0;for(const N of b.values()){const R=ye(N).getTime();R>M&&(M=R)}const L=ze(new Date(M));for(let N=g.topoOrder.length-1;N>=0;N--){const R=g.topoOrder[N];if(!w.has(R))continue;const $=y.get(R),_=g.successors.get(R);let U;if(_.length===0)U=s.addDays(L,-$);else{let K=1/0;for(const B of _){const I=m.get(B.target);let O;switch(B.type){case"FS":O=s.addDays(I,-B.lag);break;case"SS":O=s.addDays(s.addDays(I,-B.lag),$);break;case"FF":O=s.addDays(b.get(B.target),-B.lag);break;case"SF":O=s.addDays(s.addDays(b.get(B.target),-B.lag),$);break;default:O=s.addDays(I,-B.lag)}const P=s.addDays(O,-$),x=ye(P).getTime();x<K&&(K=x)}U=ze(new Date(K))}const Y=m.get(R);ye(U).getTime()<ye(Y).getTime()&&(U=Y),m.set(R,U),b.set(R,s.addDays(U,$))}}for(const M of o)a.set(M,{startDate:m.get(M),endDate:b.get(M)});let k=1/0,D=-1/0;for(const{startDate:M,endDate:L}of a.values()){const N=ye(M).getTime(),R=ye(L).getTime();N<k&&(k=N),R>D&&(D=R)}const E=ze(new Date(k)),C=ze(new Date(D)),A=s.daysBetween(E,C);return{scheduledTasks:a,violations:i,projectStart:E,projectEnd:C,totalDuration:A}}function Yr(e){const t={direction:"forward",respectWorkCalendar:!1,autoRun:!0,...e};let n,s,o=null,i=[];function a(){if(!t.respectWorkCalendar){s=fo();return}let p=null;_n(n,"calendar:addWorkDays","2026-01-05",1,r=>{p=r}),p!==null?s={addDays(r,l){let f=ho(r,l);return _n(n,"calendar:addWorkDays",r,l,T=>{f=T}),f},daysBetween(r,l){let f=go(r,l);return _n(n,"calendar:workDaysBetween",r,l,T=>{f=T}),f}}:s=fo()}function c(p){const r=n.getState(),l=Nn(r.tasks,r.dependencies,p?{...t,...p}:t,s);o=l;for(const[f,T]of l.scheduledTasks){const S=r.tasks.get(f);S&&(S.startDate!==T.startDate||S.endDate!==T.endDate)&&n.dispatch({type:"TASK_MOVE",taskId:f,startDate:T.startDate,endDate:T.endDate})}return l}function u(p){const r=n.getState(),l=Nn(r.tasks,r.dependencies,p?{...t,...p}:t,s);return o=l,l}function d(p){let r,l;for(const f of p)typeof f=="function"?l=f:f&&typeof f=="object"&&(r=f);return{overrides:r,callback:l}}function h(p,r){r(p),t.autoRun!==!1&&(p.type==="ADD_DEPENDENCY"||p.type==="REMOVE_DEPENDENCY")&&c()}return{name:"AutoSchedulePlugin",install(p){n=p,a(),i.push(n.on("autoSchedule:run",(...r)=>{const{overrides:l,callback:f}=d(r),T=c(l);f&&f(T)})),i.push(n.on("autoSchedule:preview",(...r)=>{const{overrides:l,callback:f}=d(r),T=u(l);f&&f(T)})),i.push(n.on("autoSchedule:result",(...r)=>{const l=r[0];l&&l(o)})),i.push(n.on("autoSchedule:setConstraint",(...r)=>{const l=r[0],f=r[1];t.constraints||(t.constraints=new Map),f?t.constraints.set(l,f):t.constraints.delete(l)})),i.push(n.on("autoSchedule:setConstraints",(...r)=>{const l=r[0];t.constraints=l}))},middleware:h,destroy(){for(const p of i)p();i=[],o=null}}}const Wr=864e5,Xr=75,zr=50,mo=25,zt=.3,Gt=.25,yo=.2,On=.15,Vt=.1,Gr=.3,bo=.5,Vr=20,To=40,Kr=3,jr=5,qr=30,vo=.25,So=4,Zr=2,Jr=5,Hn=5,wo=4,ko=.4,Qr=.003,Qe=260,pt=260,Do=16,Ge=14,el="rgba(30, 30, 46, 0.92)",xn="#e0e0e0",tl=10,Kt=32,nl=6,jt="#EF4444",qt="#F97316",Zt="#EAB308",Jt="#22C55E";function we(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ie(e,t){return Math.round((t.getTime()-e.getTime())/Wr)}function Ce(e,t,n){return Math.max(t,Math.min(n,e))}function sl(e){return e>=Xr?"critical":e>=zr?"high":e>=mo?"medium":"low"}function ol(e){switch(e){case"critical":return jt;case"high":return qt;case"medium":return Zt;case"low":return Jt}}function Qt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function il(e,t){const n=new Map,s=new Map;for(const g of e.keys())n.set(g,[]),s.set(g,[]);for(const g of t.values())!e.has(g.source)||!e.has(g.target)||(n.get(g.source).push(g.target),s.get(g.target).push(g.source));const o=new Map,i=new Set;function a(g){if(o.has(g))return o.get(g);if(i.has(g))return 0;i.add(g);let y=0;for(const v of n.get(g)||[])y+=1+a(v);return o.set(g,y),y}for(const g of e.keys())a(g);const c=new Map;for(const[g,y]of e){const v=we(y.startDate),m=we(y.endDate);c.set(g,Math.max(Ie(v,m),0))}const u=new Map,d=new Map,h=new Map;for(const g of e.keys())h.set(g,(s.get(g)||[]).length),u.set(g,c.get(g)||0),d.set(g,null);const p=[],r=new Map(h);for(const[g,y]of r)y===0&&p.push(g);for(;p.length>0;){const g=p.shift();for(const y of n.get(g)||[]){const v=u.get(g)+(c.get(y)||0);v>u.get(y)&&(u.set(y,v),d.set(y,g));const m=r.get(y)-1;r.set(y,m),m===0&&p.push(y)}}const l=new Set;let f=0,T=null;for(const[g,y]of u)y>f&&(f=y,T=g);let S=T;for(;S!==null;)l.add(S),S=d.get(S)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:l}}function al(e){const t=Qt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=we(o.startDate),a=we(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function rl(e,t,n){const s=[],o=Qt(),i=we(e.startDate),a=we(e.endDate),c=Math.max(Ie(i,a),1),u=Math.max(Ie(i,o),0),d=Math.max(Ie(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=Ie(a,o);p=Ce(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*zt)})}else{const D=d/c;D<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*zt)})):(p=Ce(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*zt)}))}let l=0;const f=Ce(u/c,0,1),T=f-h;T>bo?(l=Ce(Math.round(T*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(T*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(l*Gt)})):T>Gr?(l=Ce(Math.round(T*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(T*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(l*Gt)})):T>.1&&(l=Ce(Math.round(T*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(l*Gt)}));let S=0;const g=t.downstreamCount.get(e.id)||0,y=t.criticalPathIds.has(e.id);if(g>0){S=Ce(Math.round(Math.log2(g+1)*20),0,70),y&&(S=Ce(Math.round(S*1.5),0,100));const D=y?" (on critical path)":"";s.push({type:"dependency-chain",description:`${g} downstream dependent${g===1?"":"s"}${D}`,impact:Math.round(S*yo)})}let v=0;c>To?(v=60,s.push({type:"duration",description:`Long task (${c} days) — consider breaking into smaller deliverables`,impact:Math.round(v*On)})):c>Vr&&(v=35,s.push({type:"duration",description:`Medium-length task (${c} days) — monitor closely`,impact:Math.round(v*On)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*Vt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>jr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Vt)})):D.length>Kr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Vt)}))}const b=Ce(Math.round(p*zt+l*Gt+S*yo+v*On+m*Vt),0,100),w=sl(b);let k;return r&&h===0?k="Task is overdue with no progress — escalate immediately":r?k="Task is past its deadline — review scope or extend timeline":T>bo?k="Task is significantly behind schedule — investigate blockers":c>To&&h<vo?k="Large task with little progress — consider splitting into smaller work items":(w==="high"||w==="critical")&&(k="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:w,riskScore:b,factors:s,suggestion:k}}function ll(e,t,n,s,o){const i=Qt();let a=0,c=0,u=0;for(const[y,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;c++;const m=we(v.startDate),b=we(v.endDate),w=Math.max(Ie(m,b),1),k=Math.max(Ie(m,i),0),D=Ce(k/w,0,1);(v.progress??0)>=D-.1&&a++;const C=t.get(y);C&&(C.riskLevel==="high"||C.riskLevel==="critical")&&u++}const d=c>0?a/c:1;let h=0;for(const y of n.criticalPathIds){const v=e.get(y);if(!v||v.isCompleted)continue;const m=we(v.endDate);i.getTime()>m.getTime()&&(h+=Ie(m,i))}const p=[],r=[];for(const[y,v]of s.activeTasks)p.push(v.length),v.length>So&&r.push(y);let l=100;if(p.length>1){const y=p.reduce((v,m)=>v+m,0)/p.length;if(y>0){const v=p.reduce((b,w)=>b+(w-y)**2,0)/p.length,m=Math.sqrt(v)/y;l=Ce(Math.round(100-m*50),0,100)}}let f=100;if(c>0){let y=0,v=0,m=0;for(const b of e.values()){if(b.isCompleted)continue;const w=we(b.startDate),k=we(b.endDate),D=Math.max(Ie(w,k),1),E=Math.max(Ie(w,i),0),C=Ce(E/D,0,2);y+=b.progress??0,v+=C,m++}if(m>0){const b=y/m,w=v/m;if(w>0){const k=b/w;f=Ce(Math.round(k*100),0,100)}}}const T=d*100,S=Ce(100-h*10,0,100);return{overallScore:Ce(Math.round(T*.25+S*.25+l*.25+f*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function cl(e,t,n,s){const o=[],i=Qt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const l=we(r.endDate),f=Ie(l,i),T=r.progress??0;f>Jr&&T===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const l=we(r.startDate),f=we(r.endDate),T=Ie(l,f),S=r.progress??0;if(T>qr&&S<vo){const g=Math.ceil(T/15);o.push({type:"split",description:`"${r.name}" spans ${T} days — split into ${g} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const c=[],u=[];for(const[p,r]of n.activeTasks)r.length>So?c.push({assignee:p,taskIds:r}):r.length<Zr&&u.push(p);if(c.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of c){const l=r.filter(f=>!t.criticalPathIds.has(f));l.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:l,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const l=we(r.endDate),f=Ie(i,l);if(f>=0&&f<=5){const T=s.get(p);T&&T.riskScore>=mo&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>we(p.startDate).getTime()-we(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const l of r)h.add(`${l}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const l=d[p],f=d[r],T=we(l.endDate),S=we(f.startDate);if(T.getTime()<=S.getTime()&&!(h.has(`${l.id}->${f.id}`)||h.has(`${f.id}->${l.id}`))){const y=Ie(T,S);y>0&&o.push({type:"parallel",description:`"${l.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${y} days on the critical path`,taskIds:[l.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function dl(e,t,n,s,o,i,a){if(e.save(),i){const c=ko+(1-ko)*(.5+.5*Math.sin(a*Qr));e.globalAlpha=c}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function ul(e,t,n,s,o,i){const a=Math.PI*.75,c=Math.PI*2.25,u=c-a,d=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,c),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Jt:i>=50?Zt:i>=25?qt:jt;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=xn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function gl(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:jt,label:"Critical"},{count:o.high,color:qt,label:"High"},{count:o.medium,color:Zt,label:"Medium"},{count:o.low,color:Jt,label:"Low"}];let c=-Math.PI/2;for(const u of a){if(u.count===0)continue;const d=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,c,c+d),e.closePath(),e.fillStyle=u.color,e.fill(),c+=d}}function hl(e,t,n,s,o){const i=t-Qe-Do,a=n+Do;e.save(),e.beginPath();const c=tl;e.moveTo(i+c,a),e.lineTo(i+Qe-c,a),e.arcTo(i+Qe,a,i+Qe,a+c,c),e.lineTo(i+Qe,a+pt-c),e.arcTo(i+Qe,a+pt,i+Qe-c,a+pt,c),e.lineTo(i+c,a+pt),e.arcTo(i,a+pt,i,a+pt-c,c),e.lineTo(i,a+c),e.arcTo(i,a,i+c,a,c),e.closePath(),e.fillStyle=el,e.fill(),e.fillStyle=xn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Ge,a+Ge);const u=i+Ge+Kt+4,d=a+Ge+20+Kt+8;ul(e,u,d,Kt,nl,s.overallScore);const h=24,p=i+Qe-Ge-h-4,r=d;gl(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const l=r+h+8,f=[{count:o.critical,color:jt,label:"C"},{count:o.high,color:qt,label:"H"},{count:o.medium,color:Zt,label:"M"},{count:o.low,color:Jt,label:"L"}],T=28,S=p-f.length*T/2+T/2;for(let m=0;m<f.length;m++){const b=f[m],w=S+m*T;e.fillStyle=b.color,e.fillText(`${b.label}:${b.count}`,w,l)}const g=d+Kt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Ge,g);const y=g+18;e.font="10px sans-serif",e.fillStyle=xn,e.fillText("Recommendations:",i+Ge,y);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const b=v[m],w=y+14+m*16,k=b.type==="escalate"?"⚠":b.type==="split"?"✂":b.type==="reassign"?"⇄":b.type==="parallel"?"⇉":b.type==="add-buffer"?"⏱":"ℹ",D=34,E=b.description.length>D?b.description.substring(0,D-1)+"…":b.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${k} ${E}`,i+Ge,w)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Ge,y+14)),e.restore()}function fl(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function c(){const u=e.getState(),{tasks:d,dependencies:h}=u;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=il(d,h),r=al(d),l=new Map;for(const[f,T]of d)l.set(f,rl(T,p,r));n=l,o=cl(d,p,r,n),s=ll(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),c(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,d){d(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&c()},renderCanvas(u,d,h){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,l=d.scrollY,f=p,T=Date.now()-a;u.save(),u.beginPath(),u.rect(0,f,u.canvas.width,u.canvas.height-f),u.clip(),u.translate(-r,0);for(const S of h){const g=n.get(S.taskId);if(!g||g.riskLevel==="low")continue;const y=S.x,v=S.barY-l,m=S.width,b=S.barHeight;if(v+b<f||v>u.canvas.height||y+m<0)continue;const w=y+m-Hn-wo,k=v+Hn+wo,D=ol(g.riskLevel),E=g.riskLevel==="critical";dl(u,w,k,Hn,D,E,T)}if(u.restore(),i){const S={critical:0,high:0,medium:0,low:0};for(const g of n.values())S[g.riskLevel]++;u.save(),hl(u,u.canvas.width,p,s,S),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const $e=160,et=80,Bn=8,pl=240,ml=160,yl=100,bl=200,en=8,Eo=.1,Co=3,Tl=.001,vl=500,Sl=5,wl=864e5,kl={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function Io(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Dl(e,t){return Math.round((t.getTime()-e.getTime())/wl)}function Mo(e,t,n){return e+(t-e)*n}function tn(e,t,n){return Math.max(t,Math.min(n,e))}function Fn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function El(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const c of e.keys())s.set(c,[]),o.set(c,[]),i.set(c,0);for(const c of t.values())!e.has(c.source)||!e.has(c.target)||(s.get(c.source).push(c.target),o.get(c.target).push(c.source),i.set(c.target,(i.get(c.target)||0)+1));const a=[];for(const[c,u]of i)u===0&&(a.push(c),n.set(c,0));for(;a.length>0;){const c=a.shift(),u=n.get(c);for(const d of s.get(c)){const h=n.get(d),p=u+1;(h===void 0||p>h)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const c of e.keys())n.has(c)||n.set(c,0);return n}function Cl(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Il(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let c=0;c<a.length;c++)i.set(a[c],c);for(let a=0;a<Sl;a++){for(let c=1;c<e.length;c++){const u=e[c],d=new Map;for(const h of u){const p=o.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const l of p)r+=i.get(l)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let c=e.length-2;c>=0;c--){const u=e[c],d=new Map;for(const h of u){const p=s.get(h);if(p.size===0){d.set(h,i.get(h)??0);continue}let r=0;for(const l of p)r+=i.get(l)??0;d.set(h,r/p.size)}u.sort((h,p)=>(d.get(h)??0)-(d.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function Ml(e,t){const n=new Map;if(t==="radial")return Al(e);const s=t==="lr",o=s?pl:ml,i=s?yl:bl;for(let a=0;a<e.length;a++){const c=e[a],h=-((c.length-1)*i)/2;for(let p=0;p<c.length;p++){const r=c[p],l=h+p*i;s?n.set(r,{x:a*o,y:l}):n.set(r,{x:l,y:a*o})}}return n}function Al(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const c=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(c)*u,y:Math.sin(c)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let c=0;c<o.length;c++){const u=c*a-Math.PI/2;t.set(o[c],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function Mt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Rl(e,t){return e.color?e.color:e.status&&(t[e.status]||kl[e.status])||"#94A3B8"}function Ll(e){const t=Io(e.startDate),n=Io(e.endDate);return Math.max(Dl(t,n),0)}function Pl(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,c=null,u=null,d=new Map,h=[],p=null,r=0,l=0,f=1,T=!1,S=0,g=0,y=0,v=0,m=null,b=0,w=0,k=null,D=null,E=new Set,C=!1,A=0,M=0,L=0,N=0;function R(z,H){return{x:(z-r)/f,y:(H-l)/f}}function $(z,H){const{x:F,y:G}=R(z,H);for(const V of d.values()){const j=V.x,ne=V.y;if(F>=j&&F<=j+$e&&G>=ne&&G<=ne+et)return V}return null}function _(){const z=e.getState(),{tasks:H,dependencies:F,config:G}=z;if(H.size===0){d=new Map,h=[];return}p=vn(H,F);const V=El(H,F),j=Cl(V);Il(j,F,H);const ne=Ml(j,s);let oe=1/0,ae=-1/0,le=1/0,me=-1/0;for(const{x:ue,y:De}of ne.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+$e),le=Math.min(le,De),me=Math.max(me,De+et);const Se=(oe+ae)/2,Ae=(le+me)/2,Re=d;d=new Map;for(const[ue,De]of H){const Le=ne.get(ue);if(!Le)continue;const je=Le.x-Se,it=Le.y-Ae,Fe=Re.get(ue);d.set(ue,{id:ue,task:De,layer:V.get(ue)??0,orderInLayer:0,x:Fe?Fe.x:je,y:Fe?Fe.y:it,targetX:je,targetY:it,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of j)for(let De=0;De<ue.length;De++){const Le=d.get(ue[De]);Le&&(Le.orderInLayer=De)}h=[];for(const ue of F.values())!H.has(ue.source)||!H.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function U(z){const H=e.getState(),F=new Set;F.add(z);const G=new Map,V=new Map;for(const oe of H.tasks.keys())G.set(oe,[]),V.set(oe,[]);for(const oe of H.dependencies.values())!H.tasks.has(oe.source)||!H.tasks.has(oe.target)||(G.get(oe.source).push(oe.target),V.get(oe.target).push(oe.source));const j=[z];for(;j.length>0;){const oe=j.shift();for(const ae of V.get(oe)||[])F.has(ae)||(F.add(ae),j.push(ae))}const ne=[z];for(;ne.length>0;){const oe=ne.shift();for(const ae of G.get(oe)||[])F.has(ae)||(F.add(ae),ne.push(ae))}return F}function Y(){C&&cancelAnimationFrame(M),C=!0,A=performance.now(),K()}function K(){const z=performance.now()-A,H=tn(z/vl,0,1),F=1-Math.pow(1-H,3);let G=!1;for(const V of d.values()){if(V.isDragging)continue;const j=Math.abs(V.x-V.targetX),ne=Math.abs(V.y-V.targetY);j>.5||ne>.5?(V.x=Mo(V.x,V.targetX,F),V.y=Mo(V.y,V.targetY,F),G=!0):(V.x=V.targetX,V.y=V.targetY)}if(B(),G&&H<1)M=requestAnimationFrame(K);else{C=!1;for(const V of d.values())V.isDragging||(V.x=V.targetX,V.y=V.targetY);B()}}function B(){if(!i||!o)return;const z=e.getState(),{config:H}=z,F=H.theme,G=H.colorMap,V=F.timelineBg==="#1A202C"||F.gridBg==="#1A202C"||F.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(F.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=V?"#1A202C":"#F7F8FA",i.fillRect(0,0,L,N),i.save(),i.translate(r,l),i.scale(f,f);for(const j of h){const ne=d.get(j.sourceId),oe=d.get(j.targetId);if(!ne||!oe)continue;const ae=E.has(j.sourceId)&&E.has(j.targetId),le=k===j.sourceId||k===j.targetId,me=k!==null&&!le||D!==null&&!ae,Se=ne.x+$e,Ae=ne.y+et/2,Re=oe.x,ue=oe.y+et/2;i.save(),me?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),j.isCritical?(i.strokeStyle=F.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?V?"#A0AEC0":"#4A5568":V?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const De=(Se+Re)/2;i.beginPath(),i.moveTo(Se,Ae),i.quadraticCurveTo(De,Ae,(Se+Re)/2,(Ae+ue)/2),i.quadraticCurveTo(De,ue,Re,ue),i.stroke();const Le=Math.atan2(ue-(Ae+ue)/2,Re-De);i.beginPath(),i.moveTo(Re,ue),i.lineTo(Re-en*Math.cos(Le-Math.PI/6),ue-en*Math.sin(Le-Math.PI/6)),i.lineTo(Re-en*Math.cos(Le+Math.PI/6),ue-en*Math.sin(Le+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const je=j.dep.type||"FS",it=j.dep.lag||0,Fe=it!==0?`${je} +${it}d`:je!=="FS"?je:"";if(Fe&&!me){const Lt=(Se+Re)/2,ss=(Ae+ue)/2-8;i.font=`10px ${F.fontFamily}`,i.fillStyle=V?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Fe,Lt,ss)}i.restore()}for(const j of d.values()){const ne=k!==null&&k!==j.id&&!O(k,j.id)||D!==null&&!E.has(j.id),oe=k===j.id,ae=D===j.id,le=Rl(j.task,G),me=j.x,Se=j.y;i.save(),ne&&(i.globalAlpha=.25),j.isCritical&&!ne&&(i.save(),i.shadowColor=F.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Mt(i,me,Se,$e,et,Bn),i.fillStyle="transparent",i.fill(),i.restore()),Mt(i,me,Se,$e,et,Bn),i.fillStyle=V?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=F.selectionColor||"#3182CE",i.lineWidth=2,Mt(i,me-2,Se-2,$e+4,et+4,Bn+2),i.stroke()),i.font=`600 12px ${F.fontFamily}`,i.fillStyle=V?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ae=Fn(i,j.task.name,$e-20);i.fillText(Ae,me+10,Se+8);const Re=Se+26;i.beginPath(),i.arc(me+16,Re+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${F.fontFamily}`,i.fillStyle=V?"#A0AEC0":"#718096",i.textBaseline="top";const ue=j.task.status||"No status";i.fillText(Fn(i,ue,$e-40),me+24,Re);const De=Ll(j.task),Le=De===1?"1 day":`${De} days`;i.font=`10px ${F.fontFamily}`,i.fillStyle=V?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Le,me+10,Se+42),j.task.assignee&&(i.font=`10px ${F.fontFamily}`,i.fillStyle=V?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(Fn(i,j.task.assignee,$e/2-10),me+$e-10,Se+42));const je=j.task.progress??0,it=Se+et-6,Fe=$e-20,Lt=3;if(Mt(i,me+10,it,Fe,Lt,1.5),i.fillStyle=V?"#4A5568":"#E2E8F0",i.fill(),je>0){const ss=Math.max(Lt,Fe*tn(je,0,1));Mt(i,me+10,it,ss,Lt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),I(V,F.fontFamily)}function I(z,H){if(!i)return;const F={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${H}`,i.fillStyle=z?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${F[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,L-12,12),i.restore()}function O(z,H){for(const F of h)if(F.sourceId===z&&F.targetId===H||F.sourceId===H&&F.targetId===z)return!0;return!1}function P(z){c=z;const H=z.querySelector(".ng-timeline-panel");if(!H)return;u=H.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",H.appendChild(o);const F=o.getContext("2d");F&&(i=F,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",be),o.addEventListener("mouseup",X),o.addEventListener("mouseleave",te),o.addEventListener("dblclick",q),o.addEventListener("wheel",Q,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function x(){if(!o||!c)return;const z=c.querySelector(".ng-timeline-panel");z&&(L=z.clientWidth,N=z.clientHeight,o.width=Math.round(L*a),o.height=Math.round(N*a),o.style.width=`${L}px`,o.style.height=`${N}px`)}function W(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),x(),Z(),_();for(const z of d.values())z.x=z.targetX,z.y=z.targetY;B()}}function ee(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),k=null,D=null,E=new Set)}function Z(){r=L/2,l=N/2,f=1}function re(z){if(!o)return{x:0,y:0};const H=o.getBoundingClientRect();return{x:z.clientX-H.left,y:z.clientY-H.top}}function ge(z){const{x:H,y:F}=re(z),G=$(H,F);G?(m=G,G.isDragging=!0,b=R(H,F).x-G.x,w=R(H,F).y-G.y,D=G.id,E=U(G.id),e.dispatch({type:"SELECT_TASK",taskId:G.id}),B()):(T=!0,S=H,g=F,y=r,v=l,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),B()))}function be(z){if(!o)return;const{x:H,y:F}=re(z);if(m){const j=R(H,F);m.x=j.x-b,m.y=j.y-w,m.targetX=m.x,m.targetY=m.y,B();return}if(T){const j=H-S,ne=F-g;r=y+j,l=v+ne,B();return}const G=$(H,F),V=G?G.id:null;V!==k&&(k=V,o.style.cursor=k?"pointer":"default",B())}function X(z){m&&(m.isDragging=!1,m=null),T=!1}function te(z){m&&(m.isDragging=!1,m=null),T=!1,k&&(k=null,B())}function q(z){const{x:H,y:F}=re(z),G=$(H,F);if(G){const V=e.getState();V.tasks.get(G.id)&&V.config&&e.dispatch({type:"SELECT_TASK",taskId:G.id})}}function Q(z){if(z.preventDefault(),!o)return;const{x:H,y:F}=re(z),G=R(H,F),V=-z.deltaY*Tl;f=tn(f+V*f,Eo,Co);const j=R(H,F);r+=(j.x-G.x)*f,l+=(j.y-G.y)*f,B()}let se=0,de=0,ie=0;function fe(z){if(z.preventDefault(),!!o){if(z.touches.length===1){const H=z.touches[0],F=o.getBoundingClientRect(),G=H.clientX-F.left,V=H.clientY-F.top,j=$(G,V);j?(m=j,j.isDragging=!0,b=R(G,V).x-j.x,w=R(G,V).y-j.y,D=j.id,E=U(j.id),e.dispatch({type:"SELECT_TASK",taskId:j.id})):(T=!0,S=G,g=V,y=r,v=l),B()}else if(z.touches.length===2){T=!1,m&&(m.isDragging=!1,m=null);const H=z.touches[0],F=z.touches[1];se=Math.hypot(F.clientX-H.clientX,F.clientY-H.clientY),de=(H.clientX+F.clientX)/2,ie=(H.clientY+F.clientY)/2}}}function ce(z){if(z.preventDefault(),!o)return;const H=o.getBoundingClientRect();if(z.touches.length===1){const F=z.touches[0],G=F.clientX-H.left,V=F.clientY-H.top;if(m){const j=R(G,V);m.x=j.x-b,m.y=j.y-w,m.targetX=m.x,m.targetY=m.y,B()}else if(T){const j=G-S,ne=V-g;r=y+j,l=v+ne,B()}}else if(z.touches.length===2){const F=z.touches[0],G=z.touches[1],V=Math.hypot(G.clientX-F.clientX,G.clientY-F.clientY),j=(F.clientX+G.clientX)/2,ne=(F.clientY+G.clientY)/2,oe=j-H.left,ae=ne-H.top;if(se>0){const le=V/se,me=R(oe,ae);f=tn(f*le,Eo,Co);const Se=R(oe,ae);r+=(Se.x-me.x)*f,l+=(Se.y-me.y)*f}r+=j-de,l+=ne-ie,se=V,de=j,ie=ne,B()}}function Te(z){m&&(m.isDragging=!1,m=null),T=!1,se=0}function ve(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",be),o.removeEventListener("mouseup",X),o.removeEventListener("mouseleave",te),o.removeEventListener("dblclick",q),o.removeEventListener("wheel",Q),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),C&&(cancelAnimationFrame(M),C=!1)}return{name:"NetworkGraphPlugin",install(z){e=z,t.push(e.on("networkGraph:toggle",()=>{n?ee():W()})),t.push(e.on("networkGraph:layout",(...H)=>{const F=H[0];F!==s&&(s=F,n&&(_(),Y()))})),t.push(e.on("stateChange",()=>{n&&(_(),Y())}))},renderDOM(z,H){o||P(z),n&&(x(),B())},destroy(){for(const z of t)z();t=[],ve(),d=new Map,h=[],p=null,n=!1}}}const Ao=300,Ro="nimbus-gantt-config-panel",Un="nimbus-gantt-config-panel-styles",Lo=300,Yn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],$l=`
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
    transition: opacity ${Lo}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${Ao}px;
    width: ${Ao}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${Lo}ms ease;
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
`;function _l(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(Ro);return e?JSON.parse(e):{}}catch{return{}}}function Nl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(Ro,JSON.stringify(e))}catch{}}function Po(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function nn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ol(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=$l,document.head.appendChild(e)}function Hl(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function sn(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const c=document.createElement("span");c.className="ng-config-label",c.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);d.textContent=String(h),i(h)}),a.appendChild(c),a.appendChild(u),a.appendChild(d),a}function At(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let c=t;return i.addEventListener("click",()=>{c=!c,i.classList.toggle("ng-active",c),n(c)}),s.appendChild(o),s.appendChild(i),s}function on(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=$o(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function $o(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function xl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const c=[];function u(){if(!e)return;const k=e.getState();e.dispatch({type:"SET_SCROLL",x:k.scrollX,y:k.scrollY})}function d(k){Object.assign(t,k),Nl(t)}function h(k,D,E){k[D]=E}function p(k,D){if(!e)return;const E=e.getState();h(E.config,k,D),d({[k]:D}),u()}function r(k,D){if(!e)return;const E=e.getState();h(E.config.theme,k,D),u()}function l(k){if(!e)return;const D=Yn.find(C=>C.name===k);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),d({themePreset:k}),u()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function T(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function S(k,D){var z;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?T():f()}),k.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",T),k.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",k.appendChild(o)),o.innerHTML="";const C=document.createElement("div");C.className="ng-config-panel-header",C.innerHTML="<span>Configuration</span>";const A=document.createElement("button");A.className="ng-config-close",A.innerHTML="×",A.addEventListener("click",T),C.appendChild(A),o.appendChild(C);const M=g("Display Settings");M.appendChild(sn("Row height",24,60,E.rowHeight,2,H=>p("rowHeight",H))),M.appendChild(sn("Bar height",16,40,E.barHeight,2,H=>p("barHeight",H))),M.appendChild(sn("Grid width",0,500,E.gridWidth,10,H=>p("gridWidth",H))),M.appendChild(sn("Font size",10,16,E.theme.fontSize,1,H=>{h(D.config.theme,"fontSize",H),d({fontSize:H}),u()})),M.appendChild(At("Today marker",E.showToday,H=>{h(D.config,"showToday",H),d({showToday:H}),u()})),M.appendChild(At("Weekends",E.showWeekends,H=>{h(D.config,"showWeekends",H),d({showWeekends:H}),u()})),M.appendChild(At("Progress bars",E.showProgress,H=>{h(D.config,"showProgress",H),d({showProgress:H}),u()})),M.appendChild(At("Dependency arrows",a,H=>{a=H,d({showDependencies:H}),u()})),M.appendChild(At("Labels on bars",t.showBarLabels!==!1,H=>{d({showBarLabels:H}),u()})),o.appendChild(M);const L=g("Color Theme"),N=document.createElement("div");N.className="ng-config-row";const R=document.createElement("span");R.className="ng-config-label",R.textContent="Preset";const $=document.createElement("select");$.className="ng-config-select";const _=document.createElement("option");_.value="",_.textContent="Custom",$.appendChild(_);for(const H of Yn){const F=document.createElement("option");F.value=H.name,F.textContent=H.name,t.themePreset===H.name&&(F.selected=!0),$.appendChild(F)}$.addEventListener("change",()=>{$.value&&l($.value)}),N.appendChild(R),N.appendChild($),L.appendChild(N),L.appendChild(on("Bar default",E.theme.barDefaultColor,H=>{r("barDefaultColor",H),d({customColors:{...t.customColors,barDefault:H}})})),L.appendChild(on("Today line",E.theme.todayLineColor,H=>{r("todayLineColor",H),d({customColors:{...t.customColors,todayLine:H}})})),L.appendChild(on("Grid lines",E.theme.timelineGridColor,H=>{r("timelineGridColor",H),d({customColors:{...t.customColors,gridLines:H}})})),L.appendChild(on("Background",E.theme.timelineBg,H=>{r("timelineBg",H),d({customColors:{...t.customColors,background:H}})}));const U=document.createElement("div");U.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",U.textContent="Status Color Map",L.appendChild(U);const Y={...E.colorMap,...t.statusColorMap},K=document.createElement("div");function B(){K.innerHTML="";const H=Object.entries(Y);for(const[G,V]of H){const j=document.createElement("div");j.className="ng-config-color-map-entry";const ne=document.createElement("input");ne.className="ng-config-color-map-status",ne.value=G,ne.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=$o(V),oe.addEventListener("input",()=>{Y[G]=oe.value,E.colorMap[G]=oe.value,d({statusColorMap:{...Y}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete Y[G],delete E.colorMap[G],d({statusColorMap:{...Y}}),B(),u()}),j.appendChild(ne),j.appendChild(oe),j.appendChild(ae),K.appendChild(j)}const F=document.createElement("button");F.className="ng-config-color-map-add",F.textContent="+ Add status color",F.addEventListener("click",()=>{const G=prompt("Status name:");!G||G.trim()===""||(Y[G.trim()]="#3b82f6",E.colorMap[G.trim()]="#3b82f6",d({statusColorMap:{...Y}}),B(),u())}),K.appendChild(F)}B(),L.appendChild(K),o.appendChild(L);const I=g("Zoom & Time"),O=document.createElement("div");O.className="ng-config-row";const P=document.createElement("span");P.className="ng-config-label",P.textContent="Zoom";const x=document.createElement("div");x.className="ng-config-zoom-group";const W=["day","week","month","quarter"];for(const H of W){const F=document.createElement("button");F.className="ng-config-zoom-btn"+(D.zoomLevel===H?" ng-active":""),F.textContent=H.charAt(0).toUpperCase()+H.slice(1),F.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:H}),d({zoomLevel:H}),x.querySelectorAll(".ng-config-zoom-btn").forEach(G=>G.classList.toggle("ng-active",G===F)))}),x.appendChild(F)}O.appendChild(P),O.appendChild(x),I.appendChild(O);const ee=document.createElement("div");ee.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=Po(D.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const H=nn(re.value),F=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:H,end:F}),d({dateRangeStart:re.value})}),ee.appendChild(Z),ee.appendChild(re),I.appendChild(ee);const ge=document.createElement("div");ge.className="ng-config-row";const be=document.createElement("span");be.className="ng-config-label",be.textContent="End date";const X=document.createElement("input");X.type="date",X.className="ng-config-date-input",X.value=Po(D.dateRange.end),X.addEventListener("change",()=>{if(!e||!X.value)return;const H=e.getState().dateRange.start,F=nn(X.value);e.dispatch({type:"SET_DATE_RANGE",start:H,end:F}),d({dateRangeEnd:X.value})}),ge.appendChild(be),ge.appendChild(X),I.appendChild(ge);const te=document.createElement("div");te.style.cssText="margin-top: 8px;";const q=document.createElement("button");q.className="ng-config-btn ng-primary",q.textContent="Fit to View",q.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),te.appendChild(q),I.appendChild(te),o.appendChild(I);const Q=g("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),y("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>y("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&b(e.getState())}),se.appendChild(ce),Q.appendChild(se),o.appendChild(Q);const Te=g("Plugin Toggles"),ve=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const H of ve){const F=document.createElement("div");F.className="ng-config-plugin-row";const G=document.createElement("span");G.className="ng-config-plugin-name",G.textContent=H.label;const V=((z=t.pluginToggles)==null?void 0:z[H.key])!==!1,j=document.createElement("span");j.className="ng-config-plugin-status"+(V?" ng-active-status":""),j.textContent=V?"Active":"Inactive";const ne=document.createElement("div");ne.className="ng-config-toggle"+(V?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",ne.appendChild(oe);let ae=V;ne.addEventListener("click",()=>{ae=!ae,ne.classList.toggle("ng-active",ae),j.className="ng-config-plugin-status"+(ae?" ng-active-status":""),j.textContent=ae?"Active":"Inactive";const me={...t.pluginToggles,[H.key]:ae};d({pluginToggles:me}),y(H.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(G),le.appendChild(j),F.appendChild(le),F.appendChild(ne),Te.appendChild(F)}o.appendChild(Te)}function g(k){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=k,D.appendChild(E),D}function y(k){e&&v.forEach(D=>D(k))}const v=[];function m(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],C=D.map(R=>[R.id,`"${(R.name||"").replace(/"/g,'""')}"`,R.startDate,R.endDate,String(Math.round((R.progress??0)*100))+"%",R.status||"",R.assignee||"",R.priority||"",R.groupName||""]),A=[E.join(","),...C.map(R=>R.join(","))].join(`
`),M=new Blob([A],{type:"text/csv;charset=utf-8;"}),L=URL.createObjectURL(M),N=document.createElement("a");N.href=L,N.download="gantt-tasks.csv",document.body.appendChild(N),N.click(),document.body.removeChild(N),URL.revokeObjectURL(L)}function b(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],C=D.map(L=>[L.name,L.startDate,L.endDate,Math.round((L.progress??0)*100)+"%",L.status||"",L.assignee||""]),M=[E.join("	"),...C.map(L=>L.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(M).catch(()=>{})}function w(k){const D=t;if(D.rowHeight!==void 0&&h(k.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&h(k.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&h(k.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&h(k.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&h(k.config,"showToday",D.showToday),D.showWeekends!==void 0&&h(k.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&h(k.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=Yn.find(C=>C.name===D.themePreset);E&&Object.assign(k.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&h(k.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&h(k.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&h(k.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&h(k.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(k.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:nn(D.dateRangeStart),end:nn(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(k){e=k,Ol(),t=_l();const D=k.on("render",()=>{D(),w(k.getState()),u()});c.push(D);const E=k.on("config:open",()=>f()),C=k.on("config:close",()=>T()),A=k.on("config:toggle",()=>{i?T():f()});c.push(E,C,A)},renderDOM(k,D){S(k,D)},destroy(){c.forEach(k=>k()),c.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Hl(),e=null,i=!1}}}const _o=864e5,Wn="nimbus-gantt-heatmap-styles",ke=28,_e=2,tt=48,Ne=160,Bl=3,No="#1e1e2e",Oo="#166534",Ho="#a16207",xo="#b91c1c",Fl=`
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
`;function Bo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ul(e){return String(e.getUTCDate())}function Yl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Wl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fo(e,t){return Math.round((t.getTime()-e.getTime())/_o)}function Uo(e,t){return new Date(e.getTime()+t*_o)}function mt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Xl(e,t){return e===0?No:e===1?Oo:e===2?Ho:xo}function zl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Gl(){if(typeof document>"u"||document.getElementById(Wn))return;const e=document.createElement("style");e.id=Wn,e.textContent=Fl,document.head.appendChild(e)}function Vl(){if(typeof document>"u")return;const e=document.getElementById(Wn);e&&e.remove()}function Kl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Fo(o,i)+1,c=[];for(let h=0;h<a;h++)c.push(Uo(o,h));const u=new Map;let d=0;for(const h of s)for(const p of c){const r=`${h}|${mt(p)}`;u.set(r,{assignee:h,date:p,dateKey:mt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=Bo(h.startDate),l=Bo(h.endDate),f=Fo(r,l)+1;for(let T=0;T<f;T++){const S=Uo(r,T),g=`${p}|${mt(S)}`,y=u.get(g);y&&(y.tasks.push(h),y.count++,y.count>d&&(d=y.count))}}return{assignees:s,dates:c,cells:u,maxCount:d}}function jl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function c(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=Kl(p);let l=t.querySelector(".ng-heatmap-grid-wrapper");l||(l=document.createElement("div"),l.className="ng-heatmap-grid-wrapper",t.appendChild(l)),l.innerHTML="";const f=document.createElement("canvas"),T=Ne+r.dates.length*(ke+_e),S=tt+r.assignees.length*(ke+_e),g=window.devicePixelRatio||1;f.width=T*g,f.height=S*g,f.style.width=T+"px",f.style.height=S+"px",f.style.cursor="pointer";const y=f.getContext("2d");y.scale(g,g),y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle";let v="",m=Ne;for(let b=0;b<r.dates.length;b++){const w=r.dates[b],k=Yl(w),D=Ne+b*(ke+_e);if(k!==v){if(v&&b>0){const E=(m+D)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,E,12)}m=D,v=k}}if(v){const b=Ne+r.dates.length*(ke+_e),w=(m+b)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,w,12)}y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let b=0;b<r.dates.length;b++){const w=r.dates[b],k=Ne+b*(ke+_e)+ke/2,D=w.getUTCDay()===0||w.getUTCDay()===6;y.fillStyle=D?"#475569":"#64748b",y.fillText(Ul(w),k,32)}y.beginPath(),y.strokeStyle="#1e293b",y.lineWidth=1,y.moveTo(0,tt-.5),y.lineTo(T,tt-.5),y.stroke();for(let b=0;b<r.assignees.length;b++){const w=r.assignees[b],k=tt+b*(ke+_e);y.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="left",y.textBaseline="middle",y.fillStyle="#cbd5e1",y.save(),y.beginPath(),y.rect(0,k,Ne-8,ke),y.clip(),y.fillText(w,8,k+ke/2),y.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],C=`${w}|${mt(E)}`,A=r.cells.get(C),M=(A==null?void 0:A.count)??0,L=Ne+D*(ke+_e),N=Xl(M),R=zl(M,r.maxCount);y.globalAlpha=R,y.fillStyle=N,h(y,L,k,ke,ke,Bl),y.fill(),M>=2&&(y.globalAlpha=1,y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle",y.fillStyle="#fff",y.fillText(String(M),L+ke/2,k+ke/2)),y.globalAlpha=1}}l.appendChild(f),f.addEventListener("mousemove",b=>{if(!n)return;const w=f.getBoundingClientRect(),k=b.clientX-w.left,D=b.clientY-w.top,E=Math.floor((k-Ne)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Ne||D<tt){n.classList.remove("ng-visible");return}const A=r.dates[E],M=r.assignees[C],L=`${M}|${mt(A)}`,N=r.cells.get(L);if(!N||N.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const R=document.createElement("div");R.className="ng-heatmap-tooltip-date",R.textContent=`${M} - ${Wl(A)}`,n.appendChild(R);for(const U of N.tasks){const Y=document.createElement("div");Y.className="ng-heatmap-tooltip-task",Y.textContent=`• ${U.name}`,n.appendChild(Y)}n.classList.add("ng-visible");const $=b.clientX+12,_=b.clientY+12;n.style.left=$+"px",n.style.top=_+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",b=>{if(!e)return;const w=f.getBoundingClientRect(),k=b.clientX-w.left,D=b.clientY-w.top,E=Math.floor((k-Ne)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Ne||D<tt)return;const A=r.dates[E],L=`${r.assignees[C]}|${mt(A)}`,N=r.cells.get(L);if(!(!N||N.count===0)){u();for(const R of N.tasks)e.dispatch({type:"SELECT_TASK",taskId:R.id,multi:!0})}})}function h(p,r,l,f,T,S){p.beginPath(),p.moveTo(r+S,l),p.lineTo(r+f-S,l),p.quadraticCurveTo(r+f,l,r+f,l+S),p.lineTo(r+f,l+T-S),p.quadraticCurveTo(r+f,l+T,r+f-S,l+T),p.lineTo(r+S,l+T),p.quadraticCurveTo(r,l+T,r,l+T-S),p.lineTo(r,l+S),p.quadraticCurveTo(r,l,r+S,l),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Gl();const r=p.on("heatmap:toggle",()=>a()),l=p.on("heatmap:show",()=>c()),f=p.on("heatmap:hide",()=>u());i.push(r,l,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const l=document.createElement("div");l.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",l.appendChild(f);const T=document.createElement("div");T.className="ng-heatmap-legend";const S=[{color:No,label:"None"},{color:Oo,label:"1 task"},{color:Ho,label:"2 tasks"},{color:xo,label:"3+ tasks"}];for(const y of S){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=y.color,T.appendChild(v);const m=document.createElement("span");m.textContent=y.label,T.appendChild(m)}l.appendChild(T);const g=document.createElement("button");g.className="ng-heatmap-close",g.textContent="Back to Gantt",g.addEventListener("click",u),l.appendChild(g),t.appendChild(l),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Vl(),e=null,s=!1,o=null}}}const nt=200,st=80,Yo=12,Wo=6,ql="rgba(255, 255, 255, 0.95)",Zl="#cbd5e1",Jl="rgba(59, 130, 246, 0.3)",Ql="rgba(59, 130, 246, 0.7)",ec=1.5,tc=2,nc=1,Xn="nimbus-gantt-minimap-styles",sc=864e5,oc=`
  .ng-minimap {
    position: absolute;
    bottom: ${Yo}px;
    right: ${Yo}px;
    width: ${nt}px;
    height: ${st}px;
    z-index: 900;
    border-radius: ${Wo}px;
    border: 1px solid ${Zl};
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
    border-radius: ${Wo}px;
  }
`;function ic(){if(typeof document>"u"||document.getElementById(Xn))return;const e=document.createElement("style");e.id=Xn,e.textContent=oc,document.head.appendChild(e)}function ac(){if(typeof document>"u")return;const e=document.getElementById(Xn);e&&e.remove()}function rc(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let c=1,u=1,d=0,h=0,p=0,r=0;function l(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function T(){o=!1,t&&t.classList.add("ng-hidden")}function S(b,w){const k=b/c-p/2,D=w/u-r/2;return{x:Math.max(0,Math.min(k,d-p)),y:Math.max(0,Math.min(D,h-r))}}function g(b){if(!e||!n)return;b.preventDefault(),i=!0;const w=n.getBoundingClientRect(),k=b.clientX-w.left,D=b.clientY-w.top,E=S(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function y(b){if(!i||!e||!n)return;b.preventDefault();const w=n.getBoundingClientRect(),k=Math.max(0,Math.min(b.clientX-w.left,nt)),D=Math.max(0,Math.min(b.clientY-w.top,st)),E=S(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function v(){i=!1}function m(b,w){if(!s||!n||!o)return;const k=window.devicePixelRatio||1;n.width=nt*k,n.height=st*k,n.style.width=nt+"px",n.style.height=st+"px",s.scale(k,k);const{config:D,scrollX:E,scrollY:C,dateRange:A}=b,M=e.getTimeScale(),L=Math.round((A.end.getTime()-A.start.getTime())/sc),N=M.getColumnWidth();if(d=Math.max(L*N,1),h=Math.max(b.flatVisibleIds.length*D.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const P=t.parentElement;p=P.clientWidth-D.gridWidth,r=P.clientHeight-D.headerHeight}c=nt/Math.max(d,1),u=st/Math.max(h,1),s.fillStyle=ql,s.fillRect(0,0,nt,st);const R=new Map;for(const P of w)R.has(P.rowIndex)||R.set(P.rowIndex,[]),R.get(P.rowIndex).push(P);for(const P of w){const x=P.x*c,W=Math.max(P.width*c,1),ee=P.rowIndex*D.rowHeight*u;s.fillStyle=P.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(x,ee,W,Math.max(tc,D.rowHeight*u-nc))}s.globalAlpha=1;const $=E*c,_=C*u,U=p*c,Y=r*u,K=Math.max(0,Math.min($,nt-1)),B=Math.max(0,Math.min(_,st-1)),I=Math.min(U,nt-K),O=Math.min(Y,st-B);s.fillStyle=Jl,s.fillRect(K,B,I,O),s.strokeStyle=Ql,s.lineWidth=ec,s.strokeRect(K,B,I,O)}return{name:"MiniMapPlugin",install(b){e=b,ic();const w=b.on("minimap:toggle",()=>l()),k=b.on("minimap:show",()=>f()),D=b.on("minimap:hide",()=>T());a.push(w,k,D),typeof document<"u"&&(document.addEventListener("mousemove",y),document.addEventListener("mouseup",v))},renderDOM(b,w){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",g),t.appendChild(n),b.appendChild(t));const k=(e==null?void 0:e.getLayouts())??[];m(w,k)},destroy(){a.forEach(b=>b()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",y),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,ac(),e=null,o=!0,i=!1}}}const lc="#f59e0b",cc=[6,4],dc=1,lt=16,uc=4,gc="rgba(15, 23, 42, 0.95)",hc="#e2e8f0",fc="#334155",pc=6,ct=10,Xo=220,zo=12,Go=13;function mc(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Rt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function yc(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Rt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function bc(e,t,n,s,o){const i=s/2,a=i*.4,c=5;e.beginPath();for(let u=0;u<c*2;u++){const d=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/c*u,p=t+Math.cos(h)*d,r=n+Math.sin(h)*d;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke()}function Tc(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function vc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Sc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Vo={flag:yc,star:bc,warning:Tc,info:vc,deadline:Sc};function wc(e,t,n,s,o){e.save();const i=`${zo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Go}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const c=e.measureText(t.label).width;e.font=i;const u=[];let d=0;if(t.description){const S=t.description.split(" ");let g="";for(const y of S){const v=g?g+" "+y:y;e.measureText(v).width>Xo-ct*2&&g?(u.push(g),d=Math.max(d,e.measureText(g).width),g=y):g=v}g&&(u.push(g),d=Math.max(d,e.measureText(g).width))}const h=Math.min(Xo,Math.max(c,d)+ct*2),p=zo+4,r=Go+4,l=ct*2+r+(u.length>0?4+u.length*p:0);let f=n-h/2;const T=s-l-8;if(f<4&&(f=4),f+h>o-4&&(f=o-h-4),e.beginPath(),kc(e,f,T,h,l,pc),e.fillStyle=gc,e.fill(),e.strokeStyle=fc,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=hc,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+ct,T+ct),u.length>0){e.font=i,e.fillStyle="#94a3b8";let S=T+ct+r+4;for(const g of u)e.fillText(g,f+ct,S),S+=p}e.restore()}function kc(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Dc(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,c=-1,u=null,d=null;function h(g){return n.find(y=>y.id===g)}function p(g){n.push(g),T()}function r(g){n=n.filter(y=>y.id!==g),T()}function l(g,y){const v=h(g);v&&(Object.assign(v,y),T())}function f(){return[...n]}function T(){if(!t)return;const g=t.getState();t.dispatch({type:"SET_SCROLL",x:g.scrollX,y:g.scrollY})}function S(g){const y=g.canvas;d!==y&&(d&&u&&d.removeEventListener("mousemove",u),d=y,u=v=>{const m=y.getBoundingClientRect();a=v.clientX-m.left,c=v.clientY-m.top;let b=null;for(const w of o){const k=a-w.x,D=c-w.y;if(Math.sqrt(k*k+D*D)<=w.size){b=w.note.id;break}}b!==s&&(s=b,y.style.cursor=s?"pointer":"",T())},y.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(g){t=g;const y=g.on("notes:add",(...w)=>{const k=w[0];k&&k.id&&k.date&&k.label&&p(k)}),v=g.on("notes:remove",(...w)=>{const k=w[0];k&&r(k)}),m=g.on("notes:update",(...w)=>{const k=w[0];if(k&&k.id){const{id:D,...E}=k;l(D,E)}}),b=g.on("notes:list",(...w)=>{const k=w[0];typeof k=="function"&&k(f())});i.push(y,v,m,b)},renderCanvas(g,y,v){if(!t||n.length===0)return;const{config:m,scrollX:b,scrollY:w,dateRange:k}=y,{theme:D}=m,E=m.headerHeight,C=t.getTimeScale();S(g);const A=g.canvas.width/(window.devicePixelRatio||1),M=g.canvas.height/(window.devicePixelRatio||1),L=E,N=M-L;o=[],g.save();for(const R of n){const $=mc(R.date);if($<k.start||$>k.end)continue;const _=R.color||lc,U=R.icon||"flag",Y=C.dateToX($)-b;if(Y<-lt||Y>A+lt)continue;g.save(),g.beginPath(),g.setLineDash(cc),g.strokeStyle=_,g.globalAlpha=.5,g.lineWidth=dc,g.moveTo(Y,L),g.lineTo(Y,L+N),g.stroke(),g.setLineDash([]),g.globalAlpha=1,g.restore();const K=Y,B=L+uc+lt/2,I=Vo[U]||Vo.flag;g.save(),g.beginPath(),g.arc(K,B,lt/2+3,0,Math.PI*2),g.fillStyle="rgba(0, 0, 0, 0.4)",g.fill(),g.restore(),g.save(),I(g,K,B,lt,_),g.restore(),o.push({note:R,x:K,y:B,size:lt/2+4}),s===R.id&&wc(g,R,K,B-lt/2-4,A)}g.restore()},destroy(){i.forEach(g=>g()),i.length=0,d&&u&&d.removeEventListener("mousemove",u),t=null,d=null,u=null,s=null,o=[]}}}const Ec=500,Cc=40,Ko=7,jo=3,qo=5,Ic=500,zn="nimbus-gantt-timetravel-styles",Zo={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Mc=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Cc}px;
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
    width: ${Ko*2}px;
    height: ${Ko*2}px;
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
    width: ${jo*2}px;
    height: ${jo*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${qo*2}px;
    height: ${qo*2}px;
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
`;function Ac(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Rc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Lc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function Pc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function $c(){if(typeof document>"u"||document.getElementById(zn))return;const e=document.createElement("style");e.id=zn,e.textContent=Mc,document.head.appendChild(e)}function _c(){if(typeof document>"u")return;const e=document.getElementById(zn);e&&e.remove()}const Jo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),an=[.5,1,2,4];function Nc(e){const t=(e==null?void 0:e.maxSnapshots)??Ec,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,c=!1,u=null,d=1;const h=[];let p=null,r=null,l=null,f=null,T=null,S=null,g=null,y=!1;function v(B){if(!s||a)return;const I=s.getState(),O=Lc(I,B);i<o.length-1&&(o.length=i+1),o.push(O),o.length>t&&o.shift(),i=o.length-1}function m(B){if(!s||o.length===0)return;const I=Math.max(0,Math.min(B,o.length-1));i=I;const O=o[I];a=!0;const P=O.tasks.map(W=>({id:W.id,name:W.name,startDate:W.startDate,endDate:W.endDate,progress:W.progress,status:W.status})),x=O.dependencies.map(W=>({id:W.id,source:W.source,target:W.target}));s.dispatch({type:"SET_DATA",tasks:P,dependencies:x}),a=!1,L()}function b(){o.length>0&&m(o.length-1),k()}function w(){if(c||o.length<=1)return;c=!0;const B=an[d],I=Ic/B;u=setInterval(()=>{if(i>=o.length-1){k();return}m(i+1)},I),L()}function k(){c=!1,u!==null&&(clearInterval(u),u=null),L()}function D(){c?k():w()}function E(){d=(d+1)%an.length,c&&(k(),w()),L()}function C(){k(),i>0&&m(i-1)}function A(){k(),i<o.length-1&&m(i+1)}function M(){k(),o.length=0,i=-1,a=!1,L()}function L(){if(p){if(f){const B=o.length,I=B>0?i+1:0;f.textContent=`${I} / ${B}`}T&&(T.textContent=c?"⏸":"▶",T.classList.toggle("ng-active",c)),S&&(S.textContent=`${an[d]}x`),N(),R()}}function N(){if(!l||!r||o.length===0){l&&(l.style.display="none");return}l.style.display="block";const B=o.length<=1?50:i/(o.length-1)*100;l.style.left=`${B}%`}function R(){if(!g||!r||(g.innerHTML="",o.length===0))return;const B=200,I=o.length>B?Math.ceil(o.length/B):1;for(let O=0;O<o.length;O+=I){const P=o[O],x=o.length<=1?50:O/(o.length-1)*100,W=Ac(P.action.split(" ")[0]==="Loaded"?"SET_DATA":$(P.action)),ee=Zo[W]||Zo.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${x}%`,Z.style.background=ee;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${P.action}
${Pc(P.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=O;Z.addEventListener("click",be=>{be.stopPropagation(),k(),m(ge)}),g.appendChild(Z)}}function $(B){return B.startsWith("Moved")?"TASK_MOVE":B.startsWith("Resized")?"TASK_RESIZE":B.startsWith("Added task")?"ADD_TASK":B.startsWith("Added dependency")?"ADD_DEPENDENCY":B.startsWith("Removed task")?"REMOVE_TASK":B.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":B.startsWith("Updated")?"UPDATE_TASK":(B.startsWith("Loaded"),"SET_DATA")}function _(B){if(!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(B.clientX-I.left)/I.width)),P=Math.round(O*(o.length-1));k(),m(P)}function U(B){B.preventDefault(),B.stopPropagation(),y=!0,l&&l.classList.add("ng-dragging"),k()}function Y(B){if(!y||!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(B.clientX-I.left)/I.width)),P=Math.round(O*(o.length-1));m(P)}function K(){y&&(y=!1,l&&l.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(B){s=B,$c(),h.push(B.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),B.on("timeTravel:scrub",(...I)=>{const O=I[0];k(),m(O)}),B.on("timeTravel:play",()=>w()),B.on("timeTravel:pause",()=>k()),B.on("timeTravel:present",()=>b()),B.on("timeTravel:clear",()=>M()),B.on("timeTravel:history",(...I)=>{const O=I[0];typeof O=="function"&&O([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",Y),document.addEventListener("mouseup",K))},middleware(B,I){let O="";n&&Jo.has(B.type)&&s&&!a&&(O=Rc(B,s.getState())),I(B),n&&Jo.has(B.type)&&!a&&O&&v(O)},renderDOM(B,I){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const O=document.createElement("button");O.className="ng-timetravel-btn",O.textContent="◀",O.title="Step backward",O.addEventListener("click",()=>C()),p.appendChild(O),T=document.createElement("button"),T.className="ng-timetravel-btn",T.textContent="▶",T.title="Play / Pause",T.addEventListener("click",()=>D()),p.appendChild(T);const P=document.createElement("button");P.className="ng-timetravel-btn",P.textContent="▶",P.title="Step forward",P.addEventListener("click",()=>A()),p.appendChild(P),S=document.createElement("span"),S.className="ng-timetravel-speed ng-timetravel-btn",S.textContent=`${an[d]}x`,S.title="Click to cycle speed",S.addEventListener("click",()=>E()),p.appendChild(S),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",_);const x=document.createElement("div");x.className="ng-timetravel-rail",r.appendChild(x),g=document.createElement("div"),g.style.position="absolute",g.style.inset="0",r.appendChild(g),l=document.createElement("div"),l.className="ng-timetravel-playhead",l.addEventListener("mousedown",U),r.appendChild(l),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const W=document.createElement("button");W.className="ng-timetravel-btn ng-present",W.textContent="Present",W.title="Return to latest state",W.addEventListener("click",()=>b()),p.appendChild(W),B.appendChild(p)}L()},destroy(){k();for(const B of h)B();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",Y),document.removeEventListener("mouseup",K)),p&&(p.remove(),p=null),r=null,l=null,f=null,T=null,S=null,g=null,_c(),o.length=0,i=-1,a=!1,c=!1,y=!1,s=null}}}const Qo=864e5,Oc=60,Hc=2,ei=[6,4],Gn="nimbus-gantt-montecarlo-styles",ti={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},xc=.08,Bc=`
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
`;function Vn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function rn(e,t){return Math.round((t.getTime()-e.getTime())/Qo)}function dt(e,t){return new Date(e.getTime()+t*Qo)}function ni(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function si(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Uc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Yc(e,t){return e+Math.random()*(t-e)}function Wc(e,t,n,s,o,i,a,c){const u=e.length;if(u===0)return 0;const d=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(c),r=[];for(let T=0;T<u;T++)p[T]===0&&(r.push(T),d[T]=o[T],h[T]=o[T]+s[T]);let l=0;for(;l<r.length;){const T=r[l++],S=h[T],g=i[T];for(let y=0;y<g.length;y++){const v=g[y];S>d[v]&&(d[v]=S,h[v]=S+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let T=0;T<u;T++)h[T]===0&&s[T]>0&&(d[T]=o[T],h[T]=o[T]+s[T]);let f=0;for(let T=0;T<u;T++)h[T]>f&&(f=h[T]);return f}function Xc(e,t,n,s,o,i){const a=new Float64Array(e),c=new Float64Array(e),u=new Float64Array(e),d=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let S=0;S<e;S++)h[S]===0&&(r.push(S),a[S]=n[S],c[S]=n[S]+t[S]);let l=0;for(;l<r.length;){const S=r[l++];p.push(S);const g=c[S];for(const y of s[S])g>a[y]&&(a[y]=g,c[y]=g+t[y]),h[y]--,h[y]===0&&r.push(y)}for(let S=0;S<e;S++)c[S]===0&&t[S]>0&&(a[S]=n[S],c[S]=n[S]+t[S],p.push(S));let f=0;for(let S=0;S<e;S++)c[S]>f&&(f=c[S]);for(let S=0;S<e;S++)s[S].length===0?(d[S]=f,u[S]=f-t[S]):(d[S]=1/0,u[S]=1/0);for(let S=p.length-1;S>=0;S--){const g=p[S];if(d[g]===1/0){let y=1/0;for(const v of s[g])u[v]<y&&(y=u[v]);y===1/0?d[g]=f:d[g]=y,u[g]=d[g]-t[g]}}const T=new Set;for(let S=0;S<e;S++){const g=u[S]-a[S];Math.abs(g)<.5&&T.add(S)}return T}function zc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,c=[],u=new Map;for(const x of e.keys())u.set(x,c.length),c.push(x);const d=c.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const x of e.values()){const W=Vn(x.startDate).getTime();W<r&&(r=W)}const l=new Date(r);for(let x=0;x<d;x++){const W=e.get(c[x]),ee=Vn(W.startDate),Z=Vn(W.endDate);h[x]=Math.max(rn(ee,Z),1),p[x]=rn(l,ee)}const f=Array.from({length:d},()=>[]),T=Array.from({length:d},()=>[]),S=new Int32Array(d);for(const x of t.values()){if((x.type||"FS")!=="FS")continue;const ee=u.get(x.source),Z=u.get(x.target);ee===void 0||Z===void 0||(f[ee].push(Z),T[Z].push(ee),S[Z]++)}const g=f.map(x=>new Int32Array(x)),y=T.map(x=>new Int32Array(x)),v=new Float64Array(s),m=new Float64Array(d),b=new Float64Array(d),w=new Float64Array(d),k=new Float64Array(d),D=new Float64Array(d),E=Math.max(1,Math.floor(s/100));for(let x=0;x<s;x++){for(let W=0;W<d;W++){const ee=h[W];let Z;switch(i){case"triangular":{const re=ee*(1-o),ge=ee,be=ee*(1+o*1.5);Z=Fc(re,ge,be);break}case"normal":{Z=Uc(ee,ee*o);break}case"uniform":{Z=Yc(ee*(1-o),ee*(1+o));break}}m[W]=Math.max(.5,Z),b[W]+=m[W],w[W]+=m[W]*m[W],m[W]>h[W]&&k[W]++}if(v[x]=Wc(c,u,h,m,p,g,y,S),x%E===0){const W=Xc(d,m,p,g,y,S);for(const ee of W)D[ee]++}}const C=Array.from(v).sort((x,W)=>x-W),A=C.map(x=>dt(l,x)),M=new Map;for(const x of a){const W=Math.min(Math.floor(x*C.length),C.length-1);M.set(x,dt(l,C[W]))}let L=0;for(let x=0;x<s;x++)L+=C[x];const N=L/s,R=dt(l,N),$=Math.floor(s/2),_=dt(l,C[$]);let U=0;for(let x=0;x<s;x++){const W=C[x]-N;U+=W*W}const Y=Math.sqrt(U/s),K=dt(l,C[0]),B=dt(l,C[C.length-1]),I=new Map;for(let x=0;x<d;x++){const W=b[x]/s,ee=w[x]/s-W*W;I.set(c[x],{meanDuration:W,stdDev:Math.sqrt(Math.max(0,ee)),delayProbability:k[x]/s})}const O=Math.floor(s/E),P=new Map;for(let x=0;x<d;x++)D[x]>0&&P.set(c[x],D[x]/O);return{iterations:s,finishDates:A,percentiles:M,meanFinishDate:R,medianFinishDate:_,earliestFinish:K,latestFinish:B,standardDeviation:Y,taskRisk:I,criticalPathFrequency:P}}function Gc(){if(typeof document>"u"||document.getElementById(Gn))return;const e=document.createElement("style");e.id=Gn,e.textContent=Bc,document.head.appendChild(e)}function Vc(){if(typeof document>"u")return;const e=document.getElementById(Gn);e&&e.remove()}function Kc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function c(r){if(!n)return;const l={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=zc(f.tasks,f.dependencies,l),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",l=0;for(const[g,y]of s.criticalPathFrequency)y>l&&(l=y,r=g);let f=r;if(n){const g=n.getState().tasks.get(r);g&&(f=g.name)}let T=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const g of t.confidenceLevels){const y=s.percentiles.get(g);if(!y)continue;const v=Math.round(g*100),m=ti[g]||"#94A3B8";T+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${si(y)}</span>
        </div>
      `}if(T+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${si(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&l>0){const g=Math.round(l*100);T+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${g}% of runs)
        </div>
      `}a.innerHTML=T;const S=a.querySelector(".ng-montecarlo-close");S&&S.addEventListener("click",()=>u())}function p(r,l){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:T}=l.config,S=l.scrollX,g=r.canvas.width/(window.devicePixelRatio||1),y=r.canvas.height/(window.devicePixelRatio||1),v=T,m=y-v,b=s.earliestFinish,w=s.latestFinish,k=Math.max(rn(b,w),1),D=f.getColumnWidth(),E=Math.max(D,Hc),C=Math.max(Math.ceil(k),1),A=new Uint32Array(C);for(const $ of s.finishDates){const _=rn(b,$),U=Math.min(Math.max(Math.floor(_),0),C-1);A[U]++}let M=0;for(let $=0;$<C;$++)A[$]>M&&(M=A[$]);if(M===0)return;r.save(),r.beginPath(),r.rect(0,v,g,m),r.clip(),r.translate(-S,0);const L=s.finishDates[Math.floor(s.finishDates.length*.1)],N=s.finishDates[Math.floor(s.finishDates.length*.9)];if(L&&N){const $=f.dateToX(L),_=f.dateToX(N),U=r.createLinearGradient($,0,_,0);U.addColorStop(0,"rgba(34, 197, 94, 0.0)"),U.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),U.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),U.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=U,r.globalAlpha=xc*5,r.fillRect($,v,_-$,m),r.globalAlpha=1}const R=y-8;for(let $=0;$<C;$++){if(A[$]===0)continue;const _=dt(b,$),U=f.dateToX(_),Y=A[$]/M*Oc,K=C>1?$/(C-1):.5;let B,I,O;if(K<.5){const P=K*2;B=Math.round(34+200*P),I=Math.round(197+-18*P),O=Math.round(94+-86*P)}else{const P=(K-.5)*2;B=Math.round(234+5*P),I=Math.round(179+-111*P),O=Math.round(8+60*P)}r.fillStyle=`rgba(${B}, ${I}, ${O}, 0.6)`,r.fillRect(U,R-Y,Math.max(E-1,1),Y)}r.setLineDash(ei),r.lineWidth=1.5;for(const[$,_]of s.percentiles){const U=f.dateToX(_),Y=ti[$]||"#94A3B8",K=`P${Math.round($*100)}`;r.strokeStyle=Y,r.beginPath(),r.moveTo(U,v),r.lineTo(U,y),r.stroke(),r.setLineDash([]),r.fillStyle=Y,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const B=r.measureText(`${K}: ${ni(_)}`).width,I=`${K}: ${ni(_)}`,O=B+8,P=16,x=U-O/2,W=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(x+3,W),r.lineTo(x+O-3,W),r.arcTo(x+O,W,x+O,W+3,3),r.lineTo(x+O,W+P-3),r.arcTo(x+O,W+P,x+O-3,W+P,3),r.lineTo(x+3,W+P),r.arcTo(x,W+P,x,W+P-3,3),r.lineTo(x,W+3),r.arcTo(x,W,x+3,W,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=Y,r.fillText(I,U,W+3),r.setLineDash(ei)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Gc(),i.push(r.on("montecarlo:run",(...l)=>{const f=l[0];c(f)}),r.on("montecarlo:result",(...l)=>{const f=l[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...l)=>{const f=l[0];f&&d(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&c()}))},middleware(r,l){l(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&c()},renderCanvas(r,l,f){!o||!s||p(r,l)},renderDOM(r,l){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Vc(),s=null,n=null}}}const ln=864e5,oi=400,Kn="nimbus-gantt-narrative-styles",ii=300;function Ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function jn(e,t){return Math.round((t.getTime()-e.getTime())/ln)}function ai(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function ri(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*ln)}function li(e,t){return new Date(e.getTime()+t*ln)}function jc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const C=Ve(E.startDate).getTime(),A=Ve(E.endDate).getTime();C<s&&(s=C),A>o&&(o=A)}const i=new Date(s),a=new Date(o),c=jn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const d=new Map,h=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(d.has(E.source)||d.set(E.source,[]),d.get(E.source).push(E.target),h.has(E.target)||h.set(E.target,[]),h.get(E.target).push(E.source));const p=Qc(n,t),r=ri(i),l=ri(a),f=[];let T=r;for(;T.getTime()<=l.getTime();)f.push({start:new Date(T),end:li(T,6)}),T=li(T,7);const S=[];for(let E=0;E<f.length;E++){const C=f[E],A=C.start,M=C.end,L=[],N=[],R=[],$=[],_=[],U=[],Y=[];for(const P of n){const x=Ve(P.startDate),W=Ve(P.endDate);x>=A&&x<=M&&(L.push(P),P.isMilestone?(U.push(P),Y.push(`Milestone: ${P.name}`)):Y.push(`Started: ${P.name}`)),W>=A&&W<=M&&(P.isCompleted||P.progress!==void 0&&P.progress>=1)&&(N.push(P),Y.push(`Completed: ${P.name}`)),x<=M&&W>=A&&(_.push(P),x<A&&!P.isCompleted&&(P.progress===void 0||P.progress===0)&&R.push(P),!P.isCompleted&&P.progress!==void 0&&P.progress>0&&P.progress<1&&$.push(P))}for(const P of n)if(P.isMilestone){const x=Ve(P.startDate);x>=A&&x<=M&&!U.includes(P)&&(U.push(P),Y.push(`Milestone: ${P.name}`))}const K=_.filter(P=>p.has(P.id)),B=qc(L,N,R,_,K),I=Zc(L,N,R,$,_,K,U,d,e),O=`Week ${E+1} (${ai(A)}–${ai(M)})`;S.push({weekLabel:O,headline:B,body:I,metrics:{started:L.length,completed:N.length,delayed:R.length,onTrack:$.length},events:Y})}const g=n.length,y=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,v=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,m=g-y-v,b=g>0?Math.round(y/g*100):0,w=b>=75?"strong":b>=50?"moderate":b>=25?"early-stage":"just getting started",k=`This project spans ${c} days across ${f.length} weeks with ${g} tasks. Progress is ${w} at ${b}% completion (${y} done, ${v} in progress, ${m} not started).`,D=Jc(n,p,d,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:k,chapters:S,insights:D}}function qc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Zc(e,t,n,s,o,i,a,c,u){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(l=>l.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(l=>l.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(l=>l.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(l=>l.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const l=n.map(f=>f.name).join(", ");d.push(`${l} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const l of n){const f=c.get(l.id);if(f)for(const T of f){const S=u.get(T);S&&!r.includes(S.name)&&r.push(S.name)}}if(r.length>0){const l=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${l}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(l=>l.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,l)=>l[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function Jc(e,t,n,s,o,i,a){const c=[];if(t.size>0){const S=e.filter(v=>t.has(v.id)),g=S.slice(0,4).map(v=>v.name).join(", "),y=S.length>4?` and ${S.length-4} more`:"";c.push(`The critical path runs through ${g}${y} — any delay here pushes the project finish.`)}const u=new Map;for(const S of e)S.assignee&&!S.isCompleted&&u.set(S.assignee,(u.get(S.assignee)||0)+1);const d=Array.from(u.entries()).sort((S,g)=>g[1]-S[1]);d.length>0&&d[0][1]>=2&&c.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const h=e.filter(S=>S.isCompleted?!1:Ve(S.startDate)<a&&(S.progress===void 0||S.progress===0));h.length>0&&c.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=jn(o,i),r=jn(o,a);if(r>0&&p>0){const S=Math.round(r/p*100),g=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,y=Math.round(g/e.length*100),v=y-S;Math.abs(v)>=5?v>0?c.push(`Project is running ahead: ${y}% of tasks completed with ${S}% of time elapsed.`):c.push(`Project is running behind: only ${y}% of tasks completed with ${S}% of time elapsed.`):c.push(`Project is tracking close to schedule: ${y}% complete at ${S}% of elapsed time.`)}const l=e.filter(S=>{if(S.isCompleted||S.progress!==void 0&&S.progress>0)return!1;const g=s.get(S.id);return!g||g.length===0});l.length>0&&l.length<=e.length*.5&&c.push(`${l.length} task${l.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,T="";for(const S of e){const g=n.get(S.id);g&&g.length>f&&(f=g.length,T=S.name)}return f>=3&&c.push(`"${T}" is a bottleneck with ${f} downstream tasks depending on it.`),c}function Qc(e,t){const n=new Map;for(const l of e)n.set(l.id,l);const s=new Map,o=new Map;for(const l of e)s.set(l.id,[]),o.set(l.id,0);for(const l of t.values())(l.type||"FS")==="FS"&&(!n.has(l.source)||!n.has(l.target)||(s.get(l.source).push({target:l.target,lag:l.lag||0}),o.set(l.target,(o.get(l.target)||0)+1)));const i=new Map,a=[];for(const l of e)o.get(l.id)===0&&a.push(l.id);for(const l of e){const f=Ve(l.endDate).getTime();i.set(l.id,f)}const c=new Map(o);for(;a.length>0;){const l=a.shift(),f=i.get(l);for(const T of s.get(l)){const S=n.get(T.target),g=Ve(S.endDate).getTime()-Ve(S.startDate).getTime(),y=f+T.lag*ln+g;y>i.get(T.target)&&i.set(T.target,y);const v=c.get(T.target)-1;c.set(T.target,v),v===0&&a.push(T.target)}}let u=-1/0,d="";for(const[l,f]of i)f>u&&(u=f,d=l);if(!d)return new Set;const h=new Set,p=new Map;for(const l of e)p.set(l.id,[]);for(const l of t.values())(l.type||"FS")==="FS"&&(!n.has(l.source)||!n.has(l.target)||p.get(l.target).push({source:l.source,lag:l.lag||0}));let r=d;for(;r;){h.add(r);const l=p.get(r);if(!l||l.length===0)break;let f="",T=-1/0;for(const S of l){const g=i.get(S.source)||0;g>T&&(T=g,f=S.source)}if(!f||h.has(f))break;r=f}return h}const ed=`
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
    transition: opacity ${ii}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${oi}px;
    width: ${oi}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${ii}ms ease;
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
`;function td(){if(typeof document>"u"||document.getElementById(Kn))return;const e=document.createElement("style");e.id=Kn,e.textContent=ed,document.head.appendChild(e)}function nd(){if(typeof document>"u")return;const e=document.getElementById(Kn);e&&e.remove()}function sd(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function od(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function c(){if(!e)return;const r=e.getState();t=jc(r.tasks,r.dependencies)}function u(){n=!0,c(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const l=document.createElement("div");l.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",l.appendChild(f);const T=document.createElement("span");T.textContent="Project Story",l.appendChild(T),r.appendChild(l);const S=document.createElement("div");S.style.display="flex",S.style.alignItems="center",S.style.gap="4px";const g=document.createElement("button");g.className="ng-narrative-refresh",g.innerHTML="↻",g.title="Regenerate",g.addEventListener("click",()=>{c(),h()}),S.appendChild(g);const y=document.createElement("button");y.className="ng-narrative-close",y.innerHTML="×",y.addEventListener("click",d),S.appendChild(y),r.appendChild(S),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const w=document.createElement("div");w.className="ng-narrative-empty",w.textContent="No weekly chapters to display.",a.appendChild(w)}else for(const w of t.chapters){const k=document.createElement("div");k.className="ng-narrative-chapter";const D=sd(w),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const C=document.createElement("div");C.className="ng-narrative-week-label",C.textContent=w.weekLabel,E.appendChild(C);const A=document.createElement("div");A.className="ng-narrative-headline",A.textContent=w.headline,E.appendChild(A),k.appendChild(E);const M=document.createElement("div");if(M.className="ng-narrative-metrics",w.metrics.started>0&&M.appendChild(p("started",`${w.metrics.started} started`)),w.metrics.completed>0&&M.appendChild(p("completed",`${w.metrics.completed} done`)),w.metrics.delayed>0&&M.appendChild(p("delayed",`${w.metrics.delayed} delayed`)),w.metrics.onTrack>0&&M.appendChild(p("ontrack",`${w.metrics.onTrack} on track`)),M.children.length>0&&k.appendChild(M),w.body){const L=document.createElement("div");L.className="ng-narrative-body",L.textContent=w.body,k.appendChild(L)}a.appendChild(k)}if(t.insights.length>0){const w=document.createElement("div");w.className="ng-narrative-insights";const k=document.createElement("div");k.className="ng-narrative-insights-title",k.innerHTML="<span>💡</span> Key Insights",w.appendChild(k);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const C=document.createElement("span");C.className="ng-narrative-insight-icon",C.textContent="•",E.appendChild(C);const A=document.createElement("span");A.textContent=D,E.appendChild(A),w.appendChild(E)}a.appendChild(w)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const b=new Date(t.generatedAt);m.textContent=`Generated ${b.toLocaleString()}`,a.appendChild(m)}function p(r,l){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=l,f}return{name:"NarrativePlugin",install(r){e=r,td(),c(),s.push(r.on("narrative:generate",()=>{c(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||c()}))},renderDOM(r,l){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(c(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),nd(),e=null,t=null,n=!1}}}const id=864e5,ad=10,qn="nimbus-gantt-whatif-styles",ci=.25,rd=.6,cn=6,di="#38A169",ui="#E53E3E",gi="#A0AEC0",Zn=36,ld="#F6AD55",hi="#1a202c",cd=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Zn}px;
    background: ${ld};
    color: ${hi};
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
    color: ${hi};
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
    top: ${Zn}px;
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
    top: ${Zn+8}px;
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
    color: ${di};
  }
  .ng-whatif-summary-value--worsened {
    color: ${ui};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${gi};
  }
`;function Ke(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function fi(e){const t=Ke(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function dn(e,t){return Math.round((t.getTime()-e.getTime())/id)}function pi(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function dd(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function ud(e){return{...e}}function gd(){if(typeof document>"u"||document.getElementById(qn))return;const e=document.createElement("style");e.id=qn,e.textContent=cd,document.head.appendChild(e)}function hd(){if(typeof document>"u")return;const e=document.getElementById(qn);e&&e.remove()}function fd(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,dd(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,ud(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function mi(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function pd(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const c=[];let u=null,d=null,h=null,p=null,r=null,l=null,f=null;function T(){t||!e||(o=fd(e.getState()),i=[],t=!0,n=!1,D())}function S(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),A(),L())}function g(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),A())}function y(I){if(!t||!e||!o)return;a.length>=ad&&a.shift();const O=e.getState(),P=mi(O.tasks),x=Ke(o.projectFinish),W=Ke(P),ee=dn(x,W);let Z=0;for(const[ge,be]of o.tasks){const X=O.tasks.get(ge);if(!X){Z++;continue}(X.startDate!==be.startDate||X.endDate!==be.endDate||X.assignee!==be.assignee)&&Z++}for(const ge of O.tasks.keys())o.tasks.has(ge)||Z++;const re={id:pi(),name:I,createdAt:Date.now(),changes:[...i],result:{projectFinish:P,criticalPathDelta:ee,tasksAffected:Z}};a.push(re),_()}function v(I){if(!e||!o)return;const O=a.find(P=>P.id===I);if(O){t||T(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const P of O.changes)b(P);i=[...O.changes],E()}}function m(I){a=a.filter(O=>O.id!==I),_()}function b(I){if(e)switch(I.type){case"move":case"resize":I.taskId&&I.after&&I.after.startDate&&I.after.endDate&&e.dispatch({type:I.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:I.taskId,startDate:I.after.startDate,endDate:I.after.endDate});break;case"add":I.after&&e.dispatch({type:"ADD_TASK",task:I.after});break;case"remove":I.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:I.taskId});break;case"reassign":I.taskId&&I.after&&e.dispatch({type:"UPDATE_TASK",taskId:I.taskId,changes:I.after});break;case"add-dependency":I.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:I.dependencyId||pi(),source:I.dependency.source,target:I.dependency.target,type:I.dependency.type||"FS"}});break;case"remove-dependency":I.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:I.dependencyId});break}}function w(){t&&(n=!n,n?C():A())}function k(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const I=e.getState(),O=mi(I.tasks),P=Ke(o.projectFinish),x=Ke(O),W=dn(P,x);let ee=0;for(const[Z,re]of o.tasks){const ge=I.tasks.get(Z);if(!ge){ee++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&ee++}for(const Z of I.tasks.keys())o.tasks.has(Z)||ee++;return{baselineFinish:o.projectFinish,sandboxFinish:O,deltaDays:W,tasksAffected:ee}}function D(){u&&u.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function C(){if(!h)return;const I=k();let O="ng-whatif-summary-value--unchanged",P="No change";I.deltaDays<0?(O="ng-whatif-summary-value--improved",P=`${Math.abs(I.deltaDays)} day${Math.abs(I.deltaDays)!==1?"s":""} earlier`):I.deltaDays>0&&(O="ng-whatif-summary-value--worsened",P=`${I.deltaDays} day${I.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${fi(I.baselineFinish)} &rarr; ${fi(I.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${O}">${P}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${I.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function A(){h&&h.classList.add("ng-hidden")}function M(){s=!s,d&&d.classList.toggle("ng-open",s),s&&_()}function L(){s=!1,d&&d.classList.remove("ng-open")}function N(){r&&(r.classList.add("ng-active"),l==null||l.focus())}function R(){r&&r.classList.remove("ng-active"),l&&(l.value="")}function $(){if(!l)return;const I=l.value.trim();I&&(y(I),R())}function _(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(I=>{var W;const O=new Date(I.createdAt).toLocaleDateString(),P=((W=I.result)==null?void 0:W.criticalPathDelta)??0;let x="No impact";return P<0?x=`${Math.abs(P)}d earlier`:P>0&&(x=`${P}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${I.id}">
            <div class="ng-whatif-scenario-name">${U(I.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${O}</span>
              <span>${I.changes.length} changes</span>
              <span>${x}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${I.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${I.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${I.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function U(I){const O=document.createElement("div");return O.textContent=I,O.innerHTML}function Y(I){const O=I.target,P=O.getAttribute("data-action"),x=O.getAttribute("data-id");if(!(!P||!x))switch(P){case"load":v(x),L();break;case"compare":v(x),n=!0,C(),L();break;case"delete":m(x);break}}function K(I,O){switch(I.type){case"TASK_MOVE":{const P=O.tasks.get(I.taskId);P&&i.push({type:"move",taskId:I.taskId,before:{startDate:P.startDate,endDate:P.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"TASK_RESIZE":{const P=O.tasks.get(I.taskId);P&&i.push({type:"resize",taskId:I.taskId,before:{startDate:P.startDate,endDate:P.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:I.task.id,after:{...I.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:I.taskId,before:O.tasks.get(I.taskId)?{...O.tasks.get(I.taskId)}:void 0});break;case"UPDATE_TASK":{const P=O.tasks.get(I.taskId);P&&i.push({type:"reassign",taskId:I.taskId,before:{...P},after:I.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:I.dependency.id,dependency:{source:I.dependency.source,target:I.dependency.target,type:I.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:I.dependencyId});break}E()}function B(I,O,P,x,W,ee){const Z=Math.min(ee,x/2,W/2);I.beginPath(),I.moveTo(O+Z,P),I.lineTo(O+x-Z,P),I.arcTo(O+x,P,O+x,P+Z,Z),I.lineTo(O+x,P+W-Z),I.arcTo(O+x,P+W,O+x-Z,P+W,Z),I.lineTo(O+Z,P+W),I.arcTo(O,P+W,O,P+W-Z,Z),I.lineTo(O,P+Z),I.arcTo(O,P,O+Z,P,Z),I.closePath()}return{name:"WhatIfPlugin",install(I){e=I,gd(),c.push(I.on("whatif:enter",()=>T())),c.push(I.on("whatif:exit",()=>S())),c.push(I.on("whatif:compare",()=>w())),c.push(I.on("whatif:discard",()=>g())),c.push(I.on("whatif:save",(...O)=>{const P=typeof O[0]=="string"?O[0]:void 0;P?y(P):N()})),c.push(I.on("whatif:load",(...O)=>{const P=typeof O[0]=="string"?O[0]:void 0;P?v(P):M()})),c.push(I.on("whatif:list-scenarios",(...O)=>{const P=typeof O[0]=="function"?O[0]:void 0;P?P([...a]):M()})),c.push(I.on("whatif:delete-scenario",(...O)=>{const P=typeof O[0]=="string"?O[0]:void 0;P&&m(P)}))},middleware(I,O){if(!t){O(I);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(I.type)&&e){const x=e.getState();K(I,x)}O(I)},renderCanvas(I,O,P){if(!t||!e)return;const{theme:x,headerHeight:W,barHeight:ee}=O.config,Z=O.scrollX,re=O.scrollY,ge=W,be=e.getTimeScale(),X=x.barBorderRadius;if(I.save(),I.beginPath(),I.rect(0,ge,I.canvas.width,I.canvas.height-ge),I.clip(),I.translate(-Z,0),o){const te=new Set;for(const q of P){const Q=o.tasks.get(q.taskId),se=O.tasks.get(q.taskId);(!Q&&se||Q&&se&&(Q.startDate!==se.startDate||Q.endDate!==se.endDate||Q.assignee!==se.assignee))&&te.add(q.taskId)}for(const q of P){if(!te.has(q.taskId))continue;const Q=q.x,se=q.barY-re,de=q.width,ie=q.barHeight;se+ie<ge||se>I.canvas.height||(I.save(),I.setLineDash([4,3]),I.strokeStyle="#F6AD55",I.lineWidth=2,B(I,Q,se,de,ie,X),I.stroke(),I.restore())}}if(n&&o){const te=ee*rd;for(const q of P){if(q.isMilestone)continue;const Q=o.tasks.get(q.taskId);if(!Q)continue;const se=O.tasks.get(q.taskId);if(!se)continue;const de=Ke(Q.startDate),ie=Ke(Q.endDate),fe=Ke(se.startDate),ce=Ke(se.endDate),Te=dn(de,fe),ve=dn(ie,ce);if(Te===0&&ve===0)continue;let z=gi;ve<0?z=di:ve>0&&(z=ui);const H=be.dateToX(de),F=be.dateToX(ie),G=Math.max(F-H,2),V=q.barY-re,j=V+ee+2;I.save(),I.globalAlpha=ci,I.fillStyle=z,B(I,H,j,G,te,X),I.fill(),I.globalAlpha=ci*2,I.strokeStyle=z,I.lineWidth=1,I.stroke(),I.restore();const ne=H+G/2,oe=j+te/2,ae=q.x+q.width/2,le=V+ee/2;I.save(),I.globalAlpha=.6,I.strokeStyle=z,I.lineWidth=1.5,I.setLineDash([3,2]),I.beginPath(),I.moveTo(ne,oe),I.lineTo(ae,le),I.stroke();const me=Math.atan2(le-oe,ae-ne),Se=ae,Ae=le;I.setLineDash([]),I.beginPath(),I.moveTo(Se,Ae),I.lineTo(Se-cn*Math.cos(me-Math.PI/6),Ae-cn*Math.sin(me-Math.PI/6)),I.lineTo(Se-cn*Math.cos(me+Math.PI/6),Ae-cn*Math.sin(me+Math.PI/6)),I.closePath(),I.fillStyle=z,I.fill(),I.restore()}}I.restore()},renderDOM(I,O){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const P=document.createElement("div");P.className="ng-whatif-banner-left";const x=document.createElement("span");x.className="ng-whatif-badge",x.textContent="What-If Mode",P.appendChild(x);const W=document.createElement("span");W.textContent="Changes are hypothetical",W.style.fontSize="12px",W.style.opacity="0.7",P.appendChild(W);const ee=document.createElement("span");ee.textContent="·",ee.style.opacity="0.4",P.appendChild(ee),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",P.appendChild(p),u.appendChild(P);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",l=document.createElement("input"),l.type="text",l.placeholder="Scenario name...",l.addEventListener("keydown",se=>{se.key==="Enter"&&$(),se.key==="Escape"&&R()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",$);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>R()),r.appendChild(l),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const be=document.createElement("button");be.className="ng-whatif-btn",be.textContent="Scenarios",be.addEventListener("click",()=>M()),Z.appendChild(be);const X=document.createElement("button");X.className="ng-whatif-btn ng-whatif-btn--primary",X.textContent="Compare with Baseline",X.addEventListener("click",()=>w()),Z.appendChild(X);const te=document.createElement("button");te.className="ng-whatif-btn",te.textContent="Save Scenario",te.addEventListener("click",()=>N()),Z.appendChild(te);const q=document.createElement("button");q.className="ng-whatif-btn ng-whatif-btn--danger",q.textContent="Discard",q.addEventListener("click",()=>g()),Z.appendChild(q);const Q=document.createElement("button");Q.className="ng-whatif-btn ng-whatif-btn--danger",Q.textContent="Exit",Q.addEventListener("click",()=>S()),Z.appendChild(Q),u.appendChild(Z),I.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",I.appendChild(h)),!d){d=document.createElement("div"),d.className="ng-whatif-panel";const P=document.createElement("div");P.className="ng-whatif-panel-title";const x=document.createElement("span");x.textContent="Saved Scenarios",P.appendChild(x);const W=document.createElement("button");W.className="ng-whatif-panel-close",W.textContent="×",W.addEventListener("click",()=>L()),P.appendChild(W),d.appendChild(P),f=document.createElement("div"),f.addEventListener("click",Y),d.appendChild(f),I.appendChild(d),_()}D(),n&&C()},destroy(){for(const I of c)I();c.length=0,u&&(u.remove(),u=null),d&&(d.remove(),d=null),h&&(h.remove(),h=null),p=null,r=null,l=null,f=null,hd(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Jn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},md=261.63;function yd(e){return md*Math.pow(2,e/12)}function bd(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return yd(n?a+12:a)}const Qn="nimbus-gantt-sonification-styles",es=64,un=64,yi=.05,Td=.1,vd=.7,bi=.2,ts="#F6AD55",Sd=2,wd="rgba(246, 173, 85, 0.35)",Ti=12,kd=`
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
    height: ${es}px;
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
`;function ns(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Dd(){if(typeof document>"u"||document.getElementById(Qn))return;const e=document.createElement("style");e.id=Qn,e.textContent=kd,document.head.appendChild(e)}function Ed(){if(typeof document>"u")return;const e=document.getElementById(Qn);e&&e.remove()}function Cd(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,c=null,u=null,d=null,h=null;const p=new Map;let r="stopped",l=0,f=0,T=0,S=0,g=0,y=0,v=0,m=null,b=null,w=null,k=null,D=null,E=null;const C=[];let A=[],M=[];function L(){if(c)return;const X=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;X&&(c=new X,u=c.createGain(),u.gain.value=i,d=c.createAnalyser(),d.fftSize=256,h=new Uint8Array(d.frequencyBinCount),u.connect(d),d.connect(c.destination))}function N(){c&&c.state==="suspended"&&c.resume()}function R(){if(!a)return;const X=a.getState(),te=Date.now();let q=1/0,Q=-1/0;const se=[],de=new Set,ie=X.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of X.tasks){const ve=ns(Te.startDate).getTime(),z=ns(Te.endDate).getTime();ve<q&&(q=ve),z>Q&&(Q=z);const H=Te.groupId||"__default__";de.add(H);const F=fe.get(ce)??0,G=!Te.isCompleted&&z<te&&(Te.progress??0)<1;se.push({id:ce,startMs:ve,endMs:z,rowIndex:F,progress:Te.progress??0,groupId:H,isCritical:!1,isOverdue:G})}A=se,M=Array.from(de),g=q===1/0?0:q,y=Q===-1/0?0:Q,v=Math.max(y-g,1)}function $(X){if(!c||!u||p.has(X.id))return;const te=Jn[n]||Jn.major,q=bd(X.rowIndex,te,X.isCritical),Q=c.createOscillator();Q.type=s,Q.frequency.value=q,X.isOverdue&&(Q.detune.value=25);const se=.3+X.progress*.7,de=X.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=c.createGain();fe.gain.setValueAtTime(0,c.currentTime),fe.gain.linearRampToValueAtTime(ie,c.currentTime+yi),fe.gain.linearRampToValueAtTime(ie*vd,c.currentTime+yi+Td);const ce=c.createStereoPanner();if(M.length<=1)ce.pan.value=0;else{const Te=M.indexOf(X.groupId);ce.pan.value=M.length>1?Te/(M.length-1)*2-1:0}Q.connect(fe),fe.connect(ce),ce.connect(u),Q.start(),p.set(X.id,{taskId:X.id,oscillator:Q,gainNode:fe,panNode:ce})}function _(X){const te=p.get(X);if(!te||!c)return;const q=c.currentTime;te.gainNode.gain.cancelScheduledValues(q),te.gainNode.gain.setValueAtTime(te.gainNode.gain.value,q),te.gainNode.gain.linearRampToValueAtTime(0,q+bi),te.oscillator.stop(q+bi+.05),p.delete(X)}function U(){for(const X of Array.from(p.keys()))_(X)}function Y(){if(r!=="playing"||!c)return;const X=c.currentTime-l;if(f=Math.min(X/o,1),f>=1){I();return}const te=g+f*v;for(const q of A){const Q=te>=q.startMs&&te<q.endMs,se=p.has(q.id);Q&&!se?$(q):!Q&&se&&_(q.id)}Z(),S=requestAnimationFrame(Y)}function K(){L(),N(),c&&(R(),r==="paused"?l=c.currentTime-T*o:(l=c.currentTime,f=0),r="playing",x(),W(),S=requestAnimationFrame(Y))}function B(){r==="playing"&&(r="paused",T=f,U(),cancelAnimationFrame(S),x())}function I(){r="stopped",f=0,T=0,U(),cancelAnimationFrame(S),x(),ee()}function O(){r==="playing"?B():K()}function P(X){const te=ns(X).getTime(),q=Math.max(0,Math.min((te-g)/v,1));r==="playing"&&c?l=c.currentTime-q*o:(T=q,f=q)}function x(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=re(),D.classList.remove("ng-son-btn--active")))}function W(){b&&b.classList.remove("ng-hidden")}function ee(){b&&b.classList.add("ng-hidden")}function Z(){if(!d||!h||!k||!w)return;d.getByteFrequencyData(h);const X=w.width,te=w.height;k.clearRect(0,0,X,te);const q=k.createLinearGradient(0,0,0,te);q.addColorStop(0,"rgba(26, 32, 44, 0)"),q.addColorStop(1,"rgba(26, 32, 44, 0.6)"),k.fillStyle=q,k.fillRect(0,0,X,te);const Q=X/un*.8,se=X/un*.2,de=Math.floor(h.length/un);for(let ie=0;ie<un;ie++){let fe=0;for(let G=0;G<de;G++)fe+=h[ie*de+G]??0;const ce=fe/de,Te=ce/255*te*.85,ve=ie*(Q+se),z=te-Te,H=30+ce/255*15,F=55+ce/255*15;k.fillStyle=`hsl(${H}, 90%, ${F}%)`,k.fillRect(ve,z,Q,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function be(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(X){a=X,Dd(),C.push(X.on("sonification:play",()=>K())),C.push(X.on("sonification:pause",()=>B())),C.push(X.on("sonification:stop",()=>I())),C.push(X.on("sonification:scrub",(...te)=>{const q=typeof te[0]=="string"?te[0]:void 0;q&&P(q)})),C.push(X.on("sonification:configure",(...te)=>{const q=te[0];q&&(q.tempo!==void 0&&(t=q.tempo),q.scale!==void 0&&(n=q.scale),q.instrument!==void 0&&(s=q.instrument),q.duration!==void 0&&(o=q.duration),q.volume!==void 0&&(i=q.volume,u&&(u.gain.value=i)))}))},renderCanvas(X,te,q){if(r==="stopped"||!a)return;const{headerHeight:Q}=te.config,se=te.scrollX,de=te.scrollY,ie=Q,fe=a.getTimeScale(),ce=g+f*v,Te=new Date(ce),ve=fe.dateToX(Te);X.save(),X.beginPath(),X.rect(0,ie,X.canvas.width,X.canvas.height-ie),X.clip(),X.translate(-se,0),X.save(),X.shadowColor=ts,X.shadowBlur=Ti,X.strokeStyle=ts,X.lineWidth=Sd,X.beginPath(),X.moveTo(ve,ie),X.lineTo(ve,X.canvas.height+de),X.stroke(),X.restore();const z=new Map;for(const H of q)z.set(H.taskId,H);for(const H of p.values()){const F=z.get(H.taskId);if(!F)continue;const G=F.x,V=F.barY-de,j=F.width,ne=F.barHeight;if(V+ne<ie||V>X.canvas.height)continue;const oe=((c==null?void 0:c.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);X.save(),X.globalAlpha=ae,X.shadowColor=wd,X.shadowBlur=Ti,X.fillStyle=ts;const le=Math.min(te.config.theme.barBorderRadius,j/2,ne/2);X.beginPath(),X.moveTo(G+le,V),X.lineTo(G+j-le,V),X.arcTo(G+j,V,G+j,V+le,le),X.lineTo(G+j,V+ne-le),X.arcTo(G+j,V+ne,G+j-le,V+ne,le),X.lineTo(G+le,V+ne),X.arcTo(G,V+ne,G,V+ne-le,le),X.lineTo(G,V+le),X.arcTo(G,V,G+le,V,le),X.closePath(),X.fill(),X.restore()}X.restore()},renderDOM(X,te){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=re(),D.title="Play / Pause",D.addEventListener("click",()=>O()),m.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=be(),E.title="Stop",E.addEventListener("click",()=>I()),m.appendChild(E);const q=document.createElement("div");q.className="ng-son-sep",m.appendChild(q);const Q=document.createElement("div");Q.style.display="flex",Q.style.flexDirection="column",Q.style.alignItems="center",Q.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",Q.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),Q.appendChild(de),m.appendChild(Q);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const F of Object.keys(Jn)){const G=document.createElement("option");G.value=F,G.textContent=F.charAt(0).toUpperCase()+F.slice(1),F===n&&(G.selected=!0),ce.appendChild(G)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const ve=document.createElement("div");ve.style.display="flex",ve.style.flexDirection="column",ve.style.alignItems="center",ve.style.gap="2px";const z=document.createElement("span");z.className="ng-son-label",z.textContent="Vol",ve.appendChild(z);const H=document.createElement("input");H.type="range",H.className="ng-son-slider",H.min="0",H.max="100",H.value=String(Math.round(i*100)),H.addEventListener("input",()=>{i=Number(H.value)/100,u&&(u.gain.value=i)}),ve.appendChild(H),m.appendChild(ve),X.appendChild(m)}if(!b){b=document.createElement("div"),b.className="ng-sonification-waveform ng-hidden",w=document.createElement("canvas"),k=w.getContext("2d");const q=(typeof window<"u"?window.devicePixelRatio:1)||1,Q=X.getBoundingClientRect();w.width=Q.width*q,w.height=es*q,w.style.width="100%",w.style.height=es+"px",k&&k.scale(q,q),b.appendChild(w),X.appendChild(b)}},destroy(){for(const X of C)X();C.length=0,I(),U(),c&&(c.close(),c=null),u=null,d=null,h=null,m&&(m.remove(),m=null),b&&(b.remove(),b=null),w=null,k=null,D=null,E=null,Ed(),a=null,A=[],M=[]}}}const Id=.55,Md=[4,3],Ad=1,Rd=4,Ld=600;function Pd(e={}){let t=null;const n=vi(e.futureFadeStrength??Id,0,1),s=e.futureDashedBorder!==!1,o=e.futureDashPattern??Md,i=e.futureDashWidth??Ad,a=e.pastShowCheckmark!==!1,c=e.todayProvider??(()=>new Date);return{name:"TemporalAsymmetryPlugin",install(u){t=u},renderCanvas(u,d,h){if(!t||h.length===0)return;const{config:p,scrollX:r,scrollY:l,tasks:f}=d,{theme:T}=p,S=p.headerHeight,g=T.barBorderRadius,y=c();let v;try{v=t.getTimeScale().dateToX(y)}catch{return}const m=e.futureFadeColor??T.timelineBg??"#ffffff",b=typeof window<"u"&&window.devicePixelRatio||1,w=u.canvas.width/b,k=u.canvas.height/b;u.save();const D=S,E=k-D;u.beginPath(),u.rect(0,D,w,E),u.clip(),u.translate(-r,0);for(const C of h){if(C.isMilestone)continue;const A=f.get(C.taskId);if(!A||A.status==="group-header")continue;const M=C.x,L=C.barY-l,N=C.width,R=C.barHeight;if(L+R<0||L>E)continue;const $=M+N,_=M>=v,U=$<=v,Y=!_&&!U;if(_||Y){const K=_?M:v,B=_?N:$-v;B>.5&&(u.save(),u.beginPath(),Si(u,M,L,N,R,g),u.clip(),u.globalAlpha=n,u.fillStyle=m,u.fillRect(K,L,B,R),u.restore())}if(s&&(_||Y)){const K=e.futureDashColor??_d(C.color,.4);if(u.save(),u.lineWidth=i,u.strokeStyle=K,u.setLineDash(o),_)$d(u,M,L,N,R,g);else{const B=L+.5,I=L+R-.5;u.beginPath(),u.moveTo(v,B),u.lineTo($-g,B),u.moveTo(v,I),u.lineTo($-g,I),u.moveTo(v,L),u.lineTo(v,L+R),u.stroke()}u.setLineDash([]),u.restore()}if(a&&U&&(A.progress??0)>=1){const K=M+Rd+5,B=L+R/2,I=e.pastCheckmarkColor??Nd(C.color);u.save(),u.font=`${Ld} ${Math.max(10,T.fontSize-1)}px ${T.fontFamily}`,u.textBaseline="middle",u.textAlign="left",u.fillStyle=I,u.fillText("✓",K-5,B),u.restore()}}u.restore()},destroy(){t=null}}}function vi(e,t,n){return Math.max(t,Math.min(n,e))}function Si(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.quadraticCurveTo(t+s,n,t+s,n+a),e.lineTo(t+s,n+o-a),e.quadraticCurveTo(t+s,n+o,t+s-a,n+o),e.lineTo(t+a,n+o),e.quadraticCurveTo(t,n+o,t,n+o-a),e.lineTo(t,n+a),e.quadraticCurveTo(t,n,t+a,n)}function $d(e,t,n,s,o,i){e.beginPath(),Si(e,t,n,s,o,i),e.stroke()}function _d(e,t){const n=wi(e);if(!n)return e;const s=Math.round((n.r+n.g+n.b)/3),o=i=>Math.round(i*(1-t)+s*t);return Od(o(n.r),o(n.g),o(n.b))}function Nd(e){const t=wi(e);return t?.299*t.r+.587*t.g+.114*t.b>140?"#1f2937":"#ffffff":"#1f2937"}function wi(e){const t=e.replace("#","");return t.length===3?{r:parseInt(t[0]+t[0],16),g:parseInt(t[1]+t[1],16),b:parseInt(t[2]+t[2],16)}:t.length===6?{r:parseInt(t.substring(0,2),16),g:parseInt(t.substring(2,4),16),b:parseInt(t.substring(4,6),16)}:null}function Od(e,t,n){const s=o=>vi(o,0,255).toString(16).padStart(2,"0");return`#${s(e)}${s(t)}${s(n)}`}const Hd=5e3,xd=3e4,Bd=500,Fd=new Set(["SET_DATA","UPDATE_TASK","ADD_TASK","REMOVE_TASK","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ot(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}})}function Ud(e={}){const t=Math.max(100,e.capacity??Hd),n=e.compactAfterIdleMs??xd,s=Math.min(t,Math.max(50,e.compactKeep??Bd)),o=[],i=[];let a=null,c=null,u=null,d=null;function h(){d&&clearTimeout(d),d=setTimeout(p,n)}function p(){if(o.length<=s)return;const y=o.length-s;o.splice(0,y),ot("history:compaction",{dropped:y,kept:o.length})}function r(y){var v;if(o.push(y),ot("history:entry-recorded",{actionType:y.action.type,ts:y.wallTs,source:y.source}),o.length>t){const m=o.splice(0,1);ot("history:overflow-drop",{ts:(v=m[0])==null?void 0:v.wallTs})}if(h(),e.onEntry)try{const m=e.onEntry(y);m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}e.hydrate&&o.push(...e.hydrate),e.hydrateAnnotations&&i.push(...e.hydrateAnnotations);function l(y,v){switch(v.type){case"SET_DATA":{const m=Array.from(y.tasks.values()),b=Array.from(y.dependencies.values());return{type:"SET_DATA",tasks:m,dependencies:b}}case"UPDATE_TASK":{const m=y.tasks.get(v.taskId);if(!m)return null;const b={};for(const w of Object.keys(v.changes))b[w]=m[w];return{type:"UPDATE_TASK",taskId:v.taskId,changes:b}}case"ADD_TASK":return{type:"REMOVE_TASK",taskId:v.task.id};case"REMOVE_TASK":{const m=y.tasks.get(v.taskId);return m?{type:"ADD_TASK",task:m}:null}case"TASK_MOVE":case"TASK_RESIZE":{const m=y.tasks.get(v.taskId);return m?{type:v.type,taskId:v.taskId,startDate:m.startDate,endDate:m.endDate}:null}case"ADD_DEPENDENCY":return{type:"REMOVE_DEPENDENCY",dependencyId:v.dependency.id};case"REMOVE_DEPENDENCY":{const m=y.dependencies.get(v.dependencyId);return m?{type:"ADD_DEPENDENCY",dependency:m}:null}default:return null}}function f(y,v){if(!Fd.has(y.type)){v(y);return}const m=a?a():null;if(!m){v(y);return}const b=l(m,y);v(y);const w=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),k=Date.now();r({ts:w,wallTs:k,action:y,inverse:b,actor:e.defaultActor,source:e.defaultSource??"local"})}function T(y){if(!a)return null;const v=y.getTime(),m=a();if(o.length===0)return m;const b=o[0].wallTs;if(v<b)return ot("history:snapshot-miss",{target:v,baselineTs:b}),null;const w=new gn(m);for(let k=o.length-1;k>=0;k--){const D=o[k];if(D.wallTs<=v)break;D.inverse&&w.dispatch(D.inverse)}return w.getState()}function S(y){const v=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),m=Date.now(),b={ts:v,wallTs:m,...y};if(i.push(b),ot("history:annotation-added",{kind:b.kind,taskId:b.taskId}),e.onAnnotation)try{const w=e.onAnnotation(b);w&&typeof w.catch=="function"&&w.catch(()=>{})}catch{}}const g={entries:()=>o,annotations:()=>i,snapshotAt:T,appendAnnotation:S,lastWallTs:()=>o.length>0?o[o.length-1].wallTs:null,scrubTo:y=>{c==null||c.setTimeCursor(y),ot("history:scrub",{cursorWallTs:y?y.getTime():null})},scrubToNow:()=>{c==null||c.setTimeCursor(null),ot("history:scrub",{cursorWallTs:null})}};return{name:"HistoryPlugin",install(y){a=y.getState,c=y.__gantt??null,c&&(c.history=g,typeof c.registerReplayProvider=="function"&&(u=c.registerReplayProvider({snapshotAt:v=>T(v)}))),ot("history:hydrate",{entryCount:o.length})},middleware:f,destroy(){d&&(clearTimeout(d),d=null),u&&(u(),u=null),c&&c.history===g&&(c.history=null),c=null}}}const Yd="#3b82f6",Wd=2,Xd="#10b981",zd=864e5;function Gd(e={}){let t=null,n=null,s=null;const o=e.cursorColor??Yd,i=e.cursorWidth??Wd,a=e.showNowBracket!==!1,c=e.nowBracketColor??Xd,u=e.enableKeyboardShortcuts!==!1,d=e.stepMs??zd;function h(l){if(!n)return;const T=n.getTimeCursor()??new Date,S=new Date(T.getTime()+l);n.setTimeCursor(S)}function p(){if(!(n!=null&&n.history))return;const l=n.history.entries();l.length!==0&&n.setTimeCursor(new Date(l[0].wallTs))}function r(l){const f=document.activeElement;if(!(f&&(f.tagName==="INPUT"||f.tagName==="TEXTAREA"||f.isContentEditable))){if(l.key==="Home"){l.preventDefault(),p();return}if(l.key==="End"){l.preventDefault(),n==null||n.setTimeCursor(null);return}if(l.key==="ArrowLeft"&&(l.altKey||l.metaKey)){l.preventDefault(),h(-d);return}if(l.key==="ArrowRight"&&(l.altKey||l.metaKey)){l.preventDefault(),h(d);return}}}return{name:"TimeCursorPlugin",install(l){t=l,n=l.__gantt??null,u&&typeof document<"u"&&(s=r,document.addEventListener("keydown",s))},renderCanvas(l,f,T){if(!t)return;const{config:S,scrollX:g}=f,y=S.headerHeight,v=typeof window<"u"&&window.devicePixelRatio||1,m=l.canvas.width/v,b=l.canvas.height/v,w=y,k=b-w;let D;try{D=t.getTimeScale()}catch{return}if(l.save(),l.beginPath(),l.rect(0,w,m,k),l.clip(),l.translate(-g,0),a){const C=D.dateToX(new Date);l.save(),l.strokeStyle=c,l.lineWidth=3,l.beginPath(),l.moveTo(C-6,w+1),l.lineTo(C+6,w+1),l.moveTo(C-6,w+k-1),l.lineTo(C+6,w+k-1),l.stroke(),l.restore()}const E=f.timeCursorDate;if(E){const C=D.dateToX(E);l.save(),l.strokeStyle=o,l.lineWidth=i,l.beginPath(),l.moveTo(C,w),l.lineTo(C,w+k),l.stroke(),l.fillStyle=o,l.beginPath(),l.moveTo(C-6,w),l.lineTo(C+6,w),l.lineTo(C,w+8),l.closePath(),l.fill(),l.restore()}l.restore()},destroy(){s&&typeof document<"u"&&document.removeEventListener("keydown",s),s=null,t=null,n=null}}}const Vd=14,Kd=4,jd=6,qd="#6b7280",Zd={comment:"#3b82f6",decision:"#8b5cf6","agent-note":"#10b981",view:"#a3a3a3"};function Jd(e={}){let t=null,n=null;const s=e.height??Vd,o=e.position??"above-body",i=e.markerRadius??Kd,a=e.clusterDistancePx??jd,c=e.fallbackColor??qd,u={...Zd,...e.colorByKind??{}};return{name:"HistoryStripPlugin",install(d){t=d,n=d.__gantt??null},renderCanvas(d,h,p){if(!t||!(n!=null&&n.history))return;const r=n.history.annotations();if(r.length===0)return;const{config:l,scrollX:f}=h,T=l.headerHeight,S=typeof window<"u"&&window.devicePixelRatio||1,g=d.canvas.width/S;let y;try{y=t.getTimeScale()}catch{return}const v=o==="above-body"?T-s:T+2;d.save(),d.beginPath(),d.rect(0,v,g,s),d.clip(),d.translate(-f,0);const m=[];for(const k of r){const D=y.dateToX(new Date(k.wallTs));m.push({x:D,ann:k})}m.sort((k,D)=>k.x-D.x);const b=[];for(const k of m){const D=b[b.length-1];D&&Math.abs(k.x-D.x)<=a?(D.entries.push(k),D.x=D.entries.reduce((E,C)=>E+C.x,0)/D.entries.length):b.push({x:k.x,entries:[k]})}const w=[];for(const k of b){const D=v+s/2,E=k.entries.length>1,C=k.entries[0].ann.kind,A=u[C]??c;d.fillStyle=A,d.beginPath(),d.arc(k.x,D,E?i+1:i,0,Math.PI*2),d.fill(),E&&(d.fillStyle="#ffffff",d.font="600 9px sans-serif",d.textBaseline="middle",d.textAlign="center",d.fillText(String(k.entries.length),k.x,D+.5)),w.push({cx:k.x,cy:D,r:E?i+1:i,annotations:k.entries.map(M=>M.ann)})}d.restore()},destroy(){t=null,n=null}}}const ki="nimbus-gantt-ctxmenu-styles",pe="ng-ctxmenu",Di={maxCalls:1,windowMs:2e3};function Qd(e){if(e===!1)return()=>!0;const t=e??Di,n=[];return function(){const o=Date.now(),i=o-t.windowMs;for(;n.length>0&&n[0]<i;)n.shift();return n.length>=t.maxCalls?!1:(n.push(o),!0)}}function Ei(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:Date.now(),kind:e,...t??{}})}function eu(e={}){let t=null,n=null,s=null,o=null,i=null,a=null;const c=Qd(e.agentRateLimit===void 0?Di:e.agentRateLimit);async function u(g,y){if(e.onConfirmDestructive)try{return!!await e.onConfirmDestructive(g,y)}catch{return!1}if(typeof window<"u"&&typeof window.confirm=="function"){const v=g==="task"?`Delete task "${y}"?`:`Delete dependency "${y}"?`;try{return window.confirm(v)}catch{return!1}}return!0}function d(){if(typeof document>"u"||document.getElementById(ki))return;const g=document.createElement("style");g.id=ki,g.textContent=`
      .${pe} {
        position: fixed;
        z-index: 999999;
        background: #ffffff;
        border: 1px solid #cbd5e1;
        border-radius: 6px;
        box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18), 0 2px 6px rgba(15, 23, 42, 0.08);
        padding: 4px 0;
        min-width: 180px;
        max-width: 320px;
        font-family: -apple-system, "Segoe UI", Roboto, sans-serif;
        font-size: 13px;
        color: #1e293b;
        user-select: none;
      }
      .${pe}-item {
        padding: 6px 12px;
        cursor: pointer;
        display: flex;
        align-items: center;
        gap: 8px;
        white-space: nowrap;
      }
      .${pe}-item:hover { background: #f1f5f9; }
      .${pe}-item[aria-disabled="true"] { color: #94a3b8; cursor: default; }
      .${pe}-item[aria-disabled="true"]:hover { background: transparent; }
      .${pe}-icon { width: 16px; text-align: center; font-size: 12px; }
      .${pe}-label { flex: 1; }
      .${pe}-shortcut { color: #94a3b8; font-size: 11px; margin-left: auto; }
      .${pe}-arrow { color: #94a3b8; }
      .${pe}-divider { border-top: 1px solid #e2e8f0; margin: 4px 0; }
      .${pe}-agent-glyph { color: #8b5cf6; font-weight: 600; }
      .${pe}-submenu { position: relative; }
    `,document.head.appendChild(g)}function h(){if(s){try{s.remove()}catch{}s=null}a&&typeof document<"u"&&(document.removeEventListener("pointerdown",a,!0),document.removeEventListener("keydown",a,!0),a=null)}function p(g,y,v){if(typeof document>"u"||g.length===0)return;h(),d();const m=document.createElement("div");m.className=pe,m.setAttribute("role","menu"),m.style.left=`${y.x}px`,m.style.top=`${y.y}px`,m.addEventListener("pointerdown",b=>{b.stopPropagation()});for(const b of g){if(b.divider){const E=document.createElement("div");E.className=`${pe}-divider`,m.appendChild(E);continue}const w=document.createElement("div");w.className=`${pe}-item`,b.disabled&&w.setAttribute("aria-disabled","true");const k=document.createElement("span");k.className=`${pe}-icon`,b.agentSuggested&&k.classList.add(`${pe}-agent-glyph`),k.textContent=b.icon??(b.agentSuggested?"✦":""),w.appendChild(k);const D=document.createElement("span");if(D.className=`${pe}-label`,D.textContent=b.label,w.appendChild(D),b.shortcut){const E=document.createElement("span");E.className=`${pe}-shortcut`,E.textContent=b.shortcut,w.appendChild(E)}if(b.children&&b.children.length>0){const E=document.createElement("span");E.className=`${pe}-arrow`,E.textContent="▸",w.appendChild(E);let C=null;w.addEventListener("mouseenter",()=>{if(C)return;const A=w.getBoundingClientRect();C=document.createElement("div"),C.className=pe,C.style.left=`${A.right+2}px`,C.style.top=`${A.top}px`;for(const M of b.children){const L=r(M,v);C.appendChild(L)}document.body.appendChild(C)}),w.addEventListener("mouseleave",()=>{if(C){try{C.remove()}catch{}C=null}})}else b.disabled||w.addEventListener("click",E=>{E.stopPropagation(),l(b,v,y)});m.appendChild(w)}document.body.appendChild(m),s=m,a=b=>{b instanceof KeyboardEvent&&b.key!=="Escape"||b.type==="pointerdown"&&b.target instanceof Element&&b.target.closest(`.${pe}`)||h()},document.addEventListener("pointerdown",a,!0),document.addEventListener("keydown",a,!0),requestAnimationFrame(()=>{if(!s)return;const b=s.getBoundingClientRect(),w=window.innerWidth,k=window.innerHeight;let D=b.left,E=b.top;b.right>w&&(D=Math.max(4,w-b.width-4)),b.bottom>k&&(E=Math.max(4,k-b.height-4)),s.style.left=`${D}px`,s.style.top=`${E}px`})}function r(g,y){if(g.divider){const w=document.createElement("div");return w.className=`${pe}-divider`,w}const v=document.createElement("div");v.className=`${pe}-item`,g.disabled&&v.setAttribute("aria-disabled","true");const m=document.createElement("span");m.className=`${pe}-icon`,g.agentSuggested&&m.classList.add(`${pe}-agent-glyph`),m.textContent=g.icon??(g.agentSuggested?"✦":""),v.appendChild(m);const b=document.createElement("span");return b.className=`${pe}-label`,b.textContent=g.label,v.appendChild(b),g.disabled||v.addEventListener("click",w=>{w.stopPropagation(),l(g,y,{x:0,y:0})}),v}function l(g,y,v){if(h(),g.agentSuggested&&g.prompt&&e.onAgentRequest&&(t!=null&&t.agent)){if(!c()){Ei("ctxmenu:agent-rate-limited",{itemId:g.id});return}const m={hit:y,pos:v,prompt:g.prompt,snapshot:t.agent.getSnapshot()};try{const b=e.onAgentRequest(m);b&&typeof b.catch=="function"&&b.catch(()=>{})}catch{}return}if(g.onClick)try{const m=g.onClick();m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}function f(g,y,v){return async()=>{await u(g,y)?v():Ei("ctxmenu:destructive-cancelled",{kind:g,label:y})}}function T(g,y){const v=[],m=!!e.onAgentRequest&&!e.hideAgentSubmenu;switch(g.zone){case"bar":return v.push({id:"edit",label:"Edit task…",icon:"✎",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"edit",g.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"reparent",g.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"change-bucket",g.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"mark-complete",g.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"delete",g.task,y)})}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-why",label:"Ask Claude: why is this scheduled here?",agentSuggested:!0,prompt:`Explain why task "${g.task.name}" (id ${g.task.id}) is scheduled from ${g.task.startDate} to ${g.task.endDate} given current dependencies, parent context, and bucket assignment.`},{id:"agent-blocks",label:"Ask Claude: what blocks this?",agentSuggested:!0,prompt:`What dependencies, capacity constraints, or upstream blockers are gating task "${g.task.name}" (id ${g.task.id})? Walk the dependency graph and list the critical path.`},{id:"agent-resched",label:"Ask Claude: reschedule with critical-path optimization",agentSuggested:!0,prompt:`Suggest a new schedule for task "${g.task.name}" (id ${g.task.id}) that optimizes the critical path. Stage hypotheses via gantt.agent if possible.`}),v;case"row-label":return v.push({id:"edit",label:"Edit name…",icon:"✎",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"edit",g.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"reparent",g.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"change-bucket",g.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"mark-complete",g.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var b;return(b=e.onTaskAction)==null?void 0:b.call(e,"delete",g.task,y)})}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-summarize",label:"Ask Claude: summarize this task",agentSuggested:!0,prompt:`Summarize task "${g.task.name}" (id ${g.task.id}) including its current status, parent, dependencies, and recent history if available.`}),v;case"date-header":{const b=g.date.toISOString().slice(0,10);return v.push({id:"scroll-here",label:`Scroll to ${b}`,icon:"↔",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"scroll-here",g.date,y)}},{id:"zoom-to",label:"Zoom to this range",icon:"⊕",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"zoom-to",g.date,y)}},{id:"add-milestone",label:`Add milestone on ${b}`,icon:"◆",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"add-milestone",g.date,y)}}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-summary",label:`Ask Claude: what's happening around ${b}?`,agentSuggested:!0,prompt:`Summarize tasks, milestones, and dependencies that intersect ${b}. Note any clusters, conflicts, or capacity hotspots.`}),v}case"canvas-empty":{const b=g.date.toISOString().slice(0,10),w=b,k=(()=>{const D=new Date(g.date);return D.setUTCDate(D.getUTCDate()+5),D.toISOString().slice(0,10)})();return v.push({id:"create-task",label:`Create work item starting ${b}`,icon:"＋",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:w,endDate:k,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},y)}},{id:"create-milestone",label:`Insert milestone on ${b}`,icon:"◆",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:b,endDate:b,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},y)}}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-suggest",label:"Ask Claude: suggest a task here",agentSuggested:!0,prompt:`Given the project context and the dates around ${b}${g.bucketId?` in bucket "${g.bucketId}"`:""}, suggest a sensible work item to insert. Consider open dependencies, capacity, and priority.`}),v}case"bucket-header":{const b=g.bucketTask.name||g.bucketId||"(bucket)";return v.push({id:"add-to-bucket",label:`Add task to ${b}`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:new Date().toISOString().slice(0,10),endDate:new Date(Date.now()+432e6).toISOString().slice(0,10),parentId:g.bucketTask.id,bucket:g.bucketId},y)}},{id:"collapse",label:`Collapse all in ${b}`,icon:"⊟",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"collapse",g.bucketTask,y)}},{id:"expand",label:`Expand all in ${b}`,icon:"⊞",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"expand",g.bucketTask,y)}}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-rebalance",label:`Ask Claude: rebalance ${b}`,agentSuggested:!0,prompt:`Review the tasks in bucket "${b}" for capacity, sequencing, and priority alignment. Suggest moves to/from adjacent buckets and reordering within.`}),v}case"below-rows":{const b=g.date.toISOString().slice(0,10);return v.push({id:"create-end",label:`Add new task at end (starts ${b})`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:b,endDate:new Date(g.date.getTime()+432e6).toISOString().slice(0,10),parentId:null,bucket:null},y)}}),v}case"dependency":return v.push({id:"change-fs",label:"Change type → Finish-to-Start (FS)",icon:"→",onClick:()=>{var b;return(b=e.onDependencyAction)==null?void 0:b.call(e,"change-type-fs",g.depId,y)}},{id:"change-ss",label:"Change type → Start-to-Start (SS)",icon:"↦",onClick:()=>{var b;return(b=e.onDependencyAction)==null?void 0:b.call(e,"change-type-ss",g.depId,y)}},{id:"change-ff",label:"Change type → Finish-to-Finish (FF)",icon:"↤",onClick:()=>{var b;return(b=e.onDependencyAction)==null?void 0:b.call(e,"change-type-ff",g.depId,y)}},{id:"change-sf",label:"Change type → Start-to-Finish (SF)",icon:"↔",onClick:()=>{var b;return(b=e.onDependencyAction)==null?void 0:b.call(e,"change-type-sf",g.depId,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete dependency",icon:"×",onClick:f("dependency",g.depId,()=>{var b;return(b=e.onDependencyAction)==null?void 0:b.call(e,"delete",g.depId,y)})}),m&&v.push({id:"div-agent",label:"",divider:!0},{id:"agent-explain-dep",label:"Ask Claude: is this dependency necessary?",agentSuggested:!0,prompt:`Evaluate dependency ${g.depId}. Is it logically required, or could the predecessor and successor run in parallel? Consider data flow, resource contention, and external constraints.`}),v;case"outside":default:return[]}}function S(g){if(!t||!n||g.button!==void 0&&g.button!==2)return;const y=t.hitTestAt(g.clientX,g.clientY);if(y.zone==="outside")return;g.preventDefault(),g.stopPropagation();const v={x:g.clientX,y:g.clientY};let m=null;if(e.onContextMenu)try{m=e.onContextMenu(y,v)}catch{m=null}const b=m&&Array.isArray(m)&&m.length>0?m:T(y,v);b.length>0&&p(b,v,y)}return{name:"ContextMenuPlugin",install(g){t=g.__gantt??null,n=(t&&t.rootEl)??null;const y=n??(typeof document<"u"?document:null);y&&(o=v=>S(v),y.addEventListener("contextmenu",o),e.disablePointerDownFallback||(i=v=>{v.button===2&&S(v)},y.addEventListener("pointerdown",i)))},destroy(){h();const g=n??(typeof document<"u"?document:null);g&&(o&&g.removeEventListener("contextmenu",o),i&&g.removeEventListener("pointerdown",i)),o=null,i=null,t=null,n=null}}}return J.AutoSchedulePlugin=Yr,J.BaselinePlugin=Xa,J.CLOUD_NIMBUS_PRIORITY_BUCKETS=Ia,J.ConfigPanelPlugin=xl,J.ContextMenuPlugin=eu,J.CriticalPathPlugin=_a,J.DARK_THEME=Ds,J.DarkThemePlugin=ir,J.DependencyRenderer=ys,J.EventBus=is,J.ExportPlugin=Ja,J.GroupingPlugin=ka,J.HeatmapViewPlugin=jl,J.HistoryPlugin=Ud,J.HistoryStripPlugin=Jd,J.HitTest=fs,J.KeyboardPlugin=ia,J.LIGHT_THEME=mn,J.LayoutEngine=ds,J.MSProjectPlugin=wr,J.MilestonePlugin=ga,J.MiniMapPlugin=rc,J.MonteCarloPlugin=Kc,J.MotionControlPlugin=mr,J.NarrativePlugin=od,J.NetworkGraphPlugin=Pl,J.NimbusGantt=Ji,J.PriorityGroupingPlugin=Ca,J.ResourceLevelingPlugin=Ur,J.RiskAnalysisPlugin=fl,J.SonificationPlugin=Cd,J.SplitTaskPlugin=Pr,J.TelemetryPlugin=hr,J.TemporalAsymmetryPlugin=Pd,J.TimeCursorPlugin=Gd,J.TimeScale=ls,J.TimeTravelPlugin=Nc,J.TimelineNotesPlugin=Dc,J.TooltipManager=ks,J.UndoRedoPlugin=sa,J.VirtualScrollPlugin=Ka,J.WhatIfPlugin=pd,J.WorkCalendarPlugin=dr,J.buildDependencyGraph=po,J.computeCPM=vn,J.computeSchedule=Nn,J.exportMSProjectXML=An,J.getAllParentIds=Is,J.getDescendantIds=Ms,J.hoursWeightedProgress=Ma,J.importMSProjectXML=Mn,J.parseDate=bt,J.resolveConfig=Es,J.rollupHoursDeduped=ta,Object.defineProperty(J,Symbol.toStringTag,{value:"Module"}),J})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
