var NimbusGantt=(function(Q){"use strict";function Ue(e,t){const n=new Map;for(const c of e.values()){const d=c.parentId&&e.has(c.parentId)?c.parentId:void 0;let u=n.get(d);u||(u=[],n.set(d,u)),u.push(c)}const s=[];function o(c,d){const u=c.sortOrder??Number.MAX_SAFE_INTEGER,h=d.sortOrder??Number.MAX_SAFE_INTEGER;return u!==h?u-h:c.name.localeCompare(d.name)}function i(c,d,u){const h=n.get(c);return h?(h.sort(o),h.map(p=>{const l=n.has(p.id)&&t.has(p.id),f=u,b={task:p,children:[],depth:d,expanded:l,visible:f,rowIndex:-1};return f&&(b.rowIndex=s.length,s.push(p.id)),b.children=i(p.id,d+1,f&&l),b})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function yt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class gn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Ci(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Ci(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const c of t.tasks)n.set(c.id,c);const s=new Map;if(t.dependencies)for(const c of t.dependencies)s.set(c.id,c);const{tree:o,flatIds:i}=Ue(n,e.expandedIds),a=yt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:c}=Ue(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:c}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=yt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};case"SET_TIME_CURSOR":return{...e,timeCursorDate:t.date};default:return e}}function os(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class is{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const hn=864e5,Ii=hn*7,Mi={day:40,week:120,month:180,quarter:200},as=["January","February","March","April","May","June","July","August","September","October","November","December"],rs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class ls{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=Mi[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/hn)}countWeeks(){return Math.ceil(this.totalMs/Ii)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const c=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:c,width:this.columnWidth,date:new Date(o)}),o=cs(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=fn(i),c=this.dateToX(i),d=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${as[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:c,width:d-c,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=cs(this.rangeStart,i*7),c=i*this.columnWidth;n.push({label:`${rs[a.getUTCMonth()]} ${a.getUTCDate()}`,x:c,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=fn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,c=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,d=this.dateToX(a),u=this.dateToX(c);t.push({label:`${as[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:d,width:u-d,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const c=a*this.columnWidth;n.push({label:rs[o.getUTCMonth()],x:c,width:this.columnWidth,date:new Date(o)}),o=fn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),c=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,d=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,u=this.dateToX(c),h=this.dateToX(d);t.push({label:String(i.getUTCFullYear()),x:u,width:h-u,date:new Date(c)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const c=Math.floor(o.getUTCMonth()/3)+1,d=a*this.columnWidth;n.push({label:`Q${c}`,x:d,width:this.columnWidth,date:new Date(o)}),o=Ai(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),c=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,d=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,u=this.dateToX(c),h=this.dateToX(d);t.push({label:String(i.getUTCFullYear()),x:u,width:h-u,date:new Date(c)}),i=a}return[t,n]}}function cs(e,t){return new Date(e.getTime()+t*hn)}function Ai(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function fn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class ds{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const c=t[a],d=n.get(c);if(!d)continue;const u=bt(d.startDate),h=bt(d.endDate),p=s.dateToX(u),r=s.dateToX(h)-p,l=Math.max(r,o.minBarWidth),f=a*o.rowHeight,b=f+(o.rowHeight-o.barHeight)/2,T=l*(d.progress||0),g=d.color||o.colorMap[d.status||""]||o.theme.barDefaultColor;i.push({taskId:c,rowIndex:a,x:p,y:f,width:l,barY:b,barHeight:o.barHeight,progressWidth:T,color:g,textColor:o.theme.barTextColor,label:d.status==="group-header"?d.name:(d.hoursLabel||(d.hours!=null?`${d.hours}h`:""))+(d.hoursLabel||d.hours!=null?" · ":"")+((d.progress||0)>0?`${Math.round((d.progress||0)*100)}% · `:"")+(d.title||d.name),isMilestone:d.isMilestone||!1})}return i}}function bt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Pt=864e5,us=1,Ri=2,Li=.5,Pi=2,gs=8,$i=6,pn=2;class _i{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:c}=this,{config:d}=t,{theme:u}=d,h=t.scrollX,p=t.scrollY;o.setTransform(c,0,0,c,0,0);const l=d.headerHeight,f=a-l;this.fillRect(0,0,i,a,u.timelineBg),o.save(),o.beginPath(),o.rect(0,l,i,f),o.clip(),o.translate(-h,0),d.showWeekends&&this.renderWeekendShading(t,s,l,f,u),this.renderGridLines(s,l,f,u,h),this.renderAltRows(t,n,l,u,h,p);const b=this.getTodayX(t,d,s);d.showToday&&b!==null&&this.renderTodayBackground(b,s,l,f,u),this.renderGroupRowBgs(t,n,d,h,p,l,f),this.renderTaskBars(t,n,d,u,h,p,l,f),this.renderDragSnapGuide(t,n,s,l,f,u),d.showToday&&b!==null&&this.renderTodayLine(b,l,f,u),o.restore(),this.renderHeader(s,d,u,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:c}=t.dateRange,d=new Date(a);d.setUTCHours(0,0,0,0);const u=c.getTime();for(;d.getTime()<=u;){const h=d.getUTCDay();if(h===0||h===6){const p=n.dateToX(d),r=new Date(d.getTime()+Pt),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}d.setTime(d.getTime()+Pt)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,c=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=Li;for(const d of c){const u=this.snapToPixel(d);a.moveTo(u,n),a.lineTo(u,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:c,displayWidth:d}=this,u=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*u-a;if(r+u<s||r>s+this.displayHeight)continue;this.fillRect(i,r,d+i,u,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const c=new Date(a.getTime()+Pt),d=n.dateToX(c)-n.dateToX(a);this.fillRect(t,s,d,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,c){const{ctx:d,displayWidth:u}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const l=p.y-i+a;l+h<a||l>a+c||(d.save(),d.fillStyle=r.groupBg,d.fillRect(o,l,u,h),r.groupColor&&(d.fillStyle=r.groupColor,d.fillRect(o,l,u,2)),d.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const c=t.dragState;if(!c||c.type!=="move"&&c.type!=="resize-left"&&c.type!=="resize-right")return;const d=n.find(T=>T.taskId===c.taskId);if(!d)return;const u=new Date;u.setHours(0,0,0,0);const h=new Date(u.getTime()+Pt),p=s.dateToX(h)-s.dateToX(u);if(p<=0)return;const r=c.currentX-c.startX;let l;c.type==="move"||c.type==="resize-left"?l=d.x+r:l=d.x+d.width+r;const f=Math.round(l/p)*p,{ctx:b}=this;b.save(),b.strokeStyle=a.barSelectedBorder||"#3b82f6",b.lineWidth=1,b.setLineDash([4,3]),b.globalAlpha=.85,b.beginPath(),b.moveTo(f+.5,o),b.lineTo(f+.5,o+i),b.stroke(),b.restore()}renderTaskBars(t,n,s,o,i,a,c,d){const{ctx:u}=this,h=o.barBorderRadius,p=t.dragState,r=p?p.currentX-p.startX:0,l=4;for(const f of n){let b=f.x;const T=f.barY-a+c;let g=f.width;const m=f.barHeight;if(T+m<c||T>c+d)continue;const S=p&&p.taskId===f.taskId;if(S){if(p.type==="move")b+=r;else if(p.type==="resize-left"){const k=b+r,D=g-r;D>=l&&(b=k,g=D)}else if(p.type==="resize-right"){const k=g+r;k>=l&&(g=k)}}if(f.isMilestone){this.renderMilestone(b,T,m,f.color,o,t.selectedIds.has(f.taskId));continue}const y=t.tasks.get(f.taskId),v=y&&y.status!=="group-header"&&y.style?y.style:null,w=v?this.resolveFillOpacity(v):1;if(w<1?(u.save(),u.globalAlpha=w,this.fillRoundedRect(b,T,g,m,h,f.color),u.restore()):this.fillRoundedRect(b,T,g,m,h,f.color),s.showProgress&&f.progressWidth>0){const k=this.darkenColor(f.color,.2);u.save(),u.beginPath(),this.roundedRectPath(b,T,g,m,h),u.clip(),u.fillStyle=k,u.fillRect(b,T,f.progressWidth,m),u.restore()}t.selectedIds.has(f.taskId)&&this.strokeRoundedRect(b,T,g,m,h,o.barSelectedBorder,pn),S&&this.strokeRoundedRect(b,T,g,m,h,o.barSelectedBorder,pn),v&&v.borderStyle&&v.borderStyle!=="none"&&this.renderDecoratorBorder(v,b,T,g,m,h,f.color),this.renderBarLabel(f,b,T,g,m,o),v&&v.badge&&v.badge.text&&this.renderDecoratorBadge(v.badge,b,T,g,m,f.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,c){const{ctx:d}=this,u=t.borderWidth??2,h=t.borderColor??this.darkenColor(c,.3),p=t.borderStyle??"solid";let r;switch(p){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(d.save(),d.setLineDash(r),d.strokeStyle=h,d.lineWidth=u,this.roundedRectPath(n,s,o,i,a),d.stroke(),p==="double"){const l=u+1,f=Math.max(0,a-l);d.lineWidth=u,this.roundedRectPath(n+l,s+l,Math.max(0,o-l*2),Math.max(0,i-l*2),f),d.stroke()}d.restore()}renderDecoratorBadge(t,n,s,o,i,a,c){const{ctx:d}=this,u=t.text,h=t.placement??"end",p=Math.max(14,i*.65),r=6;d.save();const l=`${Math.round(c.fontSize*.85)}px ${c.fontFamily}`;d.font=l,d.textBaseline="middle";const b=d.measureText(u).width+r*2,T=s+(i-p)/2,g=h==="start"?n+2:n+o-b-2;d.shadowColor="rgba(0,0,0,0.25)",d.shadowBlur=3,d.shadowOffsetY=1;const m=t.color??"#ffffff";d.fillStyle=m,this.roundedRectPath(g,T,b,p,p/2),d.fill(),d.shadowColor="transparent",d.shadowBlur=0,d.shadowOffsetY=0,d.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),d.textAlign="center",d.fillText(u,g+b/2,T+p/2),d.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:c}=this,d=(s-Pi*2)/2,u=n+s/2;c.save(),c.beginPath(),c.moveTo(t,u-d),c.lineTo(t+d,u),c.lineTo(t,u+d),c.lineTo(t-d,u),c.closePath(),c.fillStyle=o,c.fill(),a&&(c.strokeStyle=i.barSelectedBorder,c.lineWidth=pn,c.stroke()),c.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:c}=this;if(!t.label)return;c.save();const d=`${a.fontSize}px ${a.fontFamily}`;c.font=d,c.textBaseline="middle";const u=c.measureText(t.label).width,h=s+i/2;u+gs*2<=o?(c.beginPath(),c.rect(n,s,o,i),c.clip(),c.fillStyle=t.textColor,c.textAlign="left",c.fillText(t.label,n+gs,h)):(c.fillStyle=a.gridTextColor,c.textAlign="left",c.fillText(t.label,n+o+$i,h)),c.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=Ri,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,c=n.headerHeight,d=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,c,s.timelineHeaderBg);const u=d.length||2,h=c/u,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let l=0;l<d.length;l++){const f=d[l],b=l*h;for(const T of f){const g=T.x-o,m=T.width;if(g+m<0||g>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=us;const S=this.snapToPixelRaw(g+m);i.moveTo(S,b),i.lineTo(S,b+h),i.stroke(),i.save(),i.beginPath(),i.rect(g,b,m,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=l===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(T.label,g+m/2,b+h/2),i.restore()}}const r=this.snapToPixelRaw(c);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=us,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,c=Math.min(i,s/2,o/2);a.moveTo(t+c,n),a.lineTo(t+s-c,n),a.arcTo(t+s,n,t+s,n+c,c),a.lineTo(t+s,n+o-c),a.arcTo(t+s,n+o,t+s-c,n+o,c),a.lineTo(t+c,n+o),a.arcTo(t,n+o,t,n+o-c,c),a.lineTo(t,n+c),a.arcTo(t,n,t+c,n,c),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:c}=this;c.beginPath(),this.roundedRectPath(t,n,s,o,i),c.fillStyle=a,c.fill()}strokeRoundedRect(t,n,s,o,i,a,c){const{ctx:d}=this;d.beginPath(),this.roundedRectPath(t,n,s,o,i),d.strokeStyle=a,d.lineWidth=c,d.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const c=d=>d.toString(16).padStart(2,"0");return`#${c(s)}${c(o)}${c(i)}`}}const hs="ng-tree-grid-styles";function Oi(e,t){const n=e.querySelector(`#${hs}`);n&&n.remove();const s=document.createElement("style");s.id=hs,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function Ni(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function $t(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class Hi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;Oi(this.rootEl,a),this.columns=o,this.columnWidths=o.map(u=>u.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const c=Ni(n),d=c.map(u=>u.task.id);this.updateRows(c,d,t),this.currentVisibleIds=d}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const c=o.children[a],d=c.querySelector(".ng-th-text");d&&d.textContent!==t[a].header&&(d.textContent=t[a].header),c.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,c)=>{const d=document.createElement("th");d.className="ng-grid-th",d.setAttribute("data-field",a.field);const u=document.createElement("span");u.className="ng-th-text",u.textContent=a.header,d.appendChild(u);const h=document.createElement("span");h.className="ng-resize-handle",d.appendChild(h),this.attachResizeListener(h,c),i.appendChild(d)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,c=u=>{const h=u.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,l=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),l[n]&&(l[n].style.width=`${p}px`)},d=()=>{document.removeEventListener("mousemove",c),document.removeEventListener("mouseup",d),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",c),document.addEventListener("mouseup",d)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),c=new Map;for(const u of t)c.set(u.task.id,u);for(const[u,h]of this.rows)a.has(u)||(h.remove(),this.rows.delete(u));let d=null;for(let u=0;u<t.length;u++){const h=t[u],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,u,s):(r=this.createRow(h,u,s),this.rows.set(p,r)),r.style.height=`${i}px`,d?d.nextSibling!==r&&this.tbody.insertBefore(r,d.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),d=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,c=document.createElement("tr");c.className="ng-grid-row",c.setAttribute("data-task-id",t.task.id),c.style.height=`${a}px`,t.task.status==="group-header"?(c.classList.add("ng-group-row"),t.task.groupBg&&(c.style.background=t.task.groupBg)):n%2===1&&c.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&c.classList.add("ng-row-selected");for(const d of i){const u=this.createCell(t,d,s);c.appendChild(u)}return c}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const u=document.createElement("span");u.className="ng-expand-icon",t.expanded&&u.classList.add("ng-expanded"),u.innerHTML="&#9654;",u.setAttribute("data-expand",t.task.id),o.appendChild(u)}else{const u=document.createElement("span");u.className="ng-expand-spacer",o.appendChild(u)}if(t.children.length===0&&!t.task.groupBg){const u=document.createElement("span");u.className="ng-drag-handle",u.innerHTML="&#9776;",o.appendChild(u)}const c=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(c&&t.children.length===0){const u=document.createElement("span");u.className="ng-status-dot",u.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${c};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(u)}const d=document.createElement("span");d.className="ng-grid-cell-text",d.textContent=$t(t.task,n),o.appendChild(d)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=$t(t.task,n);return o}updateRowContent(t,n,s,o){var d;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const c=t.querySelectorAll("td.ng-grid-cell");for(let u=0;u<a.length;u++){const h=a[u],p=c[u];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const l=`${n.depth*20+8}px`;p.style.paddingLeft!==l&&(p.style.paddingLeft=l);const f=p.querySelector(".ng-expand-icon"),b=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(f)n.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{b&&b.remove();const y=document.createElement("span");y.className="ng-expand-icon",n.expanded&&y.classList.add("ng-expanded"),y.innerHTML="&#9654;",y.setAttribute("data-expand",n.task.id),p.insertBefore(y,p.firstChild)}else if(f){f.remove();const y=document.createElement("span");y.className="ng-expand-spacer",p.insertBefore(y,p.firstChild)}const T=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!T){const y=document.createElement("span");y.className="ng-drag-handle",y.innerHTML="&#9776;";const v=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");v?p.insertBefore(y,v):p.appendChild(y)}}else T&&T.remove();const g=p.querySelector(".ng-status-dot"),m=n.task.color||((d=o.config.colorMap)==null?void 0:d[n.task.status??""])||"";if(m&&n.children.length===0)if(g)g.style.background=m;else{const y=document.createElement("span");y.className="ng-status-dot",y.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${m};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const v=p.querySelector(".ng-grid-cell-text");v?p.insertBefore(y,v):p.appendChild(y)}else g&&g.remove();const S=p.querySelector(".ng-grid-cell-text");if(S){const y=$t(n.task,h);S.textContent!==y&&(S.textContent=y)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const l=document.createElement("span");l.className="ng-drag-handle",l.innerHTML="&#9776;",p.appendChild(l)}}else r&&(p.textContent="")}else{const r=$t(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class xi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class fs{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],c=this.testLayout(t,n,a,o);if(c!==null)return{type:c,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:c,barHeight:d}=s;if(t<i||t>i+c||n<a||n>a+d)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+c-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const u=i+s.progressWidth;if(Math.abs(t-u)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const ps=864e5;function _t(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/ps)}function Tt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ne(e,t){const n=Tt(e),s=new Date(n.getTime()+t*ps),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function ms(e,t,n){return Math.max(t,Math.min(n,e))}const Bi=3,Fi=300;class Ui{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new fs,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,c=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:c}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,c=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:c}}handlePointerMove(t){if(this.panning){t.preventDefault();const c=t.clientX-this.panStartClientX,d=t.clientY-this.panStartClientY,u=this.options.scrollManager;if(u){const h=Math.max(0,this.panOrigScrollX-c),p=Math.max(0,this.panOrigScrollY-d);u.setScrollPosition(h,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const c=o.tasks.get(a.taskId);if(c){const d=this.canvas.getBoundingClientRect();this.options.onHover(c,t.clientX-d.left,t.clientY-d.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const d=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=d.x,this.panOrigScrollY=d.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const c=o.tasks.get(a.taskId);if(c){this.dragOriginalStartDate=c.startDate,this.dragOriginalEndDate=c.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const d=Yi(a.type);d&&this.options.dispatch({type:"DRAG_START",drag:{type:d,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:c.startDate,originalEndDate:c.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=_t(i,o);let c="";if(this.dragHit.type==="bar"){const l=Ne(this.dragOriginalStartDate,a),f=Ne(this.dragOriginalEndDate,a);c=`${l} → ${f}`}else if(this.dragHit.type==="bar-left-edge")c=`Start → ${Ne(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")c=`End → ${Ne(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const l=this.dragHit.layout,{canvasX:f}=this.toCanvasCoords(t),b=f-l.x;c=`${Math.round(ms(b/l.width,0,1)*100)}%`}if(!c)return;if(!this.gestureLabelEl){const l=document.createElement("div");l.setAttribute("data-nga-gesture-label","1"),l.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(l),this.gestureLabelEl=l,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=c;const d=12,u=window.innerWidth||document.documentElement.clientWidth,h=this.gestureLabelEl.offsetWidth,p=Math.min(t.clientX+d,u-h-4),r=t.clientY+d;this.gestureLabelEl.style.left=`${p}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,c=this.options.getState().tasks.get(i.taskId);o<Bi?(this.options.dispatch({type:"DRAG_END"}),c&&this.handleClick(c)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Fi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var d,u,h,p,r,l,f,b,T,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,c=t.clientX-this.dragStartX;switch(a){case"bar":{const m=t.clientY-this.dragStartY,S=Math.abs(c),y=Math.abs(m),v=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),w=y>S*1.5&&y>12;if(v&&w){const C=this.options.getLayouts(),M=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),P=C.find(A=>A.rowIndex===M),_=P?P.taskId:null;let U=null;const B=C.slice().sort((A,L)=>A.rowIndex-L.rowIndex);for(const A of B){if(A.rowIndex>M)break;const L=A.taskId;typeof L=="string"&&L.indexOf("__bucket_header__")===0&&(U=L.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",M,"target=",_,"bucket=",U)}catch{}(u=(d=this.options).onBarReorderDrag)==null||u.call(d,s,_,M,U);break}const k=_t(c,o),D=Ne(this.dragOriginalStartDate,k),E=Ne(this.dragOriginalEndDate,k);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:D,endDate:E});try{console.log("[NG engine] drag commit move",s.id,D,E,"hasCb=",!!this.options.onTaskMove)}catch{}(p=(h=this.options).onTaskMove)==null||p.call(h,s,D,E);break}case"bar-left-edge":{const m=_t(c,o),S=Ne(this.dragOriginalStartDate,m),y=Tt(this.dragOriginalEndDate),w=Tt(S).getTime()>=y.getTime()?Ne(this.dragOriginalEndDate,-1):S;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:w,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,w,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(l=(r=this.options).onTaskResize)==null||l.call(r,s,w,this.dragOriginalEndDate);break}case"bar-right-edge":{const m=_t(c,o),S=Ne(this.dragOriginalEndDate,m),y=Tt(this.dragOriginalStartDate),w=Tt(S).getTime()<=y.getTime()?Ne(this.dragOriginalStartDate,1):S;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:w});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,w,"hasCb=",!!this.options.onTaskResize)}catch{}(b=(f=this.options).onTaskResize)==null||b.call(f,s,this.dragOriginalStartDate,w);break}case"progress-handle":{const m=this.dragHit.layout,{canvasX:S}=this.toCanvasCoords(t),y=S-m.x,v=ms(y/m.width,0,1),w=Math.round(v*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:w}}),(g=(T=this.options).onTaskProgressChange)==null||g.call(T,s,w);break}}this.options.dispatch({type:"DRAG_END"})}}function Yi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const He=12,vt=6,Ot=4,Wi=3;class ys{render(t,n,s,o,i,a,c){const{dependencies:d}=n;if(d.size===0)return;const u=new Map;for(const r of s)u.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,c,h,p-c),t.clip(),t.translate(-i,0);for(const r of d.values()){const l=u.get(r.source),f=u.get(r.target);if(!l||!f)continue;const b=r.type||"FS",{sourceX:T,sourceY:g,targetX:m,targetY:S}=this.getConnectionPoints(b,l,f,a,c);this.drawRoutedPath(t,b,T,g,m,S,o),this.drawArrowhead(t,b,m,S,o),this.drawConnectionDot(t,T,g,o),this.drawConnectionDot(t,m,S,o)}t.restore()}hitTest(t,n,s,o,i,a,c=8){const{dependencies:d}=s;if(d.size===0||n<a)return null;const u=new Map;for(const p of o)u.set(p.taskId,p);let h=null;for(const p of d.values()){const r=u.get(p.source),l=u.get(p.target);if(!r||!l)continue;const f=p.type||"FS",{sourceX:b,sourceY:T,targetX:g,targetY:m}=this.getConnectionPoints(f,r,l,i,a),S=t-g,y=n-m,v=Math.sqrt(S*S+y*y);if(v<=c+vt){(!h||v<h.dist)&&(h={depId:p.id,dist:v});continue}const w=f==="FS"||f==="SS"?g-He:g+He,k=Math.min(w,g),D=Math.max(w,g);if(t>=k-c&&t<=D+c&&Math.abs(n-m)<=c){const P=Math.abs(n-m);(!h||P<h.dist)&&(h={depId:p.id,dist:P})}const E=f==="FS"||f==="FF"?b+He:b-He,C=Math.min(b,E),M=Math.max(b,E);if(t>=C-c&&t<=M+c&&Math.abs(n-T)<=c){const P=Math.abs(n-T);(!h||P<h.dist)&&(h={depId:p.id,dist:P})}}return(h==null?void 0:h.depId)??null}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,c=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:c};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:c};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:c};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:c}}}drawRoutedPath(t,n,s,o,i,a,c){t.beginPath(),t.strokeStyle=c.dependencyColor,t.lineWidth=c.dependencyWidth,t.moveTo(s,o);const d=n==="FS"||n==="FF",u=n==="FS"||n==="SS",h=d?s+He:s-He,p=u?i-He:i+He;if(d?u?p>=h:i+He>=h:u?i-He<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const l=(o+a)/2;t.lineTo(h,o),t.lineTo(h,l),t.lineTo(p,l),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-vt,o-Ot),t.lineTo(s-vt,o+Ot)):(t.moveTo(s,o),t.lineTo(s+vt,o-Ot),t.lineTo(s+vt,o+Ot)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Wi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Nt=12,Xi=100,zi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Gi=`
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
`;function at(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function bs(e){const t=e.split("-");if(t.length!==3)return at(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?at(e):`${zi[n]} ${s}`}function Me(e,t,n){const s=n?` ${n}`:"";return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${at(e)}</span><span class="ng-tooltip-value${s}">${at(t)}</span></div>`}function Ht(e){return Number.isInteger(e)?String(e):e.toFixed(1)}function Ts(e,...t){var s;const n=e;for(const o of t){const i=n[o];if(typeof i=="number"&&!Number.isNaN(i))return i;const a=(s=e.metadata)==null?void 0:s[o];if(typeof a=="number"&&!Number.isNaN(a))return a}}function Vi(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.max(1,Math.round((s-n)/864e5)+1)}function vs(e,...t){var n;for(const s of t){const o=(n=e.metadata)==null?void 0:n[s];if(typeof o=="string"&&o.length>0)return o}}function Ss(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.round((s-n)/864e5)}function ws(e){return e===0?"on time":e>0?`+${e}d`:`−${Math.abs(e)}d`}function Ki(e,t,n){const s=Math.round((e.progress??0)*100),o=Ts(e,"estimatedHours","estimateHours","hours"),i=Ts(e,"loggedHours","actualHours");let a="";e.status&&(a+=Me("Status",e.status)),e.priority&&(a+=Me("Priority",e.priority)),a+=Me("Assignee",e.assignee||"Unassigned");const c=Vi(e.startDate,e.endDate),d=`${bs(e.startDate)} → ${bs(e.endDate)}`;a+=Me("Dates",c?`${d} (${c}d)`:d),s>0&&(a+=Me("Progress",`${s}%`));let u="";if(o!=null&&(u+=Me("Estimate",`${Ht(o)}h`)),i!=null&&(u+=Me("Logged",`${Ht(i)}h`)),o!=null&&i!=null&&o>0){const S=Math.round(i/o*100),y=i>o,v=o-i,w=y?`${S}% (${Ht(i-o)}h over)`:`${S}% (${Ht(v)}h left)`;u+=Me("Used",w,y?"ng-tooltip-over":void 0)}const h=n==null?void 0:n.depSummary;h&&(h.blocks>0||h.blockedBy>0)&&(h.blockedBy>0&&(a+=Me("Blocked by",`${h.blockedBy} task${h.blockedBy===1?"":"s"}`)),h.blocks>0&&(a+=Me("Blocks",`${h.blocks} task${h.blocks===1?"":"s"}`)));let p="";const r=vs(e,"baselineStart","baselineStartDate"),l=vs(e,"baselineEnd","baselineEndDate");if(r){const S=Ss(r,e.startDate);S!=null&&(p+=Me("Start vs plan",ws(S),S>0?"ng-tooltip-over":void 0))}if(l){const S=Ss(l,e.endDate);S!=null&&(p+=Me("Finish vs plan",ws(S),S>0?"ng-tooltip-over":void 0))}let f="";if(Array.isArray(e.tooltipRows))for(const S of e.tooltipRows)!S||typeof S.label!="string"||typeof S.value!="string"||(f+=Me(S.label,S.value,S.emphasis?"ng-tooltip-over":void 0));const b=`<div class="ng-tooltip-id" title="Work item ID">${at(e.id)}</div>`,T=e.title||e.name,g=`<div class="ng-tooltip-header" style="border-left: 3px solid ${at(t)}"><span class="ng-tooltip-name">${at(T)}</span>${b}</div>`,m=S=>S?`<div class="ng-tooltip-divider"></div><div class="ng-tooltip-body">${S}</div>`:"";return`${g}<div class="ng-tooltip-body">${a}</div>${m(u)}${m(p)}${m(f)}`}class ks{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Gi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o,i){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const h=this.customRenderer(t);typeof h=="string"?this.tooltipEl.innerHTML=h:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(h))}else this.tooltipEl.innerHTML=Ki(t,o,i);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const a=this.tooltipEl.getBoundingClientRect(),c=this.container.getBoundingClientRect();let d=n+Nt,u=s+Nt;d+a.width>c.width&&(d=n-Nt-a.width),u+a.height>c.height&&(u=s-Nt-a.height),d=Math.max(0,d),u=Math.max(0,u),this.tooltipEl.style.left=`${d}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Xi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const mn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},Ds={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},ji=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function Es(e){const t=qi(e.theme);return{columns:e.columns??ji,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function qi(e){return!e||e==="light"?{...mn}:e==="dark"?{...Ds}:{...mn,...e}}function ut(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const Cs="nimbus-gantt-root-styles";function Zi(){if(typeof document>"u"||document.getElementById(Cs))return;const e=document.createElement("style");e.id=Cs,e.textContent=`
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
  `,document.head.appendChild(e)}class Ji{constructor(t,n){this.lastRenderedZoom=null,this.renderRetries=0,this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.replayProvider=null,this.agent={getSnapshot:()=>{const h=this.getDisplayState();return{cursorDate:h.timeCursorDate?h.timeCursorDate.toISOString():null,zoomLevel:h.zoomLevel,tasks:Array.from(h.tasks.values()),dependencies:Array.from(h.dependencies.values()),selectedIds:Array.from(h.selectedIds),expandedIds:Array.from(h.expandedIds),flatVisibleIds:h.flatVisibleIds.slice()}},updateTask:(h,p)=>{this.store.dispatch({type:"UPDATE_TASK",taskId:h,changes:p})},addTask:h=>{this.store.dispatch({type:"ADD_TASK",task:h})},removeTask:h=>{this.store.dispatch({type:"REMOVE_TASK",taskId:h})},moveTask:(h,p,r)=>{this.store.dispatch({type:"TASK_MOVE",taskId:h,startDate:p,endDate:r})},addDependency:h=>{this.store.dispatch({type:"ADD_DEPENDENCY",dependency:h})},removeDependency:h=>{this.store.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:h})},setSelection:h=>{this.store.dispatch({type:"DESELECT_ALL"});for(const p of h)this.store.dispatch({type:"SELECT_TASK",taskId:p,multi:!0})},setZoom:h=>{this.store.dispatch({type:"SET_ZOOM",level:h})},scrubTo:h=>{this.store.dispatch({type:"SET_TIME_CURSOR",date:h?new Date(h):null})},history:()=>{const h=this.history;return h?{entries:h.entries().map(p=>({ts:p.ts,wallTs:p.wallTs,actionType:p.action.type,source:p.source,actor:p.actor})),annotations:h.annotations().slice(),lastWallTs:h.lastWallTs()}:null},appendAnnotation:(h,p,r)=>{const l=this.history;return l?(l.appendAnnotation({kind:h,taskId:p,payload:r}),!0):!1}},this.container=t,this.config=Es(n),Zi(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:c}=Ue(s,i),d=yt(s),u={tasks:s,dependencies:o,tree:a,flatVisibleIds:c,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:d,dragState:null,config:this.config};if(this.eventBus=new is,this.store=new gn(u),this.layoutEngine=new ds,this.timeScale=this.createTimeScale(u),this.canvasRenderer=new _i(this.timelinePanel),this.treeGrid=new Hi(this.gridPanel),this.scrollManager=new xi(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new ys,this.tooltipManager=new ks(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new Ui(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,l,f)=>{var b;p?this.tooltipManager.show(p,r,l,f,{depSummary:this.computeDepSummary(p.id)}):this.tooltipManager.hide();try{(b=n.onHover)==null||b.call(n,p,r,l,f)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){ut("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){ut("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(ut("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const d=os(this.store.getState(),t);for(const u of d)this.store.dispatch(u);ut("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=os(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,c=0;for(const d of n){let u=null;if(d.type==="UPDATE_TASK"?u=d.taskId:d.type==="ADD_TASK"?u=d.task.id:d.type==="REMOVE_TASK"&&(u=d.taskId),u&&typeof s=="number"){const h=this.lastAppliedTs.get(u);if(h!==void 0&&s<h){c++;continue}}this.store.dispatch(d),u&&typeof s=="number"&&this.lastAppliedTs.set(u,s),d.type==="UPDATE_TASK"?o++:d.type==="ADD_TASK"?i++:d.type==="REMOVE_TASK"&&a++}c>0&&ut("remote:dropped-stale",{kind:t.kind,count:c}),o+i+a>0&&ut("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getDisplayState(){const t=this.store.getState(),n=t.timeCursorDate;return!n||!this.replayProvider?t:this.replayProvider.snapshotAt(n)??t}registerReplayProvider(t){return this.replayProvider=t,()=>{this.replayProvider===t&&(this.replayProvider=null)}}setTimeCursor(t){this.store.dispatch({type:"SET_TIME_CURSOR",date:t})}getTimeCursor(){return this.store.getState().timeCursorDate??null}getState(){return this.store.getState()}computeDepSummary(t){let n=0,s=0;return this.store.getState().dependencies.forEach(i=>{i.source===t?n++:i.target===t&&s++}),{blocks:n,blockedBy:s}}hitTestAt(t,n){const s=this.rootEl.getBoundingClientRect();if(!(t>=s.left&&t<=s.right&&n>=s.top&&n<=s.bottom))return{zone:"outside"};const i=this.getDisplayState(),{config:a,scrollX:c,scrollY:d,flatVisibleIds:u,tasks:h}=i,{headerHeight:p,rowHeight:r}=a,l=this.gridPanel.getBoundingClientRect(),f=this.timelinePanel.getBoundingClientRect(),b=t>=l.left&&t<=l.right&&n>=l.top&&n<=l.bottom&&l.width>0,T=t>=f.left&&t<=f.right&&n>=f.top&&n<=f.bottom;if(T&&n-f.top<p){const w=t-f.left+c;let k;try{k=this.timeScale.xToDate(w)}catch{k=new Date}const D=n-f.top,E=(()=>{try{return this.timeScale.getHeaderRows()}catch{return[]}})(),C=Math.max(1,E.length),M=p/C,P=Math.min(C-1,Math.max(0,Math.floor(D/M))),_=Qi(i.zoomLevel,C,P);return{zone:"date-header",date:k,level:_}}const g=p,m=(T?n-f.top:n-l.top)-g;if(m<0)return{zone:"outside"};const S=Math.floor((m+d)/r),v=(w=>w<0||w>=u.length?null:h.get(u[w])??null)(S);if(T&&v){if(v.status==="group-header")return{zone:"bucket-header",bucketTask:v,bucketId:v.groupId??null,rowIndex:S};const w=this.layouts.find(k=>k.taskId===v.id)??null;if(w){const k=t-f.left+c,D=6;if(w.isMilestone){const E=w.barHeight/2;if(Math.abs(k-w.x)<=E)return{zone:"bar",task:v,rowIndex:S,barType:"body"}}else if(k>=w.x-D&&k<=w.x+w.width+D){const M=k<=w.x+6?"left-edge":k>=w.x+w.width-6?"right-edge":"body";return{zone:"bar",task:v,rowIndex:S,barType:M}}}}if(b&&v)return v.status==="group-header"?{zone:"bucket-header",bucketTask:v,bucketId:v.groupId??null,rowIndex:S}:{zone:"row-label",task:v,rowIndex:S};if(T){const w=t-f.left+c,k=n-f.top;try{const D=this.dependencyRenderer.hitTest(w,k,i,this.layouts,d,p);if(D)return{zone:"dependency",depId:D}}catch{}}if(S>=u.length){let w;try{w=this.timeScale.xToDate(t-f.left+c)}catch{w=new Date}return{zone:"below-rows",date:w}}if(T){let w;try{w=this.timeScale.xToDate(t-f.left+c)}catch{w=new Date}const k=ea(i,S);return{zone:"canvas-empty",date:w,rowIndex:S,nearestTask:v,bucketId:k}}return{zone:"outside"}}capabilities(){const t=this;return{version:"0.206.0",pushRemoteEvent:typeof this.pushRemoteEvent=="function",timeCursor:!0,history:!!t.history,replayProvider:!!this.replayProvider,pluginsInstalled:this.plugins.map(n=>n.name).join(",")}}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,c=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(c);const d=n.tasks.get(t);d&&this.scrollToDate(d.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}emit(t,...n){this.eventBus.emit(t,...n)}on(t,n){return this.eventBus.on(t,n)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.getDisplayState();if((this.timelinePanel.clientWidth<=0||this.timelinePanel.clientHeight<=0)&&this.renderRetries<90){this.renderRetries++,typeof requestAnimationFrame=="function"?requestAnimationFrame(()=>{this.destroyed||this.render()}):setTimeout(()=>{this.destroyed||this.render()},16);return}this.renderRetries=0;const n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;this.canvasRenderer.resize(i,a);const c=Math.max(0,s-i),d=Math.max(0,o-a);let u=t.scrollX;if(this.lastRenderedZoom!==null&&this.lastRenderedZoom!==t.zoomLevel){const l=this.timeScale.dateToX(new Date);Number.isFinite(l)&&(u=l-i/2)}this.lastRenderedZoom=t.zoomLevel;const h=Math.min(Math.max(0,u),c),p=Math.min(Math.max(0,t.scrollY),d);let r=t;if((h!==t.scrollX||p!==t.scrollY)&&(r={...t,scrollX:h,scrollY:p},this.scrollManager.setScrollPosition(h,p),this.store.dispatch({type:"SET_SCROLL",x:h,y:p})),this.canvasRenderer.render(r,this.layouts,this.timeScale),r.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const f=l.getContext("2d");f&&this.dependencyRenderer.render(f,r,this.layouts,r.config.theme,r.scrollX,r.scrollY,r.config.headerHeight)}}this.treeGrid.render(r,r.tree),this.treeGrid.setScrollY(r.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const f=this.timelinePanel.querySelector("canvas");if(f){const b=f.getContext("2d");b&&l.renderCanvas(b,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new ls(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){const t=this,n={getState:()=>this.store.getState(),dispatch:s=>this.store.dispatch(s),on:(s,o)=>this.eventBus.on(s,o),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:s=>this.timeScale.dateToX(s),xToDate:s=>this.timeScale.xToDate(s),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const s=this.store.getState(),{tree:o,flatIds:i}=Ue(s.tasks,s.expandedIds);s.tree=o,s.flatVisibleIds.length=0;for(const a of i)s.flatVisibleIds.push(a)}};return n.__gantt=t,n}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new gn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function Qi(e,t,n){if(t===2){if(e==="day")return n===0?"month":"day";if(e==="week")return n===0?"month":"week";if(e==="month")return n===0?"year":"month";if(e==="quarter")return n===0?"year":"quarter"}return e}function ea(e,t){if(t<0||t>=e.flatVisibleIds.length)return null;let n=e.tasks.get(e.flatVisibleIds[t]);for(;n;){if(n.status==="group-header")return n.groupId??n.id;if(!n.parentId)break;n=e.tasks.get(n.parentId)}const s=e.tasks.get(e.flatVisibleIds[t]);return(s==null?void 0:s.groupId)??null}function Is(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function Ms(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const c of Is(a)){let d=s.get(c);d||(d=[],s.set(c,d)),d.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),c=s.get(a);if(c)for(const d of c)o.has(d)||(o.add(d),i.push(d))}return o}function ta(e,t){const n=Ms(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const na=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function yn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function sa(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,c=null,d=null;function u(l){s.push(l),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const l=yn(n.getState()),f=s.pop();o.push(l),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const l=yn(n.getState()),f=o.pop();s.push(l),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(l){(l.ctrlKey||l.metaKey)&&(l.key==="z"||l.key==="Z")&&(l.shiftKey?(l.preventDefault(),p()):(l.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(l){n=l,d=l.on("render",()=>{if(c)return;const f=document.querySelector(".nimbus-gantt");f&&(c=f.parentElement??f,c.getAttribute("tabindex")||c.setAttribute("tabindex","-1"),a=r,c.addEventListener("keydown",a))})},middleware(l,f){if(i){f(l);return}if(na.has(l.type)&&n){const b=yn(n.getState());u(b),o=[]}f(l)},destroy(){a&&c&&c.removeEventListener("keydown",a),d&&d(),n=null,c=null,a=null,s=[],o=[]}}}const St=["day","week","month","quarter"];function oa(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function bn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function ia(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:c}=a,d=oa(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),c.length===0)return;if(!d)e.dispatch({type:"SELECT_TASK",taskId:c[0]});else{const u=c.indexOf(d);u>0&&e.dispatch({type:"SELECT_TASK",taskId:c[u-1]})}break}case"ArrowDown":{if(i.preventDefault(),c.length===0)return;if(!d)e.dispatch({type:"SELECT_TASK",taskId:c[0]});else{const u=c.indexOf(d);u<c.length-1&&e.dispatch({type:"SELECT_TASK",taskId:c[u+1]})}break}case"ArrowRight":{if(d)if(bn(d,a))if(!a.expandedIds.has(d))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d});else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}break}case"ArrowLeft":{if(d)if(bn(d,a))if(a.expandedIds.has(d))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d});else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}break}case"Enter":{if(!d)return;i.preventDefault();const u=a.tasks.get(d);if(u&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:u,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!d)return;const u=i.target;if(u.tagName==="INPUT"||u.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(d);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),c.length>0&&e.dispatch({type:"SELECT_TASK",taskId:c[0]});break}case"End":{if(i.preventDefault(),c.length>0){const u=c[c.length-1],h=(c.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:u})}break}case"+":case"=":{i.preventDefault();const u=St.indexOf(a.zoomLevel);u>0&&e.dispatch({type:"SET_ZOOM",level:St[u-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const u=St.indexOf(a.zoomLevel);u<St.length-1&&e.dispatch({type:"SET_ZOOM",level:St[u+1]});break}case" ":{if(!d)return;const u=i.target;if(u.tagName==="INPUT"||u.tagName==="TEXTAREA"||u.tagName==="BUTTON")return;bn(d,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const As="#D4A017",aa="rgba(212, 160, 23, 0.25)",ra=[6,4],la=1,ca=2,da=4,Rs=8,Ls=10,Ps=16,ua=6;function ga(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:c}=o,d=o.headerHeight,u=s.filter(r=>r.isMilestone);if(u.length===0)return;t.save();const h=d,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of u){const l=r.x,f=r.barY-a,b=r.barHeight,T=f+b/2,g=r.color===c.barDefaultColor?As:r.color||As;t.save(),t.beginPath(),t.strokeStyle=aa,t.lineWidth=la,t.setLineDash(ra),t.moveTo(l,h),t.lineTo(l,h+p),t.stroke(),t.setLineDash([]),t.restore();const m=(b-ca*2)/2;t.save(),t.beginPath(),t.moveTo(l,T-m),t.lineTo(l+m,T),t.lineTo(l,T+m),t.lineTo(l-m,T),t.closePath(),t.fillStyle=g,t.fill(),t.strokeStyle=$s(g,.25),t.lineWidth=1,t.stroke(),t.restore();const S=l+m+da,y=T-Ps/2;if(t.save(),t.beginPath(),t.strokeStyle=$s(g,.15),t.lineWidth=1.5,t.moveTo(S,y),t.lineTo(S,y+Ps),t.stroke(),t.beginPath(),t.moveTo(S,y),t.lineTo(S+Rs,y+Ls/2),t.lineTo(S,y+Ls),t.closePath(),t.fillStyle=g,t.fill(),t.restore(),r.label){const v=S+Rs+ua,w=T;t.save(),t.font=`600 ${c.fontSize}px ${c.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=c.gridTextColor,t.fillText(r.label,v,w),t.restore()}}t.restore()},destroy(){e=null}}}function $s(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const ha="rgba(100, 116, 139, 0.12)",fa="rgba(100, 116, 139, 0.25)",_s="#334155",pa="rgba(100, 116, 139, 0.2)",ma="#475569",ya=8,ba=6,Ta=2,qe=5,va=12,Sa=28,wa=8;function ka(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,c=null;function d(h){const p=new Map,r=[];for(const l of h.flatVisibleIds){const f=h.tasks.get(l);if(f)if(f.groupId){let b=p.get(f.groupId);b||(b={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,b)),b.taskIds.push(l)}else r.push(l)}n=Array.from(p.values()),o=[],s=new Map;for(const l of r)o.push(l);for(const l of n){const f=o.length,b=`__group_header__${l.groupId}`;if(o.push(b),s.set(f,l),!l.collapsed)for(const T of l.taskIds)o.push(T)}}function u(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,c=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const l=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const b=f.getBoundingClientRect(),T=r.clientY-b.top,g=l.config.headerHeight;if(T<g)return;const m=T-g+l.scrollY,S=Math.floor(m/l.config.rowHeight),y=s.get(S);y&&(r.preventDefault(),r.stopPropagation(),u(y.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let l=!1;for(const f of r.tasks.values())if(f.groupId){l=!0;break}if(!l){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(d(r),t.size>0){const f=new Set;for(const b of n)if(b.collapsed)for(const T of b.taskIds)f.add(T);if(f.size>0){const b=r.flatVisibleIds.filter(T=>!f.has(T));if(b.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const T of b)r.flatVisibleIds.push(T)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:l,scrollX:f,scrollY:b}=p,{theme:T}=l,g=l.headerHeight,m=l.rowHeight,S=h.canvas.width/(window.devicePixelRatio||1),y=h.canvas.height/(window.devicePixelRatio||1)-g;h.save(),h.beginPath(),h.rect(0,g,S,y),h.clip();let v=0;const w=[];for(const k of p.flatVisibleIds){const D=p.tasks.get(k);D&&!D.groupId&&w.push(k)}v=w.length;for(const k of n){const D=g+v*m-b;if(D+m>=g&&D<g+y){h.fillStyle=ha,h.fillRect(0,D,S,m),h.beginPath(),h.strokeStyle=fa,h.lineWidth=1,h.moveTo(0,Math.round(D+m)+.5),h.lineTo(S,Math.round(D+m)+.5),h.stroke();const E=va,C=D+m/2;h.save(),h.beginPath(),h.fillStyle=_s,k.collapsed?(h.moveTo(E,C-qe),h.lineTo(E+qe,C),h.lineTo(E,C+qe)):(h.moveTo(E-qe/2,C-qe/2),h.lineTo(E+qe/2,C-qe/2),h.lineTo(E,C+qe/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${T.fontSize}px ${T.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=_s;const M=Sa,P=D+m/2;h.fillText(k.groupName,M,P);const _=h.measureText(k.groupName).width;h.restore();const U=`${k.taskIds.length}`;h.save(),h.font=`${T.fontSize-1}px ${T.fontFamily}`;const A=h.measureText(U).width+ba*2,L=T.fontSize+Ta*2,F=M+_+wa,x=P-L/2;h.beginPath();const z=ya;h.moveTo(F+z,x),h.lineTo(F+A-z,x),h.arcTo(F+A,x,F+A,x+z,z),h.lineTo(F+A,x+L-z),h.arcTo(F+A,x+L,F+A-z,x+L,z),h.lineTo(F+z,x+L),h.arcTo(F,x+L,F,x+L-z,z),h.lineTo(F,x+z),h.arcTo(F,x,F+z,x,z),h.closePath(),h.fillStyle=pa,h.fill(),h.fillStyle=ma,h.textBaseline="middle",h.textAlign="center",h.fillText(U,F+A/2,P),h.restore()}v+=1,k.collapsed||(v+=k.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),c&&c(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const gt="__bucket_header__";function Os(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Da(e){return e.groupId??null}function Ea(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function Ca(e){const t=[...e.buckets].sort((r,l)=>r.order-l.order),n=new Map;t.forEach((r,l)=>n.set(r.id,l));const s=e.getBucket??Da,o=e.getBucketProgress??Ea,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,c=[],d=null;function u(r,l){c=t.map(f=>({config:f,taskIds:[],allTaskIds:[],collapsed:i.has(f.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const f of l){const b=r.tasks.get(f);if(!b)continue;const T=s(b);if(!T)continue;const g=n.get(T);g!==void 0&&c[g].taskIds.push(f)}for(const[f,b]of r.tasks){if(f.startsWith(gt))continue;const T=s(b);if(!T)continue;const g=n.get(T);g!==void 0&&c[g].allTaskIds.push(f)}for(const f of c){if(f.allTaskIds.length===0){f.progress=0,f.startDate=null,f.endDate=null,f.totalHours=0,f.totalLogged=0;continue}const b=[];let T=1/0,g=-1/0,m=0,S=0;for(const y of f.allTaskIds){const v=r.tasks.get(y);if(!v)continue;if(b.push(v),v.startDate){const k=bt(v.startDate).getTime();!isNaN(k)&&k<T&&(T=k)}if(v.endDate){const k=bt(v.endDate).getTime();!isNaN(k)&&k>g&&(g=k)}const w=v.metadata;typeof(w==null?void 0:w.hoursHigh)=="number"&&(m+=w.hoursHigh),typeof(w==null?void 0:w.hoursLogged)=="number"&&(S+=w.hoursLogged)}f.startDate=isFinite(T)?new Date(T):null,f.endDate=isFinite(g)?new Date(g):null,f.totalHours=m,f.totalLogged=S,f.progress=Math.max(0,Math.min(1,o(b)))}}function h(r){if(!r.startDate||!r.endDate)return null;const l=r.totalHours>0&&r.totalLogged>=r.totalHours,f=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),b=r.totalHours>0?`${r.totalHours}h (${f}% budget)`:`${r.allTaskIds.length} items`;return{id:`${gt}${r.config.id}`,name:b,startDate:Os(r.startDate),endDate:Os(r.endDate),progress:r.progress,color:l?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const l=a.getState();a.dispatch({type:"SET_SCROLL",x:l.scrollX,y:l.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,d=r.on("taskClick",((...l)=>{const f=l[0];let b=null;typeof f=="string"?b=f:f&&typeof f=="object"&&"id"in f&&(b=String(f.id)),b&&b.startsWith(gt)&&p(b.substring(gt.length))}))},middleware(r,l){if(l(r),!a)return;const f=a.getState(),b=[];for(const m of f.tasks.keys())m.startsWith(gt)&&b.push(m);for(const m of b)f.tasks.delete(m);const T=f.flatVisibleIds.filter(m=>!m.startsWith(gt));let g=!1;for(const m of f.tasks.values())if(s(m)!=null){g=!0;break}if(!g){if(c=[],T.length!==f.flatVisibleIds.length){f.flatVisibleIds.length=0;for(const m of T)f.flatVisibleIds.push(m)}return}u(f,T);for(const m of c){if(m.allTaskIds.length===0)continue;const S=h(m);if(S){f.tasks.set(S.id,S);for(const y of m.allTaskIds){const v=f.tasks.get(y);v&&(v.parentId=S.id)}m.collapsed?f.expandedIds.delete(S.id):f.expandedIds.add(S.id)}}a.rebuildTree()},destroy(){d&&d(),a=null,c=[],d=null,i.clear()}}}const Ia=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function Ma(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,c=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=c,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Ns=864e5,Aa=6,Ra=2,La=2,Pa=.18,$a=.4;function Hs(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Tn(e,t){return Math.round((t.getTime()-e.getTime())/Ns)}function ht(e,t){return new Date(e.getTime()+t*Ns)}function vn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const M=E.lag||0;s.get(E.source).push({target:E.target,lag:M,depId:E.id}),o.get(E.target).push({source:E.source,lag:M,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,c=new Map,d=new Map;for(const[E,C]of e){const M=Hs(C.startDate),P=Hs(C.endDate);c.set(E,M),d.set(E,P),a.set(E,Math.max(Tn(M,P),0))}const u=new Map,h=new Map,p=[],r=[],l=new Map(i);for(const E of n)l.get(E)===0&&(r.push(E),u.set(E,c.get(E)),h.set(E,d.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),u.get(E);const C=h.get(E);for(const M of s.get(E)){const{target:P,lag:_}=M,U=ht(C,_),B=u.get(P);(!B||U.getTime()>B.getTime())&&(u.set(P,U),h.set(P,ht(U,a.get(P))));const A=l.get(P)-1;l.set(P,A),A===0&&r.push(P)}}for(const E of n)u.has(E)||(u.set(E,c.get(E)),h.set(E,d.get(E)),p.push(E));let f=-1/0;for(const E of h.values())E.getTime()>f&&(f=E.getTime());const b=new Date(f);let T=1/0;for(const E of u.values())E.getTime()<T&&(T=E.getTime());const g=new Date(T),m=Tn(g,b),S=new Map,y=new Map;for(const E of n)s.get(E).length===0&&(y.set(E,b),S.set(E,ht(b,-a.get(E))));for(let E=p.length-1;E>=0;E--){const C=p[E];if(!y.has(C)){let M=1/0;for(const P of s.get(C)){const _=S.get(P.target);if(_){const U=ht(_,-P.lag);U.getTime()<M&&(M=U.getTime())}}M===1/0?y.set(C,b):y.set(C,new Date(M)),S.set(C,ht(y.get(C),-a.get(C)))}}for(const E of n)y.has(E)||(y.set(E,b),S.set(E,ht(b,-a.get(E))));const v=.5,w=new Set,k=new Map;for(const E of n){const C=u.get(E),M=h.get(E),P=S.get(E),_=y.get(E),U=Tn(C,P),B=Math.abs(U)<v;B&&w.add(E),k.set(E,{earlyStart:C,earlyFinish:M,lateStart:P,lateFinish:_,totalFloat:U,isCritical:B})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&w.has(E.source)&&w.has(E.target)&&D.add(E.id);return{criticalTaskIds:w,criticalDependencyIds:D,taskAnalysis:k,projectDuration:m}}function _a(){let e,t=null,n=[];function s(){const o=e.getState();t=vn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:c,headerHeight:d,rowHeight:u,barHeight:h}=i.config,p=c.criticalPathColor||"#E53E3E",r=i.scrollX,l=i.scrollY,f=d,b=e.getTimeScale(),T=new Map;for(const y of a)T.set(y.taskId,y);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const y of a){const v=t.taskAnalysis.get(y.taskId);if(!v||v.isCritical||v.totalFloat<=0)continue;const w=y.barY-l,k=h*$a,D=y.x+y.width,C=b.dateToX(v.lateFinish)-D;C>1&&(o.fillStyle=y.color,o.globalAlpha=Pa,o.fillRect(D,w+h-k,C,k),o.globalAlpha=1)}for(const y of a){if(!t.criticalTaskIds.has(y.taskId))continue;const v=y.x,w=y.barY-l,k=y.width,D=y.barHeight;if(!(w+D<f||w>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Aa;for(let E=0;E<Ra;E++){o.strokeStyle=p,o.lineWidth=La,o.beginPath();const C=c.barBorderRadius,M=Math.min(C,k/2,D/2);o.moveTo(v+M,w),o.lineTo(v+k-M,w),o.arcTo(v+k,w,v+k,w+M,M),o.lineTo(v+k,w+D-M),o.arcTo(v+k,w+D,v+k-M,w+D,M),o.lineTo(v+M,w+D),o.arcTo(v,w+D,v,w+D-M,M),o.lineTo(v,w+M),o.arcTo(v,w,v+M,w,M),o.closePath(),o.stroke()}o.restore()}}const g=6,m=4,S=12;for(const y of i.dependencies.values()){if(!t.criticalDependencyIds.has(y.id))continue;const v=T.get(y.source),w=T.get(y.target);if(!v||!w)continue;const k=v.x+v.width,D=v.barY+v.barHeight/2-l,E=w.x,C=w.barY+w.barHeight/2-l;o.beginPath(),o.strokeStyle=p,o.lineWidth=c.dependencyWidth+1;const M=k+S,P=E-S;if(o.moveTo(k,D),P>=M)o.lineTo(M,D),o.lineTo(M,C),o.lineTo(E,C);else{const _=(D+C)/2;o.lineTo(M,D),o.lineTo(M,_),o.lineTo(P,_),o.lineTo(P,C),o.lineTo(E,C)}o.stroke(),o.beginPath(),o.moveTo(E,C),o.lineTo(E-g,C-m),o.lineTo(E-g,C+m),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Oa=864e5,Na=.6,xs=.25,Ha="#38A169",xa="#E53E3E",Ba="#A0AEC0",Fa=10,Ua=4,Ze=16,Ya=3;function xt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Wa(e,t){return Math.round((t.getTime()-e.getTime())/Oa)}function Xa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:xt(s.startDate),end:xt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var b,T;if(t.size===0)return;const{theme:a,headerHeight:c,barHeight:d}=o.config,u=o.scrollX,h=o.scrollY,p=c,r=n.getTimeScale(),l=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-u,0);const f=d*Na;for(const g of i){if(g.isMilestone)continue;const m=t.get(g.taskId);if(!m)continue;const S=g.barY-h;if(S+d+f<p||S>s.canvas.height)continue;const y=r.dateToX(m.start),v=r.dateToX(m.end),w=Math.max(v-y,2),k=S+d+1;xt(((b=o.tasks.get(g.taskId))==null?void 0:b.startDate)||"");const D=xt(((T=o.tasks.get(g.taskId))==null?void 0:T.endDate)||""),E=Wa(m.end,D);let C;E<0?C=Ha:E>0?C=xa:C=Ba,s.save(),s.globalAlpha=xs,s.fillStyle=C;const M=Math.min(l,w/2,f/2);if(s.beginPath(),s.moveTo(y+M,k),s.lineTo(y+w-M,k),s.arcTo(y+w,k,y+w,k+M,M),s.lineTo(y+w,k+f-M),s.arcTo(y+w,k+f,y+w-M,k+f,M),s.lineTo(y+M,k+f),s.arcTo(y,k+f,y,k+f-M,M),s.lineTo(y,k+M),s.arcTo(y,k,y+M,k,M),s.closePath(),s.fill(),s.globalAlpha=xs*2,s.strokeStyle=C,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const P=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${Fa}px ${a.fontFamily}`;const B=s.measureText(P).width+Ua*2,A=g.x+g.width+4,L=k+(f-Ze)/2;s.globalAlpha=.85,s.fillStyle=C;const F=Ya;s.beginPath(),s.moveTo(A+F,L),s.lineTo(A+B-F,L),s.arcTo(A+B,L,A+B,L+F,F),s.lineTo(A+B,L+Ze-F),s.arcTo(A+B,L+Ze,A+B-F,L+Ze,F),s.lineTo(A+F,L+Ze),s.arcTo(A,L+Ze,A,L+Ze-F,F),s.lineTo(A,L+F),s.arcTo(A,L,A+F,L,F),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(P,A+B/2,L+Ze/2),s.restore()}}s.restore()},destroy(){}}}const Bs=5,za=5,Ga=.3,Va=15;function Ka(){let e,t=null,n=0,s=0;const o=[];function i(u){const{rowHeight:h,headerHeight:p}=u.config,r=u.scrollY,l=u.flatVisibleIds.length,f=a(u),b=Math.floor(r/h),T=Math.ceil((r+f)/h);let g=Math.max(0,b-Bs),m=Math.min(l,T+Bs);if(Math.abs(s)>0){const y=Math.min(Va,Math.ceil(Math.abs(s*Ga)/h));s>0?m=Math.min(l,m+y):g=Math.max(0,g-y)}const S=new Set;for(let y=g;y<m&&y<u.flatVisibleIds.length;y++)S.add(u.flatVisibleIds[y]);return{startRow:g,endRow:m,totalRows:l,visibleTaskIds:S}}function a(u){const p=u.flatVisibleIds.length*u.config.rowHeight-u.scrollY;return Math.min(800,Math.max(p,200))}function c(u){const h=performance.now();for(o.push({y:u,time:h});o.length>za;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],l=(r.time-p.time)/1e3;l>0&&(s=(r.y-p.y)/l)}n=u}const d={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const u=e.getState();return(!t||u.scrollY!==n)&&(c(u.scrollY),t=i(u)),t},filterLayouts(u){const h=d.getVisibleRange();return h.totalRows===0?[]:u.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(u){return d.getVisibleRange().visibleTaskIds.has(u)},getContentHeight(){if(!e)return 0;const u=e.getState();return u.flatVisibleIds.length*u.config.rowHeight+u.config.headerHeight}};return{name:"VirtualScrollPlugin",install(u){e=u},middleware(u,h){if(h(u),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(u.type)&&(t=null,u.type==="SET_SCROLL"||u.type==="SET_SCROLL_Y")){const r=e.getState();c(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:d}}const Ye=864e5,Sn=1,Fs=2,Us=.5,Ys=2,Bt=8,Ws=6,Xs=2,Ft=1e4;function wn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function zs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function rt(e){return Math.round(e)+.5}function Gs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Vs(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,c=o.rowHeight,d=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,d),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let u=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(u,0,r,d),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const l=p.align==="right"?u+r-8:p.align==="center"?u+r/2:u+8;e.fillText(p.header,l,d/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(u+r,0),e.lineTo(u+r,s),e.stroke(),u+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,d),e.lineTo(n,d),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const l=d+p*c;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,l,n,c)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,l+c),e.lineTo(n,l+c),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const b of a){const T=b.width??120,g=Gs(r,b.field);e.save(),e.beginPath(),e.rect(f,l,T,c),e.clip(),e.textBaseline="middle";const m=b.tree?8:0;e.textAlign=b.align==="right"?"right":b.align==="center"?"center":"left";const S=b.align==="right"?f+T-8:b.align==="center"?f+T/2:f+8+m;e.fillText(g,S,l+c/2),e.restore(),f+=T}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Ks(e,t,n,s,o){const{config:i}=t,a=i.theme,c=i.headerHeight,d=i.rowHeight,u=s.getTotalWidth(),h=t.flatVisibleIds.length*d,p=c+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,u,p),i.showWeekends){const{start:f,end:b}=t.dateRange,T=new Date(f);T.setUTCHours(0,0,0,0);const g=b.getTime();for(;T.getTime()<=g;){const m=T.getUTCDay();if(m===0||m===6){const S=o+s.dateToX(T),y=new Date(T.getTime()+Ye),v=o+s.dateToX(y);e.fillStyle=a.timelineWeekendBg,e.fillRect(S,c,v-S,h)}T.setTime(T.getTime()+Ye)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Us;for(const f of r){const b=rt(o+f);e.moveTo(b,c),e.lineTo(b,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,c+f*d,u,d));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:b,end:T}=t.dateRange;if(f.getTime()>=b.getTime()&&f.getTime()<=T.getTime()){const g=o+s.dateToX(f),m=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(g,c,m,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Fs,e.moveTo(rt(g),c),e.lineTo(rt(g),p),e.stroke()}}const l=a.barBorderRadius;for(const f of n){const b=o+f.x,T=f.barY,g=f.width,m=f.barHeight;if(f.isMilestone){const S=(m-Ys*2)/2,y=T+m/2;e.beginPath(),e.moveTo(b,y-S),e.lineTo(b+S,y),e.lineTo(b,y+S),e.lineTo(b-S,y),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(kn(e,b,T,g,m,l),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const S=zs(f.color,.2);e.save(),e.beginPath(),kn(e,b,T,g,m,l),e.clip(),e.fillStyle=S,e.fillRect(b,T,f.progressWidth,m),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),kn(e,b,T,g,m,l),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Xs,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const S=e.measureText(f.label).width,y=T+m/2;S+Bt*2<=g?(e.beginPath(),e.rect(b,T,g,m),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,b+Bt,y)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,b+g+Ws,y)),e.restore()}}ja(e,t,n,a,o),qa(e,s,i,a,o)}function ja(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const u of n)i.set(u.taskId,u);const a=12,c=6,d=4;e.save();for(const u of t.dependencies.values()){const h=i.get(u.source),p=i.get(u.target);if(!h||!p)continue;const r=u.type||"FS",l=h.barY+h.barHeight/2,f=p.barY+p.barHeight/2;let b,T;const g=r==="FS"||r==="FF",m=r==="FS"||r==="SS";switch(r){case"FS":b=o+h.x+h.width,T=o+p.x;break;case"SS":b=o+h.x,T=o+p.x;break;case"FF":b=o+h.x+h.width,T=o+p.x+p.width;break;case"SF":b=o+h.x,T=o+p.x+p.width;break}const S=g?b+a:b-a,y=m?T-a:T+a,v=g?m?y>=S:T+a>=S:m?T-a<=S:y<=S;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(b,l),v)e.lineTo(S,l),e.lineTo(S,f),e.lineTo(T,f);else{const w=(l+f)/2;e.lineTo(S,l),e.lineTo(S,w),e.lineTo(y,w),e.lineTo(y,f),e.lineTo(T,f)}e.stroke(),e.beginPath(),m?(e.moveTo(T,f),e.lineTo(T-c,f-d),e.lineTo(T-c,f+d)):(e.moveTo(T,f),e.lineTo(T+c,f-d),e.lineTo(T+c,f+d)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function qa(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const c=a.length||2,d=i/c;e.textBaseline="middle";for(let u=0;u<a.length;u++){const h=a[u],p=u*d;for(const r of h){const l=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=Sn,e.moveTo(rt(l+f),p),e.lineTo(rt(l+f),p+d),e.stroke(),e.save(),e.beginPath(),e.rect(l,p,f,d),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=u===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,l+f/2,p+d/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=Sn,e.moveTo(o,rt(i)),e.lineTo(o+t.getTotalWidth(),rt(i)),e.stroke()}function kn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function wt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Za(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,c=o.rowHeight,d=n.getTotalWidth(),u=s+d,h=e.flatVisibleIds.length*c,p=a+h,r=i.barBorderRadius,l=[];l.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${u}" height="${p}" viewBox="0 0 ${u} ${p}">`),l.push(`<style>text { font-family: ${wt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),l.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),l.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const y of o.columns){const v=y.width??120;l.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${wt(y.header)}</text>`),l.push(`<line x1="${f+v}" y1="0" x2="${f+v}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=v}for(let y=0;y<e.flatVisibleIds.length;y++){const v=e.tasks.get(e.flatVisibleIds[y]);if(!v)continue;const w=a+y*c;y%2===1&&l.push(`<rect x="0" y="${w}" width="${s}" height="${c}" fill="${i.gridAltRowBg}" />`);let k=0;for(const D of o.columns){const E=D.width??120,C=Gs(v,D.field),M=D.tree?8:0;l.push(`<text x="${k+8+M}" y="${w+c/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${C}]]></text>`),k+=E}l.push(`<line x1="0" y1="${w+c}" x2="${s}" y2="${w+c}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}l.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),l.push(`<line x1="0" y1="${a}" x2="${u}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),l.push(`<rect x="${s}" y="0" width="${d}" height="${p}" fill="${i.timelineBg}" />`),l.push(`<rect x="${s}" y="0" width="${d}" height="${a}" fill="${i.timelineHeaderBg}" />`);const b=n.getHeaderRows(),T=b.length||2,g=a/T;for(let y=0;y<b.length;y++){const v=b[y],w=y*g;for(const k of v){const D=s+k.x+k.width/2,E=w+g/2,C=y===0?' font-weight="600"':"";l.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${C} fill="${i.timelineHeaderText}">${wt(k.label)}</text>`),l.push(`<line x1="${s+k.x+k.width}" y1="${w}" x2="${s+k.x+k.width}" y2="${w+g}" stroke="${i.timelineGridColor}" stroke-width="${Sn}" />`)}}const m=n.getGridLines();for(const y of m)l.push(`<line x1="${s+y}" y1="${a}" x2="${s+y}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Us}" />`);for(let y=0;y<e.flatVisibleIds.length;y++)y%2===1&&l.push(`<rect x="${s}" y="${a+y*c}" width="${d}" height="${c}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:y,end:v}=e.dateRange,w=new Date(y);for(w.setUTCHours(0,0,0,0);w.getTime()<=v.getTime();){if(w.getUTCDay()===0||w.getUTCDay()===6){const k=s+n.dateToX(w),D=new Date(w.getTime()+Ye),E=s+n.dateToX(D);l.push(`<rect x="${k}" y="${a}" width="${E-k}" height="${h}" fill="${i.timelineWeekendBg}" />`)}w.setTime(w.getTime()+Ye)}}if(o.showToday){const y=new Date;y.setHours(0,0,0,0);const{start:v,end:w}=e.dateRange;if(y.getTime()>=v.getTime()&&y.getTime()<=w.getTime()){const k=s+n.dateToX(y),D=n.getColumnWidth();l.push(`<rect x="${k}" y="${a}" width="${D}" height="${h}" fill="${i.todayBg}" />`),l.push(`<line x1="${k}" y1="${a}" x2="${k}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${Fs}" />`)}}for(const y of t){const v=s+y.x,w=y.barY,k=y.width,D=y.barHeight;if(y.isMilestone){const E=(D-Ys*2)/2,C=w+D/2;l.push(`<polygon points="${v},${C-E} ${v+E},${C} ${v},${C+E} ${v-E},${C}" fill="${y.color}" />`);continue}if(l.push(`<rect x="${v}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="${y.color}" />`),o.showProgress&&y.progressWidth>0){const E=zs(y.color,.2);l.push(`<clipPath id="clip-${y.taskId}"><rect x="${v}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),l.push(`<rect x="${v}" y="${w}" width="${y.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${y.taskId})" />`)}if(e.selectedIds.has(y.taskId)&&l.push(`<rect x="${v}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Xs}" />`),y.label){const E=w+D/2;i.fontSize*.6*y.label.length+Bt*2<=k?l.push(`<text x="${v+Bt}" y="${E}" dominant-baseline="central" fill="${y.textColor}">${wt(y.label)}</text>`):l.push(`<text x="${v+k+Ws}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${wt(y.label)}</text>`)}}const S=new Map;for(const y of t)S.set(y.taskId,y);for(const y of e.dependencies.values()){const v=S.get(y.source),w=S.get(y.target);if(!v||!w)continue;const k=y.type||"FS",D=v.barY+v.barHeight/2,E=w.barY+w.barHeight/2;let C,M;const P=k==="FS"||k==="FF",_=k==="FS"||k==="SS";switch(k){case"FS":C=s+v.x+v.width,M=s+w.x;break;case"SS":C=s+v.x,M=s+w.x;break;case"FF":C=s+v.x+v.width,M=s+w.x+w.width;break;case"SF":C=s+v.x,M=s+w.x+w.width;break}const U=12,B=6,A=4,L=P?C+U:C-U,F=_?M-U:M+U,x=P?_?F>=L:M+U>=L:_?M-U<=L:F<=L;let z;if(x)z=`M${C},${D} L${L},${D} L${L},${E} L${M},${E}`;else{const O=(D+E)/2;z=`M${C},${D} L${L},${D} L${L},${O} L${F},${O} L${F},${E} L${M},${E}`}l.push(`<path d="${z}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),_?l.push(`<polygon points="${M},${E} ${M-B},${E-A} ${M-B},${E+A}" fill="${i.dependencyColor}" />`):l.push(`<polygon points="${M},${E} ${M+B},${E-A} ${M+B},${E+A}" fill="${i.dependencyColor}" />`)}return l.push("</svg>"),l.join(`
`)}function Ja(){let e=null;function t(){const a=e,c=a.getState(),d=a.getTimeScale(),{start:u,end:h}=c.dateRange,p=h.getTime()-u.getTime(),r=d.getColumnWidth(),l=c.zoomLevel;let f;switch(l){case"day":f=Math.round(p/Ye);break;case"week":f=Math.ceil(p/(Ye*7));break;case"month":{const T=u.getUTCFullYear(),g=u.getUTCMonth(),m=h.getUTCFullYear(),S=h.getUTCMonth();f=(m-T)*12+(S-g);break}case"quarter":{const T=u.getUTCFullYear(),g=Math.floor(u.getUTCMonth()/3),m=h.getUTCFullYear(),S=Math.floor(h.getUTCMonth()/3);f=(m-T)*4+(S-g);break}}const b=f*r;return{dateToX(T){return(T.getTime()-u.getTime())/p*b},getColumnWidth(){return r},getTotalWidth(){return b},getHeaderRows(){return tr(l,u,h,r,b)},getGridLines(){return this.getHeaderRows()[1].map(g=>g.x).filter(g=>g>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let c=0;for(const d of a.config.columns)c+=d.width??120;return c}function s(a){if(!e)return;const c=e.getState(),d=t(),u=e.getLayouts(),h=n(),p=d.getTotalWidth(),r=h+p,l=c.flatVisibleIds.length*c.config.rowHeight,f=c.config.headerHeight+l,b=a??"gantt-export.png";if(r>Ft||f>Ft){o(c,u,d,h,r,f,b);return}const T=document.createElement("canvas");T.width=r,T.height=f;const g=T.getContext("2d");g&&(h>0&&Vs(g,c,h,f),Ks(g,c,u,d,h),T.toBlob(m=>{m&&wn(m,b)},"image/png"))}function o(a,c,d,u,h,p,r){const l=Math.min(1,Ft/h,Ft/p),f=Math.ceil(h*l),b=Math.ceil(p*l),T=document.createElement("canvas");T.width=f,T.height=b;const g=T.getContext("2d");g&&(g.scale(l,l),u>0&&Vs(g,a,u,p),Ks(g,a,c,d,u),T.toBlob(m=>{m&&wn(m,r)},"image/png"))}function i(a){if(!e)return;const c=e.getState(),d=t(),u=e.getLayouts(),h=n(),p=Za(c,u,d,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});wn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...c)=>{s(c[0])}),a.on("export:svg",(...c)=>{i(c[0])})},destroy(){e=null}}}const js=["January","February","March","April","May","June","July","August","September","October","November","December"],qs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Zs(e,t){return new Date(e.getTime()+t*Ye)}function Dn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Qa(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function er(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function tr(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=c=>er(c,t,i,o);switch(e){case"day":{const c=[],d=[],u=Math.round(i/Ye);let h=new Date(t);for(let r=0;r<u;r++)d.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Zs(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=Dn(p),l=a(p),f=r.getTime()>=n.getTime()?o:a(r);c.push({label:`${js[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:l,width:f-l,date:new Date(p)}),p=r}return[c,d]}case"week":{const c=[],d=[],u=Math.ceil(i/(Ye*7));for(let p=0;p<u;p++){const r=Zs(t,p*7);d.push({label:`${qs[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=Dn(h),r=h.getTime()<t.getTime()?t:h,l=p.getTime()>n.getTime()?n:p;c.push({label:`${js[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(l)-a(r),date:new Date(r)}),h=p}return[c,d]}case"month":{const c=[],d=[],u=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),l=(p-u)*12+(r-h);let f=new Date(Date.UTC(u,h,1));for(let T=0;T<l;T++)d.push({label:qs[f.getUTCMonth()],x:T*s,width:s,date:new Date(f)}),f=Dn(f);let b=new Date(Date.UTC(u,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),g=b.getTime()<t.getTime()?t:b,m=T.getTime()>n.getTime()?n:T;c.push({label:String(b.getUTCFullYear()),x:a(g),width:a(m)-a(g),date:new Date(g)}),b=T}return[c,d]}case"quarter":{const c=[],d=[],u=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),l=(p-u)*4+(r-h);let f=new Date(Date.UTC(u,h*3,1));for(let T=0;T<l;T++){const g=Math.floor(f.getUTCMonth()/3)+1;d.push({label:`Q${g}`,x:T*s,width:s,date:new Date(f)}),f=Qa(f,3)}let b=new Date(Date.UTC(u,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),g=b.getTime()<t.getTime()?t:b,m=T.getTime()>n.getTime()?n:T;c.push({label:String(b.getUTCFullYear()),x:a(g),width:a(m)-a(g),date:new Date(g)}),b=T}return[c,d]}default:return[[],[]]}}const nr={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},En="nimbus-gantt-dark-theme-transition";function sr(){if(typeof document>"u"||document.getElementById(En))return;const e=document.createElement("style");e.id=En,e.textContent=`
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
  `,document.head.appendChild(e)}function or(){if(typeof document>"u")return;const e=document.getElementById(En);e&&e.remove()}function ir(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,c=null;function d(){if(!n||s)return;const l=n.getState();o={...l.config.theme};const f={...l.config.theme,...nr};Object.assign(l.config.theme,f),s=!0,p()}function u(){if(!n||!s||!o)return;const l=n.getState();Object.assign(l.config.theme,o),s=!1,p()}function h(){s?u():d()}function p(){if(!n)return;const l=n.getState();n.dispatch({type:"SET_SCROLL",x:l.scrollX,y:l.scrollY})}function r(l){l.matches?d():u()}return{name:"DarkThemePlugin",install(l){n=l,sr(),l.on("theme:toggle",()=>{h()}),l.on("theme:dark",()=>{d()}),l.on("theme:light",()=>{u()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(c=l.on("render",()=>{c&&(c(),c=null),i&&i.matches&&!s&&d()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),c&&c(),s&&n&&o){const l=n.getState();Object.assign(l.config.theme,o)}or(),n=null,o=null,i=null,a=null,s=!1}}}const Pe=864e5,ar=[1,2,3,4,5],rr="rgba(128, 128, 128, 0.06)",lr="rgba(128, 128, 128, 0.04)",cr="#f87171",kt=4;function Dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function xe(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function dr(e){const t=new Set((e==null?void 0:e.workDays)??ar),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const l=xe(r);return t.has(l.getUTCDay())}function i(r){const l=Dt(r);return n.has(l)?!1:t.has(r.getUTCDay())}function a(r){let l=xe(r);for(l=new Date(l.getTime()+Pe);!i(l);)l=new Date(l.getTime()+Pe);return Dt(l)}function c(r,l){if(l===0)return r;let f=xe(r);const b=l>0?1:-1;let T=Math.abs(l);if(!i(f))for(f=new Date(f.getTime()+b*Pe);!i(f);)f=new Date(f.getTime()+b*Pe);for(;T>0;)f=new Date(f.getTime()+b*Pe),i(f)&&T--;return Dt(f)}function d(r,l){const f=xe(r),b=xe(l);if(f.getTime()>b.getTime())return-d(l,r);let T=0,g=new Date(f.getTime());for(;g.getTime()<b.getTime();)i(g)&&T++,g=new Date(g.getTime()+Pe);return T}function u(r,l="forward"){if(o(r))return r;let f=xe(r);const b=l==="forward"?Pe:-Pe;for(let T=0;T<30;T++)if(f=new Date(f.getTime()+b),i(f))return Dt(f);return r}function h(r,l){if(r.type==="TASK_MOVE"){const f=u(r.startDate,"forward"),b=u(r.endDate,"backward"),T=xe(b).getTime()<xe(f).getTime()?f:b;l({...r,startDate:f,endDate:T});return}if(r.type==="TASK_RESIZE"){const f=u(r.startDate,"forward"),b=u(r.endDate,"backward"),T=xe(b).getTime()<xe(f).getTime()?f:b;l({...r,startDate:f,endDate:T});return}l(r)}function p(r,l,f){const{config:b}=l,T=b.headerHeight,g=l.flatVisibleIds.length*b.rowHeight,m=s==null?void 0:s.getTimeScale();if(!m||g===0)return;const{start:S,end:y}=l.dateRange,v=l.scrollX,w=l.scrollY;r.save();const k=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(k,0,0,k,0,0),r.beginPath(),r.rect(0,T,r.canvas.width/k,g),r.clip(),r.translate(-v,0);const D=new Date(S);D.setUTCHours(0,0,0,0);const E=y.getTime();for(m.getColumnWidth();D.getTime()<=E;){const C=Dt(D),M=n.has(C),P=!t.has(D.getUTCDay());if(M||P){const _=m.dateToX(D),U=new Date(D.getTime()+Pe),A=m.dateToX(U)-_;if(r.fillStyle=rr,r.fillRect(_,T-w,A,g+w),P&&!M){r.save(),r.beginPath(),r.rect(_,T,A,g),r.clip(),r.strokeStyle=lr,r.lineWidth=1;const L=8,F=g;for(let x=-F;x<A+F;x+=L)r.beginPath(),r.moveTo(_+x,T),r.lineTo(_+x+F,T+F),r.stroke();r.restore()}}if(M){const _=m.dateToX(D),U=new Date(D.getTime()+Pe),B=m.dateToX(U),A=(_+B)/2;r.save(),r.setTransform(k,0,0,k,0,0),r.translate(-v,0);const L=T-kt-3;r.beginPath(),r.moveTo(A,L-kt),r.lineTo(A+kt,L),r.lineTo(A,L+kt),r.lineTo(A-kt,L),r.closePath(),r.fillStyle=cr,r.fill(),r.restore()}D.setTime(D.getTime()+Pe)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...l)=>{const f=l[0],b=l[1],T=l[2],g=c(f,b);T&&T(g)}),r.on("calendar:workDaysBetween",(...l)=>{const f=l[0],b=l[1],T=l[2],g=d(f,b);T&&T(g)}),r.on("calendar:isWorkDay",(...l)=>{const f=l[0],b=l[1],T=o(f);b&&b(T)}),r.on("calendar:nextWorkDay",(...l)=>{const f=l[0],b=l[1],T=a(f);b&&b(T)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function ur(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function gr(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function hr(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=ur(),a=[],c=Date.now();let d=null,u=null,h=!1,p=[];const r=[];function l(y,v){if(h)return;const w={type:y,timestamp:Date.now(),sessionId:i,userId:n,data:v};a.push(w),o&&o(w)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const y=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(y),keepalive:!0}).catch(()=>{})}catch{}}function b(){u===null&&(u=setInterval(()=>{f()},s))}function T(){u!==null&&(clearInterval(u),u=null)}const g=gr(()=>{if(!d)return;const y=d.getState();l("gantt.scroll",{scrollX:y.scrollX,scrollY:y.scrollY}),y.scrollX,y.scrollY},1e3);let m=0;function S(y,v){switch(y.type){case"SET_ZOOM":{const w=d?d.getState().zoomLevel:"unknown";v(y),l("gantt.zoom",{oldLevel:w,newLevel:y.level});return}case"TASK_MOVE":{const w=m>0?Date.now()-m:0;v(y),l("gantt.task.move",{taskId:y.taskId,startDate:y.startDate,endDate:y.endDate,dragDurationMs:w}),m=0;return}case"TASK_RESIZE":{v(y),l("gantt.task.resize",{taskId:y.taskId,startDate:y.startDate,endDate:y.endDate});return}case"DRAG_START":{m=Date.now(),v(y);return}case"SELECT_TASK":{v(y),l("gantt.task.click",{taskId:y.taskId,multi:y.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{v(y),g();return}case"TOGGLE_EXPAND":{const w=d?d.getState().expandedIds.has(y.taskId):!1;v(y),l(w?"gantt.collapse":"gantt.expand",{taskId:y.taskId});return}case"EXPAND_ALL":{v(y),l("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{v(y),l("gantt.collapse",{all:!0});return}default:v(y);return}}return{name:"TelemetryPlugin",install(y){d=y,b();const v=y.getState();l("gantt.init",{taskCount:v.tasks.size,dependencyCount:v.dependencies.size,zoomLevel:v.zoomLevel}),setTimeout(()=>{h||l("gantt.feature.used",{plugins:p})},0);const w=y.on("taskClick",(...k)=>{const D=k[0];D&&l("gantt.task.click",{taskId:D.id})});r.push(w)},middleware:S,destroy(){h=!0;const y=Date.now()-c;l("gantt.session.duration",{durationMs:y,durationMinutes:Math.round(y/6e4*10)/10}),f(),T();for(const v of r)v();r.length=0,d=null}}}const Js=5,Cn=.15,In=.85,fr=2,Qs=30,We=["day","week","month","quarter"];function eo(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function pr(e,t,n){return Math.max(t,Math.min(n,e))}function mr(e){const t=pr((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let c=null,d=!1,u=0,h=0,p=0,r=null,l=null,f=null,b=null,T=null,g=null,m=0,S=0,y=0,v=!1;function w(B,A,L){y=B,m=A,S=L,v=!0,r===null&&(r=B)}function k(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(b=B=>{d||B.alpha==null||B.beta==null||B.gamma==null||w(B.alpha,B.beta,B.gamma)},window.addEventListener("deviceorientation",b),!0)}function D(){b&&(window.removeEventListener("deviceorientation",b),b=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function C(B){try{const A=JSON.parse(B);A.type==="orientation"?w(A.alpha,A.beta,A.gamma):A.type==="gesture"&&M(A.gesture)}catch{}}function M(B){if(!c)return;const A=c.getState();switch(B){case"tap":{A.selectedIds.size===0&&A.flatVisibleIds.length>0&&c.dispatch({type:"SELECT_TASK",taskId:A.flatVisibleIds[0]});break}case"doubletap":{c.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const L=We.indexOf(A.zoomLevel);L<We.length-1&&c.dispatch({type:"SET_ZOOM",level:We[L+1]});break}case"swipe-right":{const L=We.indexOf(A.zoomLevel);L>0&&c.dispatch({type:"SET_ZOOM",level:We[L-1]});break}}}function P(){if(d||typeof WebSocket>"u")return;const B=E();try{T=new WebSocket(B),T.onmessage=A=>{typeof A.data=="string"&&C(A.data)},T.onclose=()=>{T=null,d||(g=setTimeout(P,3e3))},T.onerror=()=>{T&&T.close()}}catch{d||(g=setTimeout(P,3e3))}}function _(){g!==null&&(clearTimeout(g),g=null),T&&(T.onmessage=null,T.onclose=null,T.onerror=null,T.close(),T=null)}function U(){if(!(d||!c)){if(v){u=u*In+m*Cn,h=h*In+S*Cn,p=p*In+y*Cn;const B=c.getState(),A=fr*a;if(n){const L=eo(h,Js);if(L!==0){const F=L*A,x=Math.max(0,B.scrollX+F);c.dispatch({type:"SET_SCROLL_X",x})}}if(s){const L=eo(u,Js);if(L!==0){const F=L*A,x=Math.max(0,B.scrollY+F);c.dispatch({type:"SET_SCROLL_Y",y:x})}}if(o&&r!==null){const F=(p-r+540)%360-180,x=We.indexOf(B.zoomLevel);if(F>Qs&&x>0){const z=We[x-1];l!==z&&(c.dispatch({type:"SET_ZOOM",level:z}),l=z,r=y)}else if(F<-Qs&&x<We.length-1){const z=We[x+1];l!==z&&(c.dispatch({type:"SET_ZOOM",level:z}),l=z,r=y)}}}f=requestAnimationFrame(U)}}return{name:"MotionControlPlugin",install(B){c=B,l=B.getState().zoomLevel,(!k()||i)&&P(),f=requestAnimationFrame(U)},destroy(){d=!0,f!==null&&(cancelAnimationFrame(f),f=null),D(),_(),c=null}}}const Et="http://schemas.microsoft.com/project",yr=8,to=4800,br={0:"FF",1:"FS",2:"SF",3:"SS"},Tr={FF:0,FS:1,SF:2,SS:3};function no(e){return e?e.substring(0,10):""}function so(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(Et,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function vr(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function Sr(e){return`PT${e*yr}H0M0S`}function Ct(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Mn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(Et,"Resource"),c=a.length>0?a:o.getElementsByTagName("Resource");for(let g=0;g<c.length;g++){const m=c[g],S=Ee(m,"UID"),y=Ee(m,"Name");S&&y&&i.set(S,y)}const d=new Map,u=o.getElementsByTagNameNS(Et,"Assignment"),h=u.length>0?u:o.getElementsByTagName("Assignment");for(let g=0;g<h.length;g++){const m=h[g],S=Ee(m,"TaskUID"),y=Ee(m,"ResourceUID");if(S&&y){const v=i.get(y);v&&d.set(S,v)}}const p=[],r=[],l=o.getElementsByTagNameNS(Et,"Task"),f=l.length>0?l:o.getElementsByTagName("Task"),b=[];let T=1;for(let g=0;g<f.length;g++){const m=f[g],S=Ee(m,"UID"),y=Ee(m,"Name"),v=Ee(m,"Start"),w=Ee(m,"Finish"),k=Ee(m,"PercentComplete"),D=Ee(m,"Summary")==="1",E=Ee(m,"Milestone")==="1",C=parseInt(Ee(m,"OutlineLevel")||"0",10);if(S==="0"&&!y)continue;const M=`msp-${S}`,P=no(v),_=no(w);if(!P&&!E)continue;let U;C>0&&b[C-1]&&(U=b[C-1]),b[C]=M,b.length=C+1;const B={id:M,name:y||`Task ${S}`,startDate:P||_,endDate:_||P,progress:k?parseInt(k,10)/100:0,isMilestone:E,parentId:U,sortOrder:g},A=d.get(S);A&&(B.assignee=A),D&&(B.metadata={...B.metadata,isSummary:!0}),p.push(B);const L=m.getElementsByTagNameNS(Et,"PredecessorLink"),F=L.length>0?L:m.getElementsByTagName("PredecessorLink");for(let x=0;x<F.length;x++){const z=F[x],O=Ee(z,"PredecessorUID"),I=parseInt(Ee(z,"Type")||"1",10),$=Ee(z,"LinkLag"),R=$?parseInt($,10):0;if(!O||O==="0")continue;const N={id:`msp-dep-${T++}`,source:`msp-${O}`,target:M,type:br[I]??"FS",lag:R!==0?R/to:void 0};r.push(N)}}return{tasks:p,dependencies:r}}function An(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),c=Array.from(e.dependencies.values());function d(S){let y=1,v=S;for(;v!=null&&v.parentId;)y++,v=e.tasks.get(v.parentId);return y}const u=new Map,h=new Map;for(const S of a){const y=S.parentId??"__root__",v=(u.get(y)??0)+1;if(u.set(y,v),!S.parentId)h.set(S.id,String(v));else{const w=h.get(S.parentId)??"0";h.set(S.id,`${w}.${v}`)}}const p=new Set;for(const S of a)S.parentId&&p.add(S.parentId);const r=new Map;a.forEach((S,y)=>{r.set(S.id,y+1)});const l=new Map;for(const S of c){const y=l.get(S.target)??[];y.push(S),l.set(S.target,y)}const f=new Set;for(const S of a)S.assignee&&f.add(S.assignee);const b=Array.from(f),T=new Map;b.forEach((S,y)=>{T.set(S,y+1)});const g=[];g.push('<?xml version="1.0" encoding="UTF-8"?>'),g.push('<Project xmlns="http://schemas.microsoft.com/project">'),g.push(`  <Name>${Ct(n)}</Name>`),g.push(`  <Author>${Ct(s)}</Author>`),g.push(`  <CreationDate>${o}</CreationDate>`),g.push("  <CalendarUID>1</CalendarUID>"),g.push("  <Calendars>"),g.push("    <Calendar>"),g.push("      <UID>1</UID>"),g.push(`      <Name>${Ct(i)}</Name>`),g.push("      <IsBaseCalendar>1</IsBaseCalendar>"),g.push("    </Calendar>"),g.push("  </Calendars>"),g.push("  <Tasks>");for(const S of a){const y=r.get(S.id)??0,v=d(S),w=h.get(S.id)??"1",k=p.has(S.id),D=S.isMilestone??!1,E=so(S.startDate),C=so(S.endDate),M=vr(E,C),P=Sr(M),_=Math.round((S.progress??0)*100);g.push("    <Task>"),g.push(`      <UID>${y}</UID>`),g.push(`      <ID>${y}</ID>`),g.push(`      <Name>${Ct(S.name)}</Name>`),g.push(`      <Start>${S.startDate}T08:00:00</Start>`),g.push(`      <Finish>${S.endDate}T17:00:00</Finish>`),g.push(`      <Duration>${P}</Duration>`),g.push(`      <PercentComplete>${_}</PercentComplete>`),g.push(`      <Summary>${k?"1":"0"}</Summary>`),g.push(`      <Milestone>${D?"1":"0"}</Milestone>`),g.push(`      <OutlineLevel>${v}</OutlineLevel>`),g.push(`      <OutlineNumber>${w}</OutlineNumber>`);const U=l.get(S.id);if(U)for(const B of U){const A=r.get(B.source)??0;if(A===0)continue;const L=Tr[B.type??"FS"]??1,F=Math.round((B.lag??0)*to);g.push("      <PredecessorLink>"),g.push(`        <PredecessorUID>${A}</PredecessorUID>`),g.push(`        <Type>${L}</Type>`),g.push(`        <LinkLag>${F}</LinkLag>`),g.push("      </PredecessorLink>")}g.push("    </Task>")}g.push("  </Tasks>"),g.push("  <Resources>");for(const S of b){const y=T.get(S)??0;g.push("    <Resource>"),g.push(`      <UID>${y}</UID>`),g.push(`      <Name>${Ct(S)}</Name>`),g.push("    </Resource>")}g.push("  </Resources>"),g.push("  <Assignments>");let m=1;for(const S of a){if(!S.assignee)continue;const y=r.get(S.id)??0,v=T.get(S.assignee)??0;y===0||v===0||(g.push("    <Assignment>"),g.push(`      <UID>${m++}</UID>`),g.push(`      <TaskUID>${y}</TaskUID>`),g.push(`      <ResourceUID>${v}</ResourceUID>`),g.push("    </Assignment>"))}return g.push("  </Assignments>"),g.push("</Project>"),g.join(`
`)}function wr(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=c=>{var u;const d=(u=c.target)==null?void 0:u.result;if(!(!d||!e))try{const h=Mn(d);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const c=Mn(a);o.dispatch({type:"SET_DATA",tasks:c.tasks,dependencies:c.dependencies})}catch(c){console.error("[MSProjectPlugin] Import failed:",c)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},c=i[1],d=o.getState(),u=An(d,a);c&&c(u)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},c=i[1]??"project-export.xml",d=o.getState(),u=An(d,a),h=new Blob([u],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=c,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const kr=[4,3],Dr=1.5,Er=.5,Cr=.06,Ir=4,Mr=8,Ar=.35,Rr=1,oo=.2,It=6,io=864e5;function Be(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ao(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Rn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Ln(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Lr(e){let t=0;for(const n of e){const s=Be(n.startDate).getTime(),o=Be(n.endDate).getTime();t+=Math.max(o-s,io)}return t}function Pr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const c=n.getState().tasks.get(s.taskId);if(c){const d=Be(c.startDate).getTime(),h=Be(s.startDate).getTime()-d,p=i.segments.map(r=>{const l=new Date(Be(r.startDate).getTime()+h),f=new Date(Be(r.endDate).getTime()+h);return{startDate:ao(l),endDate:ao(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const c=n.getState().tasks.get(s.taskId);if(c){const d=c.startDate,u=c.endDate;if(s.startDate!==d&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==u){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:c,scrollY:d}=o,{theme:u,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),l=u.barBorderRadius,f=h;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-c,0);for(const b of i){if(b.isMilestone)continue;const T=t.get(b.taskId);if(!T||T.segments.length===0)continue;const g=b.barY-d,m=b.barHeight,S=g+m/2;if(g+m<f||g>s.canvas.height)continue;const y=[];for(const C of T.segments){const M=r.dateToX(Be(C.startDate)),P=r.dateToX(Be(C.endDate)),_=Math.max(P-M,4);y.push({startX:M,endX:M+_,width:_})}s.save(),s.fillStyle=u.timelineBg,s.fillRect(b.x-1,g-1,b.width+2,m+2),s.restore();for(let C=0;C<y.length-1;C++){const M=y[C].endX,P=y[C+1].startX,_=P-M;if(!(_<=0)){s.save(),s.globalAlpha=Cr,s.strokeStyle=b.color,s.lineWidth=Ir,s.beginPath(),s.rect(M,g,_,m),s.clip();for(let U=M-m;U<P+m;U+=Mr)s.beginPath(),s.moveTo(U,g+m),s.lineTo(U+m,g),s.stroke();s.restore()}}for(let C=0;C<y.length-1;C++){const M=y[C].endX,P=y[C+1].startX;s.save(),s.globalAlpha=Er,s.strokeStyle=Rn(b.color,oo),s.lineWidth=Dr,s.setLineDash(kr),s.beginPath(),s.moveTo(M,S),s.lineTo(P,S),s.stroke(),s.setLineDash([]),s.restore()}const v=o.tasks.get(b.taskId),w=(v==null?void 0:v.progress)??0,k=Lr(T.segments);let E=w*k;for(let C=0;C<y.length;C++){const M=y[C],P=Math.max(Be(T.segments[C].endDate).getTime()-Be(T.segments[C].startDate).getTime(),io);if(s.save(),Ln(s,M.startX,g,M.width,m,l),s.fillStyle=b.color,s.fill(),s.strokeStyle=Rn(b.color,oo),s.lineWidth=Rr,s.stroke(),s.restore(),E>0&&a.showProgress){const _=Math.min(E,P),U=_/P,B=M.width*U;s.save(),Ln(s,M.startX,g,M.width,m,l),s.clip(),s.globalAlpha=Ar,s.fillStyle=Rn(b.color,.3),s.fillRect(M.startX,g,B,m),s.restore(),E-=_}}if(b.label){const C=y[0],M=y[y.length-1],P=M.endX-C.startX;s.save(),s.font=`${u.fontSize}px ${u.fontFamily}`;const U=s.measureText(b.label).width;s.textBaseline="middle",s.textAlign="left",U+It*2<=C.width?(s.fillStyle=b.textColor,Ln(s,C.startX,g,C.width,m,l),s.clip(),s.fillText(b.label,C.startX+It,S)):U+It<=P?(s.fillStyle=b.textColor,s.fillText(b.label,C.startX+It,S)):(s.fillStyle=u.gridTextColor,s.fillText(b.label,M.endX+It,S)),s.restore()}}s.restore()},destroy(){n=null}}}const Pn=864e5,ro=1e3,Ut=4,$r=.6,_r="#E53E3E",Or="#48BB78",Nr="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ft(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Yt(e,t){return Math.round((t.getTime()-e.getTime())/Pn)}function lo(e,t){return new Date(e.getTime()+t*Pn)}function Je(e,t){return ft(lo(he(e),t))}function Xe(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ft(n)),o;for(;i.getTime()<s.getTime();)o.push(ft(i)),i.setTime(i.getTime()+Pn);return o}class $n{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const c of s)i.set(c,(i.get(c)??0)+o),a.has(c)||a.set(c,new Set),a.get(c).add(n)}deallocate(t,n,s,o){var c,d;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const u of s){const p=(i.get(u)??0)-o;p<=0?i.delete(u):i.set(u,p),(c=a.get(u))==null||c.delete(n),((d=a.get(u))==null?void 0:d.size)===0&&a.delete(u)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var d;if(i===0)return!0;const a=this.grid.get(t),c=this.taskGrid.get(t);for(const u of s){let h=(a==null?void 0:a.get(u))??0;if((d=c==null?void 0:c.get(u))!=null&&d.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Wt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,c]of i)if(c>o.maxUnits){const d=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:c-o.maxUnits,taskIds:d})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Hr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const c=(o=a.metadata)==null?void 0:o[n];let d=1/0;if(typeof c=="number")d=c;else if(typeof c=="string"){const u=parseInt(c,10);isNaN(u)||(d=u)}s.set(i,{taskId:i,isCritical:!1,priority:d,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function co(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function xr(e,t,n,s,o){const i=new Map;for(const g of s)e.has(g.taskId)&&n.has(g.resourceId)&&(i.has(g.taskId)||i.set(g.taskId,[]),i.get(g.taskId).push({resourceId:g.resourceId,units:g.units||1}));const a=new Map,c=new Map;for(const g of e.keys())a.set(g,[]),c.set(g,[]);for(const g of t.values()){if((g.type||"FS")!=="FS"||!e.has(g.source)||!e.has(g.target))continue;const S=g.lag||0;a.get(g.source).push({target:g.target,lag:S}),c.get(g.target).push({source:g.source,lag:S})}const d=new Map;for(const[g,m]of e){const S=he(m.startDate),y=he(m.endDate);d.set(g,{taskId:g,startDate:m.startDate,endDate:m.endDate,duration:Math.max(Yt(S,y),0)})}const u=new $n;function h(){u.clear();for(const[g,m]of d){const S=i.get(g);if(!S)continue;const y=Xe(m.startDate,m.endDate);for(const v of S)u.allocate(v.resourceId,g,y,v.units)}}function p(g,m){const S=d.get(g);if(!S)return new Set;const y=new Set,v=S.startDate;if(m===v||he(m).getTime()<he(v).getTime())return y;const w=i.get(g);if(w){const k=Xe(S.startDate,S.endDate);for(const D of w)u.deallocate(D.resourceId,g,k,D.units)}if(S.startDate=m,S.endDate=Je(m,S.duration),y.add(g),w){const k=Xe(S.startDate,S.endDate);for(const D of w)u.allocate(D.resourceId,g,k,D.units)}return y}function r(g){const m=new Set,S=d.get(g);if(!S)return m;const y=a.get(g)??[];for(const{target:v,lag:w}of y){const k=d.get(v);if(!k)continue;const D=Je(S.endDate,w);if(he(k.startDate).getTime()<he(D).getTime()){const E=p(v,D);for(const C of E){m.add(C);const M=r(C);for(const P of M)m.add(P)}}}return m}function l(g){const m=c.get(g)??[];let S=d.get(g).startDate;S=e.get(g).startDate;for(const{source:v,lag:w}of m){const k=d.get(v);if(!k)continue;const D=Je(k.endDate,w);he(D).getTime()>he(S).getTime()&&(S=D)}return S}h();for(let g=0;g<ro;g++){const m=Wt(u,n);if(m.length===0)break;let S=!1;const y=m[0],v=y.taskIds.map(w=>o.get(w)).filter(w=>w!==void 0).sort(co);if(!(v.length<2))for(let w=1;w<v.length;w++){const k=v[w],D=d.get(k.taskId);if(!D)continue;const E=d.get(v[0].taskId);if(!E)continue;const C=E.endDate,M=l(k.taskId),P=he(C).getTime()>he(M).getTime()?C:M;he(P).getTime()>he(D.startDate).getTime()&&(p(k.taskId,P),r(k.taskId),S=!0);const _=u.getLoad(y.resourceId,y.date),U=n.get(y.resourceId).maxUnits;if(_<=U)break}}const f=new Map;let b=0;for(const[g,m]of d){const S=e.get(g),y=Yt(he(S.startDate),he(m.startDate));y!==0&&(f.set(g,{startDate:m.startDate,endDate:m.endDate,delayDays:y}),b+=y)}const T=Wt(u,n);return{adjustedTasks:f,totalDelay:b,conflicts:T,resolved:T.length===0}}function Br(e,t,n,s,o){const i=new Map;for(const m of s)e.has(m.taskId)&&n.has(m.resourceId)&&(i.has(m.taskId)||i.set(m.taskId,[]),i.get(m.taskId).push({resourceId:m.resourceId,units:m.units||1}));const a=new Map;for(const m of e.keys())a.set(m,[]);for(const m of t.values())(m.type||"FS")==="FS"&&(!e.has(m.source)||!e.has(m.target)||a.get(m.target).push({source:m.source,lag:m.lag||0}));const c=Array.from(e.keys()).map(m=>o.get(m)).filter(m=>m!==void 0).sort(co),d=new Map,u=new $n,h=new Set,p=new Map;for(const[m,S]of e)p.set(m,Math.max(Yt(he(S.startDate),he(S.endDate)),0));function r(m){let y=e.get(m).startDate;const v=a.get(m)??[];for(const{source:w,lag:k}of v){const D=d.get(w);if(!D)continue;const E=Je(D.endDate,k);he(E).getTime()>he(y).getTime()&&(y=E)}return y}function l(m,S,y){const v=i.get(m);if(!v||v.length===0)return S;let w=S;const k=365*5;for(let D=0;D<k;D++){const E=Je(w,y),C=Xe(w,E);let M=!0;for(const P of v){const _=n.get(P.resourceId);if(!_||_.maxUnits===0)continue;const U=_.calendar?new Set(_.calendar):null;if(U&&C.some(A=>U.has(A))){M=!1;break}if(!u.canFit(P.resourceId,m,C,P.units,_.maxUnits)){M=!1;break}}if(M)return w;w=Je(w,1)}return S}const f=new Set(c.map(m=>m.taskId));for(let m=0;m<ro&&f.size>0;m++){let S=!1;for(const y of c){if(!f.has(y.taskId)||!(a.get(y.taskId)??[]).every(_=>h.has(_.source)))continue;const k=y.taskId,D=p.get(k)??0,E=r(k),C=l(k,E,D),M=Je(C,D);d.set(k,{taskId:k,startDate:C,endDate:M,duration:D});const P=i.get(k);if(P){const _=Xe(C,M);for(const U of P)u.allocate(U.resourceId,k,_,U.units)}h.add(k),f.delete(k),S=!0}if(!S){for(const y of f){const v=e.get(y),w=p.get(y)??0;d.set(y,{taskId:y,startDate:v.startDate,endDate:v.endDate,duration:w});const k=i.get(y);if(k){const D=Xe(v.startDate,v.endDate);for(const E of k)u.allocate(E.resourceId,y,D,E.units)}h.add(y)}f.clear()}}const b=new Map;let T=0;for(const[m,S]of d){const y=e.get(m),v=Yt(he(y.startDate),he(S.startDate));v!==0&&(b.set(m,{startDate:S.startDate,endDate:S.endDate,delayDays:v}),T+=v)}const g=Wt(u,n);return{adjustedTasks:b,totalDelay:T,conflicts:g,resolved:g.length===0}}function Fr(e,t,n,s){const o=[],i=Xe(n,Je(s,1)),a=i.length;for(const[c,d]of t){const u=new Map;let h=0,p=0;for(const f of i){const b=e.getLoad(c,f);u.set(f,b),h+=b,b>p&&(p=b)}const r=d.maxUnits===0?1:d.maxUnits,l=a>0?h/(a*r):0;o.push({resourceId:c,resourceName:d.name,dailyLoad:u,overallUtilization:Math.min(l,1),peakUtilization:p})}return o}function uo(e,t,n,s){const o=new $n,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,c]of e){const d=i.get(a);if(!d)continue;const u=s.get(a),h=(u==null?void 0:u.startDate)??c.startDate,p=(u==null?void 0:u.endDate)??c.endDate,r=Xe(h,p);for(const l of d)o.allocate(l.resourceId,a,r,l.units)}return o}function Ur(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const c=[];function d(){return null}function u(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:l,dependencies:f}=r;if(l.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const b=d(),T=Hr(l,b,n);s==="parallel"?i=Br(l,f,t,e.assignments,T):i=xr(l,f,t,e.assignments,T);const g=h(l,i.adjustedTasks),m=uo(l,t,e.assignments,i.adjustedTasks);return a=Fr(m,t,g.start,g.end),i}function h(r,l){let f=1/0,b=-1/0;for(const[T,g]of r){const m=l.get(T),S=he((m==null?void 0:m.startDate)??g.startDate).getTime(),y=he((m==null?void 0:m.endDate)??g.endDate).getTime();S<f&&(f=S),y>b&&(b=y)}if(f===1/0){const T=ft(new Date);return{start:T,end:T}}return{start:ft(new Date(f)),end:ft(new Date(b))}}function p(r){const l=[];for(const f of e.assignments)f.taskId===r&&l.push(f.resourceId);return l}return{name:"ResourceLevelingPlugin",install(r){o=r,u(),c.push(r.on("resourceLeveling:run",(...l)=>{const f=l[0],b=u();f&&f(b)})),c.push(r.on("resourceLeveling:result",(...l)=>{const f=l[0];f&&f(i)})),c.push(r.on("resourceLeveling:utilization",(...l)=>{const f=l[0];f&&f(a)})),c.push(r.on("resourceLeveling:conflicts",(...l)=>{const f=l[0];if(!f)return;const b=r.getState(),T=uo(b.tasks,t,e.assignments,new Map);f(Wt(T,t))}))},middleware(r,l){l(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&u()},renderCanvas(r,l,f){if(!i||a.length===0)return;const{config:b}=l,{headerHeight:T,rowHeight:g}=b,m=l.scrollX,S=l.scrollY,y=o==null?void 0:o.getTimeScale();if(!y)return;r.save(),r.beginPath(),r.rect(0,T,r.canvas.width,r.canvas.height-T),r.clip(),r.translate(-m,0);const v=new Map;for(const w of a)v.set(w.resourceId,w);for(const w of f){const k=p(w.taskId);if(k.length===0)continue;const D=v.get(k[0]);if(!D)continue;const E=t.get(k[0]);if(!E)continue;const C=E.maxUnits===0?1:E.maxUnits,P=w.barY+w.barHeight-S+1;if(P+Ut<T||P>r.canvas.height)continue;const _=l.tasks.get(w.taskId);if(!_)continue;const U=i.adjustedTasks.get(w.taskId),B=(U==null?void 0:U.startDate)??_.startDate,A=(U==null?void 0:U.endDate)??_.endDate,L=y.dateToX(he(B)),x=y.dateToX(he(A))-L;if(x<2)continue;r.fillStyle=Nr,r.fillRect(L,P,x,Ut);const z=Xe(B,A);for(const O of z){const I=D.dailyLoad.get(O)??0;if(I===0)continue;const $=y.dateToX(he(O)),N=y.dateToX(lo(he(O),1))-$,J=Math.min(I/C,2)/2*Ut,Z=I>C;r.globalAlpha=$r,r.fillStyle=Z?_r:Or,r.fillRect($,P+Ut-J,N,J),r.globalAlpha=1}}r.restore()},destroy(){for(const r of c)r();c.length=0,o=null,i=null,a=[]}}}const Xt=864e5;function ye(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ze(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function go(e,t){return Math.round((ye(t).getTime()-ye(e).getTime())/Xt)}function ho(e,t){return ze(new Date(ye(e).getTime()+t*Xt))}function fo(){return{addDays:ho,daysBetween:go}}function _n(e,t,...n){try{const s=e;if(typeof s.emit=="function")return s.emit(t,...n),!0}catch{}return!1}function po(e,t,n){const s=new Map,o=new Map,i=new Map;for(const h of e)s.set(h,[]),o.set(h,[]),i.set(h,0);for(const h of t.values()){if(!e.has(h.source)||!e.has(h.target))continue;const p={source:h.source,target:h.target,type:h.type||"FS",lag:h.lag||0,depId:h.id};s.get(h.source).push(p),o.get(h.target).push(p),i.set(h.target,(i.get(h.target)||0)+1)}const a=new Map(i),c=[],d=[];for(const h of e)a.get(h)===0&&c.push(h);for(;c.length>0;){n&&c.length>1&&c.sort(n);const h=c.shift();d.push(h);for(const p of s.get(h)){const r=a.get(p.target)-1;a.set(p.target,r),r===0&&c.push(p.target)}}const u=new Set;for(const h of e)d.includes(h)||u.add(h);return{successors:s,predecessors:o,inDegree:i,circularTaskIds:u,topoOrder:d}}function On(e,t,n,s){const o=new Set(e.keys()),i=[],a=new Map;if(o.size===0)return{scheduledTasks:a,violations:i,projectStart:n.projectStart||ze(new Date),projectEnd:n.projectStart||ze(new Date),totalDuration:0};const c=n.constraints||new Map,d=n.capacity,u=(d==null?void 0:d.pace)??1,h=d!=null&&d.hoursPerMonth&&d.hoursPerMonth>0&&u>0?d.hoursPerMonth*12/365*u:0,p=(d==null?void 0:d.demandOf)??(A=>{const L=A,F=typeof L.estimatedHours=="number"?L.estimatedHours:0,x=typeof L.loggedHours=="number"?L.loggedHours:0;return Math.max(0,F-x)}),r=A=>{try{return p(A)}catch{return 0}},l=d==null?void 0:d.priorityOf,f=l?A=>{try{return l(A)}catch{return 1}}:null,b=new Map,T=A=>Math.floor(ye(A).getTime()/Xt);function g(A,L,F){if(h<=0||F<=0)return!1;const x=Math.max(1,L),z=Math.min(F/x,h),O=T(A);let I=!1;for(let $=O;$<O+x;$++){const R=(b.get($)||0)+z;R>h+1e-6&&(I=!0),b.set($,R)}return I}function m(A,L,F){if(h<=0||F<=0)return{start:A,exhausted:!1};const x=Math.max(1,L),z=Math.min(F/x,h);let O=T(A),I=0,$=!1;e:for(;I++<3650;){for(let R=O;R<O+x;R++)if((b.get(R)||0)+z>h+1e-6){O=R+1;continue e}$=!0;break}for(let R=O;R<O+x;R++)b.set(R,(b.get(R)||0)+z);return{start:ze(new Date(O*Xt)),exhausted:!$}}let S;h>0&&f&&(S=(A,L)=>{const F=f(e.get(A)),x=f(e.get(L));if(F!==x)return F-x;const z=e.get(A).startDate,O=e.get(L).startDate;return z!==O?z<O?-1:1:A<L?-1:A>L?1:0});const y=po(o,t,S);for(const A of y.circularTaskIds){const L=e.get(A);i.push({taskId:A,type:"circular",message:`Task "${(L==null?void 0:L.name)||A}" is part of a circular dependency chain`})}const v=new Map;for(const[A,L]of e){const F=s.daysBetween(L.startDate,L.endDate);v.set(A,Math.max(F,0))}const w=new Set;if(h>0)for(const[A,L]of c){if(L.type!=="MSO"&&L.type!=="MFO"||!L.date)continue;const F=e.get(A);if(!F)continue;const x=v.get(A),z=L.type==="MSO"?L.date:s.addDays(L.date,-x);g(z,x,r(F))&&i.push({taskId:A,type:"resource",message:`Task "${F.name}" (${L.type} ${L.date}) exceeds the capacity ceiling on its fixed dates.`}),w.add(A)}let k;if(n.projectStart)k=n.projectStart;else{let A=1/0;for(const x of e.values()){const z=ye(x.startDate).getTime();Number.isFinite(z)&&z<A&&(A=z)}const L=Date.now(),F=Number.isFinite(A)?Math.max(A,L):L;k=ze(new Date(F))}const D=new Map,E=new Map,C=new Set;for(const[A,L]of e)D.set(A,L.startDate),E.set(A,L.endDate);for(const A of y.topoOrder){const L=e.get(A),F=v.get(A),x=c.get(A),z=y.predecessors.get(A);let O;if(z.length===0)O=k;else{let $=k;for(const R of z){const N=D.get(R.source),W=E.get(R.source);let J;switch(R.type){case"FS":J=s.addDays(W,R.lag);break;case"SS":J=s.addDays(N,R.lag);break;case"FF":{const Z=s.addDays(W,R.lag);J=s.addDays(Z,-F);break}case"SF":{const Z=s.addDays(N,R.lag);J=s.addDays(Z,-F);break}default:J=s.addDays(W,R.lag)}ye(J).getTime()>ye($).getTime()&&($=J)}O=$}if(x)switch(x.type){case"ASAP":break;case"ALAP":C.add(A);break;case"SNET":x.date&&ye(O).getTime()<ye(x.date).getTime()&&(O=x.date);break;case"SNLT":x.date&&ye(O).getTime()>ye(x.date).getTime()&&i.push({taskId:A,type:"constraint",message:`Task "${L.name}" cannot start by ${x.date} (earliest possible: ${O}). SNLT constraint violated.`});break;case"MSO":x.date&&(ye(O).getTime()>ye(x.date).getTime()&&i.push({taskId:A,type:"constraint",message:`Task "${L.name}" has MSO constraint ${x.date} but dependencies require start no earlier than ${O}.`}),O=x.date);break;case"FNET":{if(x.date){const $=s.addDays(x.date,-F);ye(O).getTime()<ye($).getTime()&&(O=$)}break}case"FNLT":{if(x.date){const $=s.addDays(O,F);ye($).getTime()>ye(x.date).getTime()&&i.push({taskId:A,type:"constraint",message:`Task "${L.name}" cannot finish by ${x.date} (earliest finish: ${$}). FNLT constraint violated.`})}break}case"MFO":if(x.date){const $=s.addDays(x.date,-F);ye(O).getTime()>ye($).getTime()&&i.push({taskId:A,type:"constraint",message:`Task "${L.name}" has MFO constraint ${x.date} but dependencies require start no earlier than ${O} (finish would be ${s.addDays(O,F)}).`}),O=$}break}if(h>0&&!C.has(A)&&!w.has(A)){const $=r(L);if(x&&(x.type==="MSO"||x.type==="MFO"))g(O,F,$)&&i.push({taskId:A,type:"resource",message:`Task "${L.name}" exceeds the capacity ceiling on its fixed dates.`});else{const N=m(O,F,$);O=N.start,N.exhausted&&i.push({taskId:A,type:"resource",message:`Task "${L.name}" could not be capacity-leveled within ~10 years — placed overloaded at ${O}. Raise the pace or reduce scope.`})}}const I=s.addDays(O,F);D.set(A,O),E.set(A,I)}if(C.size>0){let A=-1/0;for(const F of E.values()){const x=ye(F).getTime();x>A&&(A=x)}const L=ze(new Date(A));for(let F=y.topoOrder.length-1;F>=0;F--){const x=y.topoOrder[F];if(!C.has(x))continue;const z=v.get(x),O=y.successors.get(x);let I;if(O.length===0)I=s.addDays(L,-z);else{let R=1/0;for(const N of O){const W=D.get(N.target);let J;switch(N.type){case"FS":J=s.addDays(W,-N.lag);break;case"SS":J=s.addDays(s.addDays(W,-N.lag),z);break;case"FF":J=s.addDays(E.get(N.target),-N.lag);break;case"SF":J=s.addDays(s.addDays(E.get(N.target),-N.lag),z);break;default:J=s.addDays(W,-N.lag)}const Z=s.addDays(J,-z),ie=ye(Z).getTime();ie<R&&(R=ie)}I=ze(new Date(R))}const $=D.get(x);ye(I).getTime()<ye($).getTime()&&(I=$),D.set(x,I),E.set(x,s.addDays(I,z))}}for(const A of o)a.set(A,{startDate:D.get(A),endDate:E.get(A)});let M=1/0,P=-1/0;for(const{startDate:A,endDate:L}of a.values()){const F=ye(A).getTime(),x=ye(L).getTime();F<M&&(M=F),x>P&&(P=x)}const _=ze(new Date(M)),U=ze(new Date(P)),B=s.daysBetween(_,U);return{scheduledTasks:a,violations:i,projectStart:_,projectEnd:U,totalDuration:B}}function Yr(e){const t={direction:"forward",respectWorkCalendar:!1,autoRun:!0,...e};let n,s,o=null,i=[];function a(){if(!t.respectWorkCalendar){s=fo();return}let l=null;_n(n,"calendar:addWorkDays","2026-01-05",1,f=>{l=f}),l!==null?s={addDays(f,b){let T=ho(f,b);return _n(n,"calendar:addWorkDays",f,b,g=>{T=g}),T},daysBetween(f,b){let T=go(f,b);return _n(n,"calendar:workDaysBetween",f,b,g=>{T=g}),T}}:s=fo()}function c(l){const f=n.getState();let b=f.tasks,T=f.dependencies;return l!=null&&l.tasks&&(b=Array.isArray(l.tasks)?new Map(l.tasks.map(g=>[g.id,g])):l.tasks),l!=null&&l.dependencies&&(T=Array.isArray(l.dependencies)?new Map(l.dependencies.map(g=>[g.id,g])):l.dependencies),{tasks:b,dependencies:T}}function d(l){if(!l)return t;const{tasks:f,dependencies:b,...T}=l;return{...t,...T}}function u(l){const f=c(l),b=On(f.tasks,f.dependencies,d(l),s);o=b;for(const[T,g]of b.scheduledTasks){const m=f.tasks.get(T);m&&(m.startDate!==g.startDate||m.endDate!==g.endDate)&&n.dispatch({type:"TASK_MOVE",taskId:T,startDate:g.startDate,endDate:g.endDate})}return b}function h(l){const f=c(l),b=On(f.tasks,f.dependencies,d(l),s);return o=b,b}function p(l){let f,b;for(const T of l)typeof T=="function"?b=T:T&&typeof T=="object"&&(f=T);return{overrides:f,callback:b}}function r(l,f){f(l),t.autoRun!==!1&&(l.type==="ADD_DEPENDENCY"||l.type==="REMOVE_DEPENDENCY")&&u()}return{name:"AutoSchedulePlugin",install(l){n=l,a(),i.push(n.on("autoSchedule:run",(...f)=>{const{overrides:b,callback:T}=p(f),g=u(b);T&&T(g)})),i.push(n.on("autoSchedule:preview",(...f)=>{const{overrides:b,callback:T}=p(f),g=h(b);T&&T(g)})),i.push(n.on("autoSchedule:result",(...f)=>{const b=f[0];b&&b(o)})),i.push(n.on("autoSchedule:setConstraint",(...f)=>{const b=f[0],T=f[1];t.constraints||(t.constraints=new Map),T?t.constraints.set(b,T):t.constraints.delete(b)})),i.push(n.on("autoSchedule:setConstraints",(...f)=>{const b=f[0];t.constraints=b}))},middleware:r,destroy(){for(const l of i)l();i=[],o=null}}}const Wr=864e5,Xr=75,zr=50,mo=25,zt=.3,Gt=.25,yo=.2,Nn=.15,Vt=.1,Gr=.3,bo=.5,Vr=20,To=40,Kr=3,jr=5,qr=30,vo=.25,So=4,Zr=2,Jr=5,Hn=5,wo=4,ko=.4,Qr=.003,Qe=260,pt=260,Do=16,Ge=14,el="rgba(30, 30, 46, 0.92)",xn="#e0e0e0",tl=10,Kt=32,nl=6,jt="#EF4444",qt="#F97316",Zt="#EAB308",Jt="#22C55E";function we(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ie(e,t){return Math.round((t.getTime()-e.getTime())/Wr)}function Ce(e,t,n){return Math.max(t,Math.min(n,e))}function sl(e){return e>=Xr?"critical":e>=zr?"high":e>=mo?"medium":"low"}function ol(e){switch(e){case"critical":return jt;case"high":return qt;case"medium":return Zt;case"low":return Jt}}function Qt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function il(e,t){const n=new Map,s=new Map;for(const g of e.keys())n.set(g,[]),s.set(g,[]);for(const g of t.values())!e.has(g.source)||!e.has(g.target)||(n.get(g.source).push(g.target),s.get(g.target).push(g.source));const o=new Map,i=new Set;function a(g){if(o.has(g))return o.get(g);if(i.has(g))return 0;i.add(g);let m=0;for(const S of n.get(g)||[])m+=1+a(S);return o.set(g,m),m}for(const g of e.keys())a(g);const c=new Map;for(const[g,m]of e){const S=we(m.startDate),y=we(m.endDate);c.set(g,Math.max(Ie(S,y),0))}const d=new Map,u=new Map,h=new Map;for(const g of e.keys())h.set(g,(s.get(g)||[]).length),d.set(g,c.get(g)||0),u.set(g,null);const p=[],r=new Map(h);for(const[g,m]of r)m===0&&p.push(g);for(;p.length>0;){const g=p.shift();for(const m of n.get(g)||[]){const S=d.get(g)+(c.get(m)||0);S>d.get(m)&&(d.set(m,S),u.set(m,g));const y=r.get(m)-1;r.set(m,y),y===0&&p.push(m)}}const l=new Set;let f=0,b=null;for(const[g,m]of d)m>f&&(f=m,b=g);let T=b;for(;T!==null;)l.add(T),T=u.get(T)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:l}}function al(e){const t=Qt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=we(o.startDate),a=we(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function rl(e,t,n){const s=[],o=Qt(),i=we(e.startDate),a=we(e.endDate),c=Math.max(Ie(i,a),1),d=Math.max(Ie(i,o),0),u=Math.max(Ie(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=Ie(a,o);p=Ce(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*zt)})}else{const D=u/c;D<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*zt)})):(p=Ce(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*zt)}))}let l=0;const f=Ce(d/c,0,1),b=f-h;b>bo?(l=Ce(Math.round(b*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(l*Gt)})):b>Gr?(l=Ce(Math.round(b*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(l*Gt)})):b>.1&&(l=Ce(Math.round(b*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(l*Gt)}));let T=0;const g=t.downstreamCount.get(e.id)||0,m=t.criticalPathIds.has(e.id);if(g>0){T=Ce(Math.round(Math.log2(g+1)*20),0,70),m&&(T=Ce(Math.round(T*1.5),0,100));const D=m?" (on critical path)":"";s.push({type:"dependency-chain",description:`${g} downstream dependent${g===1?"":"s"}${D}`,impact:Math.round(T*yo)})}let S=0;c>To?(S=60,s.push({type:"duration",description:`Long task (${c} days) — consider breaking into smaller deliverables`,impact:Math.round(S*Nn)})):c>Vr&&(S=35,s.push({type:"duration",description:`Medium-length task (${c} days) — monitor closely`,impact:Math.round(S*Nn)}));let y=0;if(!e.assignee)y=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(y*Vt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>jr?(y=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(y*Vt)})):D.length>Kr&&(y=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(y*Vt)}))}const v=Ce(Math.round(p*zt+l*Gt+T*yo+S*Nn+y*Vt),0,100),w=sl(v);let k;return r&&h===0?k="Task is overdue with no progress — escalate immediately":r?k="Task is past its deadline — review scope or extend timeline":b>bo?k="Task is significantly behind schedule — investigate blockers":c>To&&h<vo?k="Large task with little progress — consider splitting into smaller work items":(w==="high"||w==="critical")&&(k="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:w,riskScore:v,factors:s,suggestion:k}}function ll(e,t,n,s,o){const i=Qt();let a=0,c=0,d=0;for(const[m,S]of e){if(S.isCompleted||(S.progress??0)>=1)continue;c++;const y=we(S.startDate),v=we(S.endDate),w=Math.max(Ie(y,v),1),k=Math.max(Ie(y,i),0),D=Ce(k/w,0,1);(S.progress??0)>=D-.1&&a++;const C=t.get(m);C&&(C.riskLevel==="high"||C.riskLevel==="critical")&&d++}const u=c>0?a/c:1;let h=0;for(const m of n.criticalPathIds){const S=e.get(m);if(!S||S.isCompleted)continue;const y=we(S.endDate);i.getTime()>y.getTime()&&(h+=Ie(y,i))}const p=[],r=[];for(const[m,S]of s.activeTasks)p.push(S.length),S.length>So&&r.push(m);let l=100;if(p.length>1){const m=p.reduce((S,y)=>S+y,0)/p.length;if(m>0){const S=p.reduce((v,w)=>v+(w-m)**2,0)/p.length,y=Math.sqrt(S)/m;l=Ce(Math.round(100-y*50),0,100)}}let f=100;if(c>0){let m=0,S=0,y=0;for(const v of e.values()){if(v.isCompleted)continue;const w=we(v.startDate),k=we(v.endDate),D=Math.max(Ie(w,k),1),E=Math.max(Ie(w,i),0),C=Ce(E/D,0,2);m+=v.progress??0,S+=C,y++}if(y>0){const v=m/y,w=S/y;if(w>0){const k=v/w;f=Ce(Math.round(k*100),0,100)}}}const b=u*100,T=Ce(100-h*10,0,100);return{overallScore:Ce(Math.round(b*.25+T*.25+l*.25+f*.25),0,100),tasksAtRisk:d,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function cl(e,t,n,s){const o=[],i=Qt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const l=we(r.endDate),f=Ie(l,i),b=r.progress??0;f>Jr&&b===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const l=we(r.startDate),f=we(r.endDate),b=Ie(l,f),T=r.progress??0;if(b>qr&&T<vo){const g=Math.ceil(b/15);o.push({type:"split",description:`"${r.name}" spans ${b} days — split into ${g} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const c=[],d=[];for(const[p,r]of n.activeTasks)r.length>So?c.push({assignee:p,taskIds:r}):r.length<Zr&&d.push(p);if(c.length>0&&d.length>0)for(const{assignee:p,taskIds:r}of c){const l=r.filter(f=>!t.criticalPathIds.has(f));l.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${d.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:l,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const l=we(r.endDate),f=Ie(i,l);if(f>=0&&f<=5){const b=s.get(p);b&&b.riskScore>=mo&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const u=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>we(p.startDate).getTime()-we(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const l of r)h.add(`${l}->${p}`);for(let p=0;p<u.length;p++)for(let r=p+1;r<u.length;r++){const l=u[p],f=u[r],b=we(l.endDate),T=we(f.startDate);if(b.getTime()<=T.getTime()&&!(h.has(`${l.id}->${f.id}`)||h.has(`${f.id}->${l.id}`))){const m=Ie(b,T);m>0&&o.push({type:"parallel",description:`"${l.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${m} days on the critical path`,taskIds:[l.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function dl(e,t,n,s,o,i,a){if(e.save(),i){const c=ko+(1-ko)*(.5+.5*Math.sin(a*Qr));e.globalAlpha=c}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function ul(e,t,n,s,o,i){const a=Math.PI*.75,c=Math.PI*2.25,d=c-a,u=a+d*(i/100);e.beginPath(),e.arc(t,n,s,a,c),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Jt:i>=50?Zt:i>=25?qt:jt;e.beginPath(),e.arc(t,n,s,a,u),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=xn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function gl(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:jt,label:"Critical"},{count:o.high,color:qt,label:"High"},{count:o.medium,color:Zt,label:"Medium"},{count:o.low,color:Jt,label:"Low"}];let c=-Math.PI/2;for(const d of a){if(d.count===0)continue;const u=d.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,c,c+u),e.closePath(),e.fillStyle=d.color,e.fill(),c+=u}}function hl(e,t,n,s,o){const i=t-Qe-Do,a=n+Do;e.save(),e.beginPath();const c=tl;e.moveTo(i+c,a),e.lineTo(i+Qe-c,a),e.arcTo(i+Qe,a,i+Qe,a+c,c),e.lineTo(i+Qe,a+pt-c),e.arcTo(i+Qe,a+pt,i+Qe-c,a+pt,c),e.lineTo(i+c,a+pt),e.arcTo(i,a+pt,i,a+pt-c,c),e.lineTo(i,a+c),e.arcTo(i,a,i+c,a,c),e.closePath(),e.fillStyle=el,e.fill(),e.fillStyle=xn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Ge,a+Ge);const d=i+Ge+Kt+4,u=a+Ge+20+Kt+8;ul(e,d,u,Kt,nl,s.overallScore);const h=24,p=i+Qe-Ge-h-4,r=u;gl(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const l=r+h+8,f=[{count:o.critical,color:jt,label:"C"},{count:o.high,color:qt,label:"H"},{count:o.medium,color:Zt,label:"M"},{count:o.low,color:Jt,label:"L"}],b=28,T=p-f.length*b/2+b/2;for(let y=0;y<f.length;y++){const v=f[y],w=T+y*b;e.fillStyle=v.color,e.fillText(`${v.label}:${v.count}`,w,l)}const g=u+Kt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Ge,g);const m=g+18;e.font="10px sans-serif",e.fillStyle=xn,e.fillText("Recommendations:",i+Ge,m);const S=s.recommendations.slice(0,3);for(let y=0;y<S.length;y++){const v=S[y],w=m+14+y*16,k=v.type==="escalate"?"⚠":v.type==="split"?"✂":v.type==="reassign"?"⇄":v.type==="parallel"?"⇉":v.type==="add-buffer"?"⏱":"ℹ",D=34,E=v.description.length>D?v.description.substring(0,D-1)+"…":v.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${k} ${E}`,i+Ge,w)}S.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Ge,m+14)),e.restore()}function fl(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function c(){const d=e.getState(),{tasks:u,dependencies:h}=d;if(u.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=il(u,h),r=al(u),l=new Map;for(const[f,b]of u)l.set(f,rl(b,p,r));n=l,o=cl(u,p,r,n),s=ll(u,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(d){e=d,a=Date.now(),c(),t.push(e.on("risk:analysis",u=>{typeof u=="function"&&u(n)})),t.push(e.on("risk:health",u=>{typeof u=="function"&&u(s)})),t.push(e.on("risk:recommendations",u=>{typeof u=="function"&&u(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(d,u){u(d),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(d.type)&&c()},renderCanvas(d,u,h){if(n.size===0)return;const{headerHeight:p}=u.config,r=u.scrollX,l=u.scrollY,f=p,b=Date.now()-a;d.save(),d.beginPath(),d.rect(0,f,d.canvas.width,d.canvas.height-f),d.clip(),d.translate(-r,0);for(const T of h){const g=n.get(T.taskId);if(!g||g.riskLevel==="low")continue;const m=T.x,S=T.barY-l,y=T.width,v=T.barHeight;if(S+v<f||S>d.canvas.height||m+y<0)continue;const w=m+y-Hn-wo,k=S+Hn+wo,D=ol(g.riskLevel),E=g.riskLevel==="critical";dl(d,w,k,Hn,D,E,b)}if(d.restore(),i){const T={critical:0,high:0,medium:0,low:0};for(const g of n.values())T[g.riskLevel]++;d.save(),hl(d,d.canvas.width,p,s,T),d.restore()}},destroy(){for(const d of t)d();t=[],n=new Map,o=[]}}}const $e=160,et=80,Bn=8,pl=240,ml=160,yl=100,bl=200,en=8,Eo=.1,Co=3,Tl=.001,vl=500,Sl=5,wl=864e5,kl={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function Io(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Dl(e,t){return Math.round((t.getTime()-e.getTime())/wl)}function Mo(e,t,n){return e+(t-e)*n}function tn(e,t,n){return Math.max(t,Math.min(n,e))}function Fn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function El(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const c of e.keys())s.set(c,[]),o.set(c,[]),i.set(c,0);for(const c of t.values())!e.has(c.source)||!e.has(c.target)||(s.get(c.source).push(c.target),o.get(c.target).push(c.source),i.set(c.target,(i.get(c.target)||0)+1));const a=[];for(const[c,d]of i)d===0&&(a.push(c),n.set(c,0));for(;a.length>0;){const c=a.shift(),d=n.get(c);for(const u of s.get(c)){const h=n.get(u),p=d+1;(h===void 0||p>h)&&n.set(u,p);const r=i.get(u)-1;i.set(u,r),r===0&&a.push(u)}}for(const c of e.keys())n.has(c)||n.set(c,0);return n}function Cl(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Il(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let c=0;c<a.length;c++)i.set(a[c],c);for(let a=0;a<Sl;a++){for(let c=1;c<e.length;c++){const d=e[c],u=new Map;for(const h of d){const p=o.get(h);if(p.size===0){u.set(h,i.get(h)??0);continue}let r=0;for(const l of p)r+=i.get(l)??0;u.set(h,r/p.size)}d.sort((h,p)=>(u.get(h)??0)-(u.get(p)??0));for(let h=0;h<d.length;h++)i.set(d[h],h)}for(let c=e.length-2;c>=0;c--){const d=e[c],u=new Map;for(const h of d){const p=s.get(h);if(p.size===0){u.set(h,i.get(h)??0);continue}let r=0;for(const l of p)r+=i.get(l)??0;u.set(h,r/p.size)}d.sort((h,p)=>(u.get(h)??0)-(u.get(p)??0));for(let h=0;h<d.length;h++)i.set(d[h],h)}}}function Ml(e,t){const n=new Map;if(t==="radial")return Al(e);const s=t==="lr",o=s?pl:ml,i=s?yl:bl;for(let a=0;a<e.length;a++){const c=e[a],h=-((c.length-1)*i)/2;for(let p=0;p<c.length;p++){const r=c[p],l=h+p*i;s?n.set(r,{x:a*o,y:l}):n.set(r,{x:l,y:a*o})}}return n}function Al(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const c=a*i-Math.PI/2,d=n*.5;t.set(o[a],{x:Math.cos(c)*d,y:Math.sin(c)*d})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let c=0;c<o.length;c++){const d=c*a-Math.PI/2;t.set(o[c],{x:Math.cos(d)*i,y:Math.sin(d)*i})}}}return t}function Mt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Rl(e,t){return e.color?e.color:e.status&&(t[e.status]||kl[e.status])||"#94A3B8"}function Ll(e){const t=Io(e.startDate),n=Io(e.endDate);return Math.max(Dl(t,n),0)}function Pl(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,c=null,d=null,u=new Map,h=[],p=null,r=0,l=0,f=1,b=!1,T=0,g=0,m=0,S=0,y=null,v=0,w=0,k=null,D=null,E=new Set,C=!1,M=0,P=0,_=0,U=0;function B(G,H){return{x:(G-r)/f,y:(H-l)/f}}function A(G,H){const{x:Y,y:V}=B(G,H);for(const K of u.values()){const j=K.x,ne=K.y;if(Y>=j&&Y<=j+$e&&V>=ne&&V<=ne+et)return K}return null}function L(){const G=e.getState(),{tasks:H,dependencies:Y,config:V}=G;if(H.size===0){u=new Map,h=[];return}p=vn(H,Y);const K=El(H,Y),j=Cl(K);Il(j,Y,H);const ne=Ml(j,s);let oe=1/0,re=-1/0,le=1/0,me=-1/0;for(const{x:ue,y:De}of ne.values())oe=Math.min(oe,ue),re=Math.max(re,ue+$e),le=Math.min(le,De),me=Math.max(me,De+et);const Se=(oe+re)/2,Ae=(le+me)/2,Re=u;u=new Map;for(const[ue,De]of H){const Le=ne.get(ue);if(!Le)continue;const je=Le.x-Se,it=Le.y-Ae,Fe=Re.get(ue);u.set(ue,{id:ue,task:De,layer:K.get(ue)??0,orderInLayer:0,x:Fe?Fe.x:je,y:Fe?Fe.y:it,targetX:je,targetY:it,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of j)for(let De=0;De<ue.length;De++){const Le=u.get(ue[De]);Le&&(Le.orderInLayer=De)}h=[];for(const ue of Y.values())!H.has(ue.source)||!H.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function F(G){const H=e.getState(),Y=new Set;Y.add(G);const V=new Map,K=new Map;for(const oe of H.tasks.keys())V.set(oe,[]),K.set(oe,[]);for(const oe of H.dependencies.values())!H.tasks.has(oe.source)||!H.tasks.has(oe.target)||(V.get(oe.source).push(oe.target),K.get(oe.target).push(oe.source));const j=[G];for(;j.length>0;){const oe=j.shift();for(const re of K.get(oe)||[])Y.has(re)||(Y.add(re),j.push(re))}const ne=[G];for(;ne.length>0;){const oe=ne.shift();for(const re of V.get(oe)||[])Y.has(re)||(Y.add(re),ne.push(re))}return Y}function x(){C&&cancelAnimationFrame(P),C=!0,M=performance.now(),z()}function z(){const G=performance.now()-M,H=tn(G/vl,0,1),Y=1-Math.pow(1-H,3);let V=!1;for(const K of u.values()){if(K.isDragging)continue;const j=Math.abs(K.x-K.targetX),ne=Math.abs(K.y-K.targetY);j>.5||ne>.5?(K.x=Mo(K.x,K.targetX,Y),K.y=Mo(K.y,K.targetY,Y),V=!0):(K.x=K.targetX,K.y=K.targetY)}if(O(),V&&H<1)P=requestAnimationFrame(z);else{C=!1;for(const K of u.values())K.isDragging||(K.x=K.targetX,K.y=K.targetY);O()}}function O(){if(!i||!o)return;const G=e.getState(),{config:H}=G,Y=H.theme,V=H.colorMap,K=Y.timelineBg==="#1A202C"||Y.gridBg==="#1A202C"||Y.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(Y.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=K?"#1A202C":"#F7F8FA",i.fillRect(0,0,_,U),i.save(),i.translate(r,l),i.scale(f,f);for(const j of h){const ne=u.get(j.sourceId),oe=u.get(j.targetId);if(!ne||!oe)continue;const re=E.has(j.sourceId)&&E.has(j.targetId),le=k===j.sourceId||k===j.targetId,me=k!==null&&!le||D!==null&&!re,Se=ne.x+$e,Ae=ne.y+et/2,Re=oe.x,ue=oe.y+et/2;i.save(),me?i.globalAlpha=.15:(le||re)&&(i.globalAlpha=1),j.isCritical?(i.strokeStyle=Y.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?K?"#A0AEC0":"#4A5568":K?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const De=(Se+Re)/2;i.beginPath(),i.moveTo(Se,Ae),i.quadraticCurveTo(De,Ae,(Se+Re)/2,(Ae+ue)/2),i.quadraticCurveTo(De,ue,Re,ue),i.stroke();const Le=Math.atan2(ue-(Ae+ue)/2,Re-De);i.beginPath(),i.moveTo(Re,ue),i.lineTo(Re-en*Math.cos(Le-Math.PI/6),ue-en*Math.sin(Le-Math.PI/6)),i.lineTo(Re-en*Math.cos(Le+Math.PI/6),ue-en*Math.sin(Le+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const je=j.dep.type||"FS",it=j.dep.lag||0,Fe=it!==0?`${je} +${it}d`:je!=="FS"?je:"";if(Fe&&!me){const Lt=(Se+Re)/2,ss=(Ae+ue)/2-8;i.font=`10px ${Y.fontFamily}`,i.fillStyle=K?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Fe,Lt,ss)}i.restore()}for(const j of u.values()){const ne=k!==null&&k!==j.id&&!$(k,j.id)||D!==null&&!E.has(j.id),oe=k===j.id,re=D===j.id,le=Rl(j.task,V),me=j.x,Se=j.y;i.save(),ne&&(i.globalAlpha=.25),j.isCritical&&!ne&&(i.save(),i.shadowColor=Y.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Mt(i,me,Se,$e,et,Bn),i.fillStyle="transparent",i.fill(),i.restore()),Mt(i,me,Se,$e,et,Bn),i.fillStyle=K?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||re?2.5:1.5,i.stroke(),re&&(i.strokeStyle=Y.selectionColor||"#3182CE",i.lineWidth=2,Mt(i,me-2,Se-2,$e+4,et+4,Bn+2),i.stroke()),i.font=`600 12px ${Y.fontFamily}`,i.fillStyle=K?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ae=Fn(i,j.task.name,$e-20);i.fillText(Ae,me+10,Se+8);const Re=Se+26;i.beginPath(),i.arc(me+16,Re+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${Y.fontFamily}`,i.fillStyle=K?"#A0AEC0":"#718096",i.textBaseline="top";const ue=j.task.status||"No status";i.fillText(Fn(i,ue,$e-40),me+24,Re);const De=Ll(j.task),Le=De===1?"1 day":`${De} days`;i.font=`10px ${Y.fontFamily}`,i.fillStyle=K?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Le,me+10,Se+42),j.task.assignee&&(i.font=`10px ${Y.fontFamily}`,i.fillStyle=K?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(Fn(i,j.task.assignee,$e/2-10),me+$e-10,Se+42));const je=j.task.progress??0,it=Se+et-6,Fe=$e-20,Lt=3;if(Mt(i,me+10,it,Fe,Lt,1.5),i.fillStyle=K?"#4A5568":"#E2E8F0",i.fill(),je>0){const ss=Math.max(Lt,Fe*tn(je,0,1));Mt(i,me+10,it,ss,Lt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),I(K,Y.fontFamily)}function I(G,H){if(!i)return;const Y={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${H}`,i.fillStyle=G?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${Y[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,_-12,12),i.restore()}function $(G,H){for(const Y of h)if(Y.sourceId===G&&Y.targetId===H||Y.sourceId===H&&Y.targetId===G)return!0;return!1}function R(G){c=G;const H=G.querySelector(".ng-timeline-panel");if(!H)return;d=H.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",H.appendChild(o);const Y=o.getContext("2d");Y&&(i=Y,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",be),o.addEventListener("mouseup",X),o.addEventListener("mouseleave",te),o.addEventListener("dblclick",q),o.addEventListener("wheel",ee,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function N(){if(!o||!c)return;const G=c.querySelector(".ng-timeline-panel");G&&(_=G.clientWidth,U=G.clientHeight,o.width=Math.round(_*a),o.height=Math.round(U*a),o.style.width=`${_}px`,o.style.height=`${U}px`)}function W(){if(o){n=!0,o.style.display="block",d&&(d.style.visibility="hidden"),N(),Z(),L();for(const G of u.values())G.x=G.targetX,G.y=G.targetY;O()}}function J(){o&&(n=!1,o.style.display="none",d&&(d.style.visibility="visible"),k=null,D=null,E=new Set)}function Z(){r=_/2,l=U/2,f=1}function ie(G){if(!o)return{x:0,y:0};const H=o.getBoundingClientRect();return{x:G.clientX-H.left,y:G.clientY-H.top}}function ge(G){const{x:H,y:Y}=ie(G),V=A(H,Y);V?(y=V,V.isDragging=!0,v=B(H,Y).x-V.x,w=B(H,Y).y-V.y,D=V.id,E=F(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id}),O()):(b=!0,T=H,g=Y,m=r,S=l,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),O()))}function be(G){if(!o)return;const{x:H,y:Y}=ie(G);if(y){const j=B(H,Y);y.x=j.x-v,y.y=j.y-w,y.targetX=y.x,y.targetY=y.y,O();return}if(b){const j=H-T,ne=Y-g;r=m+j,l=S+ne,O();return}const V=A(H,Y),K=V?V.id:null;K!==k&&(k=K,o.style.cursor=k?"pointer":"default",O())}function X(G){y&&(y.isDragging=!1,y=null),b=!1}function te(G){y&&(y.isDragging=!1,y=null),b=!1,k&&(k=null,O())}function q(G){const{x:H,y:Y}=ie(G),V=A(H,Y);if(V){const K=e.getState();K.tasks.get(V.id)&&K.config&&e.dispatch({type:"SELECT_TASK",taskId:V.id})}}function ee(G){if(G.preventDefault(),!o)return;const{x:H,y:Y}=ie(G),V=B(H,Y),K=-G.deltaY*Tl;f=tn(f+K*f,Eo,Co);const j=B(H,Y);r+=(j.x-V.x)*f,l+=(j.y-V.y)*f,O()}let se=0,de=0,ae=0;function fe(G){if(G.preventDefault(),!!o){if(G.touches.length===1){const H=G.touches[0],Y=o.getBoundingClientRect(),V=H.clientX-Y.left,K=H.clientY-Y.top,j=A(V,K);j?(y=j,j.isDragging=!0,v=B(V,K).x-j.x,w=B(V,K).y-j.y,D=j.id,E=F(j.id),e.dispatch({type:"SELECT_TASK",taskId:j.id})):(b=!0,T=V,g=K,m=r,S=l),O()}else if(G.touches.length===2){b=!1,y&&(y.isDragging=!1,y=null);const H=G.touches[0],Y=G.touches[1];se=Math.hypot(Y.clientX-H.clientX,Y.clientY-H.clientY),de=(H.clientX+Y.clientX)/2,ae=(H.clientY+Y.clientY)/2}}}function ce(G){if(G.preventDefault(),!o)return;const H=o.getBoundingClientRect();if(G.touches.length===1){const Y=G.touches[0],V=Y.clientX-H.left,K=Y.clientY-H.top;if(y){const j=B(V,K);y.x=j.x-v,y.y=j.y-w,y.targetX=y.x,y.targetY=y.y,O()}else if(b){const j=V-T,ne=K-g;r=m+j,l=S+ne,O()}}else if(G.touches.length===2){const Y=G.touches[0],V=G.touches[1],K=Math.hypot(V.clientX-Y.clientX,V.clientY-Y.clientY),j=(Y.clientX+V.clientX)/2,ne=(Y.clientY+V.clientY)/2,oe=j-H.left,re=ne-H.top;if(se>0){const le=K/se,me=B(oe,re);f=tn(f*le,Eo,Co);const Se=B(oe,re);r+=(Se.x-me.x)*f,l+=(Se.y-me.y)*f}r+=j-de,l+=ne-ae,se=K,de=j,ae=ne,O()}}function Te(G){y&&(y.isDragging=!1,y=null),b=!1,se=0}function ve(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",be),o.removeEventListener("mouseup",X),o.removeEventListener("mouseleave",te),o.removeEventListener("dblclick",q),o.removeEventListener("wheel",ee),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),d&&(d.style.visibility="visible",d=null),C&&(cancelAnimationFrame(P),C=!1)}return{name:"NetworkGraphPlugin",install(G){e=G,t.push(e.on("networkGraph:toggle",()=>{n?J():W()})),t.push(e.on("networkGraph:layout",(...H)=>{const Y=H[0];Y!==s&&(s=Y,n&&(L(),x()))})),t.push(e.on("stateChange",()=>{n&&(L(),x())}))},renderDOM(G,H){o||R(G),n&&(N(),O())},destroy(){for(const G of t)G();t=[],ve(),u=new Map,h=[],p=null,n=!1}}}const Ao=300,Ro="nimbus-gantt-config-panel",Un="nimbus-gantt-config-panel-styles",Lo=300,Yn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],$l=`
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
`;function _l(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(Ro);return e?JSON.parse(e):{}}catch{return{}}}function Ol(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(Ro,JSON.stringify(e))}catch{}}function Po(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function nn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Nl(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=$l,document.head.appendChild(e)}function Hl(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function sn(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const c=document.createElement("span");c.className="ng-config-label",c.textContent=e;const d=document.createElement("input");d.type="range",d.className="ng-config-slider",d.min=String(t),d.max=String(n),d.step=String(o),d.value=String(s);const u=document.createElement("span");return u.className="ng-config-slider-value",u.textContent=String(s),d.addEventListener("input",()=>{const h=Number(d.value);u.textContent=String(h),i(h)}),a.appendChild(c),a.appendChild(d),a.appendChild(u),a}function At(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let c=t;return i.addEventListener("click",()=>{c=!c,i.classList.toggle("ng-active",c),n(c)}),s.appendChild(o),s.appendChild(i),s}function on(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=$o(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function $o(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function xl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const c=[];function d(){if(!e)return;const k=e.getState();e.dispatch({type:"SET_SCROLL",x:k.scrollX,y:k.scrollY})}function u(k){Object.assign(t,k),Ol(t)}function h(k,D,E){k[D]=E}function p(k,D){if(!e)return;const E=e.getState();h(E.config,k,D),u({[k]:D}),d()}function r(k,D){if(!e)return;const E=e.getState();h(E.config.theme,k,D),d()}function l(k){if(!e)return;const D=Yn.find(C=>C.name===k);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),u({themePreset:k}),d()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function b(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function T(k,D){var G;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?b():f()}),k.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",b),k.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",k.appendChild(o)),o.innerHTML="";const C=document.createElement("div");C.className="ng-config-panel-header",C.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",b),C.appendChild(M),o.appendChild(C);const P=g("Display Settings");P.appendChild(sn("Row height",24,60,E.rowHeight,2,H=>p("rowHeight",H))),P.appendChild(sn("Bar height",16,40,E.barHeight,2,H=>p("barHeight",H))),P.appendChild(sn("Grid width",0,500,E.gridWidth,10,H=>p("gridWidth",H))),P.appendChild(sn("Font size",10,16,E.theme.fontSize,1,H=>{h(D.config.theme,"fontSize",H),u({fontSize:H}),d()})),P.appendChild(At("Today marker",E.showToday,H=>{h(D.config,"showToday",H),u({showToday:H}),d()})),P.appendChild(At("Weekends",E.showWeekends,H=>{h(D.config,"showWeekends",H),u({showWeekends:H}),d()})),P.appendChild(At("Progress bars",E.showProgress,H=>{h(D.config,"showProgress",H),u({showProgress:H}),d()})),P.appendChild(At("Dependency arrows",a,H=>{a=H,u({showDependencies:H}),d()})),P.appendChild(At("Labels on bars",t.showBarLabels!==!1,H=>{u({showBarLabels:H}),d()})),o.appendChild(P);const _=g("Color Theme"),U=document.createElement("div");U.className="ng-config-row";const B=document.createElement("span");B.className="ng-config-label",B.textContent="Preset";const A=document.createElement("select");A.className="ng-config-select";const L=document.createElement("option");L.value="",L.textContent="Custom",A.appendChild(L);for(const H of Yn){const Y=document.createElement("option");Y.value=H.name,Y.textContent=H.name,t.themePreset===H.name&&(Y.selected=!0),A.appendChild(Y)}A.addEventListener("change",()=>{A.value&&l(A.value)}),U.appendChild(B),U.appendChild(A),_.appendChild(U),_.appendChild(on("Bar default",E.theme.barDefaultColor,H=>{r("barDefaultColor",H),u({customColors:{...t.customColors,barDefault:H}})})),_.appendChild(on("Today line",E.theme.todayLineColor,H=>{r("todayLineColor",H),u({customColors:{...t.customColors,todayLine:H}})})),_.appendChild(on("Grid lines",E.theme.timelineGridColor,H=>{r("timelineGridColor",H),u({customColors:{...t.customColors,gridLines:H}})})),_.appendChild(on("Background",E.theme.timelineBg,H=>{r("timelineBg",H),u({customColors:{...t.customColors,background:H}})}));const F=document.createElement("div");F.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",F.textContent="Status Color Map",_.appendChild(F);const x={...E.colorMap,...t.statusColorMap},z=document.createElement("div");function O(){z.innerHTML="";const H=Object.entries(x);for(const[V,K]of H){const j=document.createElement("div");j.className="ng-config-color-map-entry";const ne=document.createElement("input");ne.className="ng-config-color-map-status",ne.value=V,ne.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=$o(K),oe.addEventListener("input",()=>{x[V]=oe.value,E.colorMap[V]=oe.value,u({statusColorMap:{...x}}),d()});const re=document.createElement("button");re.className="ng-config-color-map-remove",re.innerHTML="×",re.addEventListener("click",()=>{delete x[V],delete E.colorMap[V],u({statusColorMap:{...x}}),O(),d()}),j.appendChild(ne),j.appendChild(oe),j.appendChild(re),z.appendChild(j)}const Y=document.createElement("button");Y.className="ng-config-color-map-add",Y.textContent="+ Add status color",Y.addEventListener("click",()=>{const V=prompt("Status name:");!V||V.trim()===""||(x[V.trim()]="#3b82f6",E.colorMap[V.trim()]="#3b82f6",u({statusColorMap:{...x}}),O(),d())}),z.appendChild(Y)}O(),_.appendChild(z),o.appendChild(_);const I=g("Zoom & Time"),$=document.createElement("div");$.className="ng-config-row";const R=document.createElement("span");R.className="ng-config-label",R.textContent="Zoom";const N=document.createElement("div");N.className="ng-config-zoom-group";const W=["day","week","month","quarter"];for(const H of W){const Y=document.createElement("button");Y.className="ng-config-zoom-btn"+(D.zoomLevel===H?" ng-active":""),Y.textContent=H.charAt(0).toUpperCase()+H.slice(1),Y.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:H}),u({zoomLevel:H}),N.querySelectorAll(".ng-config-zoom-btn").forEach(V=>V.classList.toggle("ng-active",V===Y)))}),N.appendChild(Y)}$.appendChild(R),$.appendChild(N),I.appendChild($);const J=document.createElement("div");J.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const ie=document.createElement("input");ie.type="date",ie.className="ng-config-date-input",ie.value=Po(D.dateRange.start),ie.addEventListener("change",()=>{if(!e||!ie.value)return;const H=nn(ie.value),Y=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:H,end:Y}),u({dateRangeStart:ie.value})}),J.appendChild(Z),J.appendChild(ie),I.appendChild(J);const ge=document.createElement("div");ge.className="ng-config-row";const be=document.createElement("span");be.className="ng-config-label",be.textContent="End date";const X=document.createElement("input");X.type="date",X.className="ng-config-date-input",X.value=Po(D.dateRange.end),X.addEventListener("change",()=>{if(!e||!X.value)return;const H=e.getState().dateRange.start,Y=nn(X.value);e.dispatch({type:"SET_DATE_RANGE",start:H,end:Y}),u({dateRangeEnd:X.value})}),ge.appendChild(be),ge.appendChild(X),I.appendChild(ge);const te=document.createElement("div");te.style.cssText="margin-top: 8px;";const q=document.createElement("button");q.className="ng-config-btn ng-primary",q.textContent="Fit to View",q.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),d())}),te.appendChild(q),I.appendChild(te),o.appendChild(I);const ee=g("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),m("export:png"))}),se.appendChild(de);const ae=document.createElement("button");ae.className="ng-config-btn",ae.textContent="SVG",ae.addEventListener("click",()=>m("export:svg")),se.appendChild(ae);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&y(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&v(e.getState())}),se.appendChild(ce),ee.appendChild(se),o.appendChild(ee);const Te=g("Plugin Toggles"),ve=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const H of ve){const Y=document.createElement("div");Y.className="ng-config-plugin-row";const V=document.createElement("span");V.className="ng-config-plugin-name",V.textContent=H.label;const K=((G=t.pluginToggles)==null?void 0:G[H.key])!==!1,j=document.createElement("span");j.className="ng-config-plugin-status"+(K?" ng-active-status":""),j.textContent=K?"Active":"Inactive";const ne=document.createElement("div");ne.className="ng-config-toggle"+(K?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",ne.appendChild(oe);let re=K;ne.addEventListener("click",()=>{re=!re,ne.classList.toggle("ng-active",re),j.className="ng-config-plugin-status"+(re?" ng-active-status":""),j.textContent=re?"Active":"Inactive";const me={...t.pluginToggles,[H.key]:re};u({pluginToggles:me}),m(H.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(V),le.appendChild(j),Y.appendChild(le),Y.appendChild(ne),Te.appendChild(Y)}o.appendChild(Te)}function g(k){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=k,D.appendChild(E),D}function m(k){e&&S.forEach(D=>D(k))}const S=[];function y(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],C=D.map(B=>[B.id,`"${(B.name||"").replace(/"/g,'""')}"`,B.startDate,B.endDate,String(Math.round((B.progress??0)*100))+"%",B.status||"",B.assignee||"",B.priority||"",B.groupName||""]),M=[E.join(","),...C.map(B=>B.join(","))].join(`
`),P=new Blob([M],{type:"text/csv;charset=utf-8;"}),_=URL.createObjectURL(P),U=document.createElement("a");U.href=_,U.download="gantt-tasks.csv",document.body.appendChild(U),U.click(),document.body.removeChild(U),URL.revokeObjectURL(_)}function v(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],C=D.map(_=>[_.name,_.startDate,_.endDate,Math.round((_.progress??0)*100)+"%",_.status||"",_.assignee||""]),P=[E.join("	"),...C.map(_=>_.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(P).catch(()=>{})}function w(k){const D=t;if(D.rowHeight!==void 0&&h(k.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&h(k.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&h(k.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&h(k.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&h(k.config,"showToday",D.showToday),D.showWeekends!==void 0&&h(k.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&h(k.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=Yn.find(C=>C.name===D.themePreset);E&&Object.assign(k.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&h(k.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&h(k.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&h(k.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&h(k.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(k.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:nn(D.dateRangeStart),end:nn(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(k){e=k,Nl(),t=_l();const D=k.on("render",()=>{D(),w(k.getState()),d()});c.push(D);const E=k.on("config:open",()=>f()),C=k.on("config:close",()=>b()),M=k.on("config:toggle",()=>{i?b():f()});c.push(E,C,M)},renderDOM(k,D){T(k,D)},destroy(){c.forEach(k=>k()),c.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Hl(),e=null,i=!1}}}const _o=864e5,Wn="nimbus-gantt-heatmap-styles",ke=28,_e=2,tt=48,Oe=160,Bl=3,Oo="#1e1e2e",No="#166534",Ho="#a16207",xo="#b91c1c",Fl=`
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
`;function Bo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ul(e){return String(e.getUTCDate())}function Yl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Wl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fo(e,t){return Math.round((t.getTime()-e.getTime())/_o)}function Uo(e,t){return new Date(e.getTime()+t*_o)}function mt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Xl(e,t){return e===0?Oo:e===1?No:e===2?Ho:xo}function zl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Gl(){if(typeof document>"u"||document.getElementById(Wn))return;const e=document.createElement("style");e.id=Wn,e.textContent=Fl,document.head.appendChild(e)}function Vl(){if(typeof document>"u")return;const e=document.getElementById(Wn);e&&e.remove()}function Kl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Fo(o,i)+1,c=[];for(let h=0;h<a;h++)c.push(Uo(o,h));const d=new Map;let u=0;for(const h of s)for(const p of c){const r=`${h}|${mt(p)}`;d.set(r,{assignee:h,date:p,dateKey:mt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=Bo(h.startDate),l=Bo(h.endDate),f=Fo(r,l)+1;for(let b=0;b<f;b++){const T=Uo(r,b),g=`${p}|${mt(T)}`,m=d.get(g);m&&(m.tasks.push(h),m.count++,m.count>u&&(u=m.count))}}return{assignees:s,dates:c,cells:d,maxCount:u}}function jl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&u(o)}function c(){s=!0,t&&t.classList.add("ng-active"),e&&o&&u(o)}function d(){s=!1,t&&t.classList.remove("ng-active")}function u(p){if(!t||!s)return;const r=Kl(p);let l=t.querySelector(".ng-heatmap-grid-wrapper");l||(l=document.createElement("div"),l.className="ng-heatmap-grid-wrapper",t.appendChild(l)),l.innerHTML="";const f=document.createElement("canvas"),b=Oe+r.dates.length*(ke+_e),T=tt+r.assignees.length*(ke+_e),g=window.devicePixelRatio||1;f.width=b*g,f.height=T*g,f.style.width=b+"px",f.style.height=T+"px",f.style.cursor="pointer";const m=f.getContext("2d");m.scale(g,g),m.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',m.textAlign="center",m.textBaseline="middle";let S="",y=Oe;for(let v=0;v<r.dates.length;v++){const w=r.dates[v],k=Yl(w),D=Oe+v*(ke+_e);if(k!==S){if(S&&v>0){const E=(y+D)/2;m.fillStyle="#94a3b8",m.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',m.fillText(S,E,12)}y=D,S=k}}if(S){const v=Oe+r.dates.length*(ke+_e),w=(y+v)/2;m.fillStyle="#94a3b8",m.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',m.fillText(S,w,12)}m.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let v=0;v<r.dates.length;v++){const w=r.dates[v],k=Oe+v*(ke+_e)+ke/2,D=w.getUTCDay()===0||w.getUTCDay()===6;m.fillStyle=D?"#475569":"#64748b",m.fillText(Ul(w),k,32)}m.beginPath(),m.strokeStyle="#1e293b",m.lineWidth=1,m.moveTo(0,tt-.5),m.lineTo(b,tt-.5),m.stroke();for(let v=0;v<r.assignees.length;v++){const w=r.assignees[v],k=tt+v*(ke+_e);m.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',m.textAlign="left",m.textBaseline="middle",m.fillStyle="#cbd5e1",m.save(),m.beginPath(),m.rect(0,k,Oe-8,ke),m.clip(),m.fillText(w,8,k+ke/2),m.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],C=`${w}|${mt(E)}`,M=r.cells.get(C),P=(M==null?void 0:M.count)??0,_=Oe+D*(ke+_e),U=Xl(P),B=zl(P,r.maxCount);m.globalAlpha=B,m.fillStyle=U,h(m,_,k,ke,ke,Bl),m.fill(),P>=2&&(m.globalAlpha=1,m.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',m.textAlign="center",m.textBaseline="middle",m.fillStyle="#fff",m.fillText(String(P),_+ke/2,k+ke/2)),m.globalAlpha=1}}l.appendChild(f),f.addEventListener("mousemove",v=>{if(!n)return;const w=f.getBoundingClientRect(),k=v.clientX-w.left,D=v.clientY-w.top,E=Math.floor((k-Oe)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Oe||D<tt){n.classList.remove("ng-visible");return}const M=r.dates[E],P=r.assignees[C],_=`${P}|${mt(M)}`,U=r.cells.get(_);if(!U||U.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const B=document.createElement("div");B.className="ng-heatmap-tooltip-date",B.textContent=`${P} - ${Wl(M)}`,n.appendChild(B);for(const F of U.tasks){const x=document.createElement("div");x.className="ng-heatmap-tooltip-task",x.textContent=`• ${F.name}`,n.appendChild(x)}n.classList.add("ng-visible");const A=v.clientX+12,L=v.clientY+12;n.style.left=A+"px",n.style.top=L+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",v=>{if(!e)return;const w=f.getBoundingClientRect(),k=v.clientX-w.left,D=v.clientY-w.top,E=Math.floor((k-Oe)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Oe||D<tt)return;const M=r.dates[E],_=`${r.assignees[C]}|${mt(M)}`,U=r.cells.get(_);if(!(!U||U.count===0)){d();for(const B of U.tasks)e.dispatch({type:"SELECT_TASK",taskId:B.id,multi:!0})}})}function h(p,r,l,f,b,T){p.beginPath(),p.moveTo(r+T,l),p.lineTo(r+f-T,l),p.quadraticCurveTo(r+f,l,r+f,l+T),p.lineTo(r+f,l+b-T),p.quadraticCurveTo(r+f,l+b,r+f-T,l+b),p.lineTo(r+T,l+b),p.quadraticCurveTo(r,l+b,r,l+b-T),p.lineTo(r,l+T),p.quadraticCurveTo(r,l,r+T,l),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Gl();const r=p.on("heatmap:toggle",()=>a()),l=p.on("heatmap:show",()=>c()),f=p.on("heatmap:hide",()=>d());i.push(r,l,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const l=document.createElement("div");l.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",l.appendChild(f);const b=document.createElement("div");b.className="ng-heatmap-legend";const T=[{color:Oo,label:"None"},{color:No,label:"1 task"},{color:Ho,label:"2 tasks"},{color:xo,label:"3+ tasks"}];for(const m of T){const S=document.createElement("span");S.className="ng-heatmap-legend-swatch",S.style.background=m.color,b.appendChild(S);const y=document.createElement("span");y.textContent=m.label,b.appendChild(y)}l.appendChild(b);const g=document.createElement("button");g.className="ng-heatmap-close",g.textContent="Back to Gantt",g.addEventListener("click",d),l.appendChild(g),t.appendChild(l),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&u(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Vl(),e=null,s=!1,o=null}}}const nt=200,st=80,Yo=12,Wo=6,ql="rgba(255, 255, 255, 0.95)",Zl="#cbd5e1",Jl="rgba(59, 130, 246, 0.3)",Ql="rgba(59, 130, 246, 0.7)",ec=1.5,tc=2,nc=1,Xn="nimbus-gantt-minimap-styles",sc=864e5,oc=`
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
`;function ic(){if(typeof document>"u"||document.getElementById(Xn))return;const e=document.createElement("style");e.id=Xn,e.textContent=oc,document.head.appendChild(e)}function ac(){if(typeof document>"u")return;const e=document.getElementById(Xn);e&&e.remove()}function rc(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let c=1,d=1,u=0,h=0,p=0,r=0;function l(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function b(){o=!1,t&&t.classList.add("ng-hidden")}function T(v,w){const k=v/c-p/2,D=w/d-r/2;return{x:Math.max(0,Math.min(k,u-p)),y:Math.max(0,Math.min(D,h-r))}}function g(v){if(!e||!n)return;v.preventDefault(),i=!0;const w=n.getBoundingClientRect(),k=v.clientX-w.left,D=v.clientY-w.top,E=T(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function m(v){if(!i||!e||!n)return;v.preventDefault();const w=n.getBoundingClientRect(),k=Math.max(0,Math.min(v.clientX-w.left,nt)),D=Math.max(0,Math.min(v.clientY-w.top,st)),E=T(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function S(){i=!1}function y(v,w){if(!s||!n||!o)return;const k=window.devicePixelRatio||1;n.width=nt*k,n.height=st*k,n.style.width=nt+"px",n.style.height=st+"px",s.scale(k,k);const{config:D,scrollX:E,scrollY:C,dateRange:M}=v,P=e.getTimeScale(),_=Math.round((M.end.getTime()-M.start.getTime())/sc),U=P.getColumnWidth();if(u=Math.max(_*U,1),h=Math.max(v.flatVisibleIds.length*D.rowHeight,1),p=u>0?Math.min(u,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const R=t.parentElement;p=R.clientWidth-D.gridWidth,r=R.clientHeight-D.headerHeight}c=nt/Math.max(u,1),d=st/Math.max(h,1),s.fillStyle=ql,s.fillRect(0,0,nt,st);const B=new Map;for(const R of w)B.has(R.rowIndex)||B.set(R.rowIndex,[]),B.get(R.rowIndex).push(R);for(const R of w){const N=R.x*c,W=Math.max(R.width*c,1),J=R.rowIndex*D.rowHeight*d;s.fillStyle=R.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(N,J,W,Math.max(tc,D.rowHeight*d-nc))}s.globalAlpha=1;const A=E*c,L=C*d,F=p*c,x=r*d,z=Math.max(0,Math.min(A,nt-1)),O=Math.max(0,Math.min(L,st-1)),I=Math.min(F,nt-z),$=Math.min(x,st-O);s.fillStyle=Jl,s.fillRect(z,O,I,$),s.strokeStyle=Ql,s.lineWidth=ec,s.strokeRect(z,O,I,$)}return{name:"MiniMapPlugin",install(v){e=v,ic();const w=v.on("minimap:toggle",()=>l()),k=v.on("minimap:show",()=>f()),D=v.on("minimap:hide",()=>b());a.push(w,k,D),typeof document<"u"&&(document.addEventListener("mousemove",m),document.addEventListener("mouseup",S))},renderDOM(v,w){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",g),t.appendChild(n),v.appendChild(t));const k=(e==null?void 0:e.getLayouts())??[];y(w,k)},destroy(){a.forEach(v=>v()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",m),document.removeEventListener("mouseup",S)),t&&(t.remove(),t=null),n=null,s=null,ac(),e=null,o=!0,i=!1}}}const lc="#f59e0b",cc=[6,4],dc=1,lt=16,uc=4,gc="rgba(15, 23, 42, 0.95)",hc="#e2e8f0",fc="#334155",pc=6,ct=10,Xo=220,zo=12,Go=13;function mc(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Rt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=c=>c.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function yc(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Rt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function bc(e,t,n,s,o){const i=s/2,a=i*.4,c=5;e.beginPath();for(let d=0;d<c*2;d++){const u=d%2===0?i:a,h=Math.PI/2*-1+Math.PI/c*d,p=t+Math.cos(h)*u,r=n+Math.sin(h)*u;d===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke()}function Tc(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function vc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Sc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Rt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Vo={flag:yc,star:bc,warning:Tc,info:vc,deadline:Sc};function wc(e,t,n,s,o){e.save();const i=`${zo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Go}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const c=e.measureText(t.label).width;e.font=i;const d=[];let u=0;if(t.description){const T=t.description.split(" ");let g="";for(const m of T){const S=g?g+" "+m:m;e.measureText(S).width>Xo-ct*2&&g?(d.push(g),u=Math.max(u,e.measureText(g).width),g=m):g=S}g&&(d.push(g),u=Math.max(u,e.measureText(g).width))}const h=Math.min(Xo,Math.max(c,u)+ct*2),p=zo+4,r=Go+4,l=ct*2+r+(d.length>0?4+d.length*p:0);let f=n-h/2;const b=s-l-8;if(f<4&&(f=4),f+h>o-4&&(f=o-h-4),e.beginPath(),kc(e,f,b,h,l,pc),e.fillStyle=gc,e.fill(),e.strokeStyle=fc,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=hc,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+ct,b+ct),d.length>0){e.font=i,e.fillStyle="#94a3b8";let T=b+ct+r+4;for(const g of d)e.fillText(g,f+ct,T),T+=p}e.restore()}function kc(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Dc(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,c=-1,d=null,u=null;function h(g){return n.find(m=>m.id===g)}function p(g){n.push(g),b()}function r(g){n=n.filter(m=>m.id!==g),b()}function l(g,m){const S=h(g);S&&(Object.assign(S,m),b())}function f(){return[...n]}function b(){if(!t)return;const g=t.getState();t.dispatch({type:"SET_SCROLL",x:g.scrollX,y:g.scrollY})}function T(g){const m=g.canvas;u!==m&&(u&&d&&u.removeEventListener("mousemove",d),u=m,d=S=>{const y=m.getBoundingClientRect();a=S.clientX-y.left,c=S.clientY-y.top;let v=null;for(const w of o){const k=a-w.x,D=c-w.y;if(Math.sqrt(k*k+D*D)<=w.size){v=w.note.id;break}}v!==s&&(s=v,m.style.cursor=s?"pointer":"",b())},m.addEventListener("mousemove",d))}return{name:"TimelineNotesPlugin",install(g){t=g;const m=g.on("notes:add",(...w)=>{const k=w[0];k&&k.id&&k.date&&k.label&&p(k)}),S=g.on("notes:remove",(...w)=>{const k=w[0];k&&r(k)}),y=g.on("notes:update",(...w)=>{const k=w[0];if(k&&k.id){const{id:D,...E}=k;l(D,E)}}),v=g.on("notes:list",(...w)=>{const k=w[0];typeof k=="function"&&k(f())});i.push(m,S,y,v)},renderCanvas(g,m,S){if(!t||n.length===0)return;const{config:y,scrollX:v,scrollY:w,dateRange:k}=m,{theme:D}=y,E=y.headerHeight,C=t.getTimeScale();T(g);const M=g.canvas.width/(window.devicePixelRatio||1),P=g.canvas.height/(window.devicePixelRatio||1),_=E,U=P-_;o=[],g.save();for(const B of n){const A=mc(B.date);if(A<k.start||A>k.end)continue;const L=B.color||lc,F=B.icon||"flag",x=C.dateToX(A)-v;if(x<-lt||x>M+lt)continue;g.save(),g.beginPath(),g.setLineDash(cc),g.strokeStyle=L,g.globalAlpha=.5,g.lineWidth=dc,g.moveTo(x,_),g.lineTo(x,_+U),g.stroke(),g.setLineDash([]),g.globalAlpha=1,g.restore();const z=x,O=_+uc+lt/2,I=Vo[F]||Vo.flag;g.save(),g.beginPath(),g.arc(z,O,lt/2+3,0,Math.PI*2),g.fillStyle="rgba(0, 0, 0, 0.4)",g.fill(),g.restore(),g.save(),I(g,z,O,lt,L),g.restore(),o.push({note:B,x:z,y:O,size:lt/2+4}),s===B.id&&wc(g,B,z,O-lt/2-4,M)}g.restore()},destroy(){i.forEach(g=>g()),i.length=0,u&&d&&u.removeEventListener("mousemove",d),t=null,u=null,d=null,s=null,o=[]}}}const Ec=500,Cc=40,Ko=7,jo=3,qo=5,Ic=500,zn="nimbus-gantt-timetravel-styles",Zo={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Mc=`
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
`;function Ac(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Rc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Lc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function Pc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function $c(){if(typeof document>"u"||document.getElementById(zn))return;const e=document.createElement("style");e.id=zn,e.textContent=Mc,document.head.appendChild(e)}function _c(){if(typeof document>"u")return;const e=document.getElementById(zn);e&&e.remove()}const Jo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),an=[.5,1,2,4];function Oc(e){const t=(e==null?void 0:e.maxSnapshots)??Ec,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,c=!1,d=null,u=1;const h=[];let p=null,r=null,l=null,f=null,b=null,T=null,g=null,m=!1;function S(O){if(!s||a)return;const I=s.getState(),$=Lc(I,O);i<o.length-1&&(o.length=i+1),o.push($),o.length>t&&o.shift(),i=o.length-1}function y(O){if(!s||o.length===0)return;const I=Math.max(0,Math.min(O,o.length-1));i=I;const $=o[I];a=!0;const R=$.tasks.map(W=>({id:W.id,name:W.name,startDate:W.startDate,endDate:W.endDate,progress:W.progress,status:W.status})),N=$.dependencies.map(W=>({id:W.id,source:W.source,target:W.target}));s.dispatch({type:"SET_DATA",tasks:R,dependencies:N}),a=!1,_()}function v(){o.length>0&&y(o.length-1),k()}function w(){if(c||o.length<=1)return;c=!0;const O=an[u],I=Ic/O;d=setInterval(()=>{if(i>=o.length-1){k();return}y(i+1)},I),_()}function k(){c=!1,d!==null&&(clearInterval(d),d=null),_()}function D(){c?k():w()}function E(){u=(u+1)%an.length,c&&(k(),w()),_()}function C(){k(),i>0&&y(i-1)}function M(){k(),i<o.length-1&&y(i+1)}function P(){k(),o.length=0,i=-1,a=!1,_()}function _(){if(p){if(f){const O=o.length,I=O>0?i+1:0;f.textContent=`${I} / ${O}`}b&&(b.textContent=c?"⏸":"▶",b.classList.toggle("ng-active",c)),T&&(T.textContent=`${an[u]}x`),U(),B()}}function U(){if(!l||!r||o.length===0){l&&(l.style.display="none");return}l.style.display="block";const O=o.length<=1?50:i/(o.length-1)*100;l.style.left=`${O}%`}function B(){if(!g||!r||(g.innerHTML="",o.length===0))return;const O=200,I=o.length>O?Math.ceil(o.length/O):1;for(let $=0;$<o.length;$+=I){const R=o[$],N=o.length<=1?50:$/(o.length-1)*100,W=Ac(R.action.split(" ")[0]==="Loaded"?"SET_DATA":A(R.action)),J=Zo[W]||Zo.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${N}%`,Z.style.background=J;const ie=document.createElement("div");ie.className="ng-timetravel-tooltip",ie.textContent=`${R.action}
${Pc(R.timestamp)}`,ie.style.whiteSpace="pre",Z.appendChild(ie);const ge=$;Z.addEventListener("click",be=>{be.stopPropagation(),k(),y(ge)}),g.appendChild(Z)}}function A(O){return O.startsWith("Moved")?"TASK_MOVE":O.startsWith("Resized")?"TASK_RESIZE":O.startsWith("Added task")?"ADD_TASK":O.startsWith("Added dependency")?"ADD_DEPENDENCY":O.startsWith("Removed task")?"REMOVE_TASK":O.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":O.startsWith("Updated")?"UPDATE_TASK":(O.startsWith("Loaded"),"SET_DATA")}function L(O){if(!r||o.length<=1)return;const I=r.getBoundingClientRect(),$=Math.max(0,Math.min(1,(O.clientX-I.left)/I.width)),R=Math.round($*(o.length-1));k(),y(R)}function F(O){O.preventDefault(),O.stopPropagation(),m=!0,l&&l.classList.add("ng-dragging"),k()}function x(O){if(!m||!r||o.length<=1)return;const I=r.getBoundingClientRect(),$=Math.max(0,Math.min(1,(O.clientX-I.left)/I.width)),R=Math.round($*(o.length-1));y(R)}function z(){m&&(m=!1,l&&l.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(O){s=O,$c(),h.push(O.on("timeTravel:record",()=>{s&&(s.getState(),S("Manual snapshot"))}),O.on("timeTravel:scrub",(...I)=>{const $=I[0];k(),y($)}),O.on("timeTravel:play",()=>w()),O.on("timeTravel:pause",()=>k()),O.on("timeTravel:present",()=>v()),O.on("timeTravel:clear",()=>P()),O.on("timeTravel:history",(...I)=>{const $=I[0];typeof $=="function"&&$([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",x),document.addEventListener("mouseup",z))},middleware(O,I){let $="";n&&Jo.has(O.type)&&s&&!a&&($=Rc(O,s.getState())),I(O),n&&Jo.has(O.type)&&!a&&$&&S($)},renderDOM(O,I){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const $=document.createElement("button");$.className="ng-timetravel-btn",$.textContent="◀",$.title="Step backward",$.addEventListener("click",()=>C()),p.appendChild($),b=document.createElement("button"),b.className="ng-timetravel-btn",b.textContent="▶",b.title="Play / Pause",b.addEventListener("click",()=>D()),p.appendChild(b);const R=document.createElement("button");R.className="ng-timetravel-btn",R.textContent="▶",R.title="Step forward",R.addEventListener("click",()=>M()),p.appendChild(R),T=document.createElement("span"),T.className="ng-timetravel-speed ng-timetravel-btn",T.textContent=`${an[u]}x`,T.title="Click to cycle speed",T.addEventListener("click",()=>E()),p.appendChild(T),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",L);const N=document.createElement("div");N.className="ng-timetravel-rail",r.appendChild(N),g=document.createElement("div"),g.style.position="absolute",g.style.inset="0",r.appendChild(g),l=document.createElement("div"),l.className="ng-timetravel-playhead",l.addEventListener("mousedown",F),r.appendChild(l),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const W=document.createElement("button");W.className="ng-timetravel-btn ng-present",W.textContent="Present",W.title="Return to latest state",W.addEventListener("click",()=>v()),p.appendChild(W),O.appendChild(p)}_()},destroy(){k();for(const O of h)O();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",x),document.removeEventListener("mouseup",z)),p&&(p.remove(),p=null),r=null,l=null,f=null,b=null,T=null,g=null,_c(),o.length=0,i=-1,a=!1,c=!1,m=!1,s=null}}}const Qo=864e5,Nc=60,Hc=2,ei=[6,4],Gn="nimbus-gantt-montecarlo-styles",ti={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},xc=.08,Bc=`
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
`;function Vn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function rn(e,t){return Math.round((t.getTime()-e.getTime())/Qo)}function dt(e,t){return new Date(e.getTime()+t*Qo)}function ni(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function si(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Uc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Yc(e,t){return e+Math.random()*(t-e)}function Wc(e,t,n,s,o,i,a,c){const d=e.length;if(d===0)return 0;const u=new Float64Array(d),h=new Float64Array(d),p=new Int32Array(c),r=[];for(let b=0;b<d;b++)p[b]===0&&(r.push(b),u[b]=o[b],h[b]=o[b]+s[b]);let l=0;for(;l<r.length;){const b=r[l++],T=h[b],g=i[b];for(let m=0;m<g.length;m++){const S=g[m];T>u[S]&&(u[S]=T,h[S]=T+s[S]),p[S]--,p[S]===0&&r.push(S)}}for(let b=0;b<d;b++)h[b]===0&&s[b]>0&&(u[b]=o[b],h[b]=o[b]+s[b]);let f=0;for(let b=0;b<d;b++)h[b]>f&&(f=h[b]);return f}function Xc(e,t,n,s,o,i){const a=new Float64Array(e),c=new Float64Array(e),d=new Float64Array(e),u=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let T=0;T<e;T++)h[T]===0&&(r.push(T),a[T]=n[T],c[T]=n[T]+t[T]);let l=0;for(;l<r.length;){const T=r[l++];p.push(T);const g=c[T];for(const m of s[T])g>a[m]&&(a[m]=g,c[m]=g+t[m]),h[m]--,h[m]===0&&r.push(m)}for(let T=0;T<e;T++)c[T]===0&&t[T]>0&&(a[T]=n[T],c[T]=n[T]+t[T],p.push(T));let f=0;for(let T=0;T<e;T++)c[T]>f&&(f=c[T]);for(let T=0;T<e;T++)s[T].length===0?(u[T]=f,d[T]=f-t[T]):(u[T]=1/0,d[T]=1/0);for(let T=p.length-1;T>=0;T--){const g=p[T];if(u[g]===1/0){let m=1/0;for(const S of s[g])d[S]<m&&(m=d[S]);m===1/0?u[g]=f:u[g]=m,d[g]=u[g]-t[g]}}const b=new Set;for(let T=0;T<e;T++){const g=d[T]-a[T];Math.abs(g)<.5&&b.add(T)}return b}function zc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,c=[],d=new Map;for(const N of e.keys())d.set(N,c.length),c.push(N);const u=c.length;if(u===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(u),p=new Float64Array(u);let r=1/0;for(const N of e.values()){const W=Vn(N.startDate).getTime();W<r&&(r=W)}const l=new Date(r);for(let N=0;N<u;N++){const W=e.get(c[N]),J=Vn(W.startDate),Z=Vn(W.endDate);h[N]=Math.max(rn(J,Z),1),p[N]=rn(l,J)}const f=Array.from({length:u},()=>[]),b=Array.from({length:u},()=>[]),T=new Int32Array(u);for(const N of t.values()){if((N.type||"FS")!=="FS")continue;const J=d.get(N.source),Z=d.get(N.target);J===void 0||Z===void 0||(f[J].push(Z),b[Z].push(J),T[Z]++)}const g=f.map(N=>new Int32Array(N)),m=b.map(N=>new Int32Array(N)),S=new Float64Array(s),y=new Float64Array(u),v=new Float64Array(u),w=new Float64Array(u),k=new Float64Array(u),D=new Float64Array(u),E=Math.max(1,Math.floor(s/100));for(let N=0;N<s;N++){for(let W=0;W<u;W++){const J=h[W];let Z;switch(i){case"triangular":{const ie=J*(1-o),ge=J,be=J*(1+o*1.5);Z=Fc(ie,ge,be);break}case"normal":{Z=Uc(J,J*o);break}case"uniform":{Z=Yc(J*(1-o),J*(1+o));break}}y[W]=Math.max(.5,Z),v[W]+=y[W],w[W]+=y[W]*y[W],y[W]>h[W]&&k[W]++}if(S[N]=Wc(c,d,h,y,p,g,m,T),N%E===0){const W=Xc(u,y,p,g,m,T);for(const J of W)D[J]++}}const C=Array.from(S).sort((N,W)=>N-W),M=C.map(N=>dt(l,N)),P=new Map;for(const N of a){const W=Math.min(Math.floor(N*C.length),C.length-1);P.set(N,dt(l,C[W]))}let _=0;for(let N=0;N<s;N++)_+=C[N];const U=_/s,B=dt(l,U),A=Math.floor(s/2),L=dt(l,C[A]);let F=0;for(let N=0;N<s;N++){const W=C[N]-U;F+=W*W}const x=Math.sqrt(F/s),z=dt(l,C[0]),O=dt(l,C[C.length-1]),I=new Map;for(let N=0;N<u;N++){const W=v[N]/s,J=w[N]/s-W*W;I.set(c[N],{meanDuration:W,stdDev:Math.sqrt(Math.max(0,J)),delayProbability:k[N]/s})}const $=Math.floor(s/E),R=new Map;for(let N=0;N<u;N++)D[N]>0&&R.set(c[N],D[N]/$);return{iterations:s,finishDates:M,percentiles:P,meanFinishDate:B,medianFinishDate:L,earliestFinish:z,latestFinish:O,standardDeviation:x,taskRisk:I,criticalPathFrequency:R}}function Gc(){if(typeof document>"u"||document.getElementById(Gn))return;const e=document.createElement("style");e.id=Gn,e.textContent=Bc,document.head.appendChild(e)}function Vc(){if(typeof document>"u")return;const e=document.getElementById(Gn);e&&e.remove()}function Kc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function c(r){if(!n)return;const l={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=zc(f.tasks,f.dependencies,l),h()}function d(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function u(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",l=0;for(const[g,m]of s.criticalPathFrequency)m>l&&(l=m,r=g);let f=r;if(n){const g=n.getState().tasks.get(r);g&&(f=g.name)}let b=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const g of t.confidenceLevels){const m=s.percentiles.get(g);if(!m)continue;const S=Math.round(g*100),y=ti[g]||"#94A3B8";b+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${S}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${y}">${si(m)}</span>
        </div>
      `}if(b+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${si(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&l>0){const g=Math.round(l*100);b+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${g}% of runs)
        </div>
      `}a.innerHTML=b;const T=a.querySelector(".ng-montecarlo-close");T&&T.addEventListener("click",()=>d())}function p(r,l){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:b}=l.config,T=l.scrollX,g=r.canvas.width/(window.devicePixelRatio||1),m=r.canvas.height/(window.devicePixelRatio||1),S=b,y=m-S,v=s.earliestFinish,w=s.latestFinish,k=Math.max(rn(v,w),1),D=f.getColumnWidth(),E=Math.max(D,Hc),C=Math.max(Math.ceil(k),1),M=new Uint32Array(C);for(const A of s.finishDates){const L=rn(v,A),F=Math.min(Math.max(Math.floor(L),0),C-1);M[F]++}let P=0;for(let A=0;A<C;A++)M[A]>P&&(P=M[A]);if(P===0)return;r.save(),r.beginPath(),r.rect(0,S,g,y),r.clip(),r.translate(-T,0);const _=s.finishDates[Math.floor(s.finishDates.length*.1)],U=s.finishDates[Math.floor(s.finishDates.length*.9)];if(_&&U){const A=f.dateToX(_),L=f.dateToX(U),F=r.createLinearGradient(A,0,L,0);F.addColorStop(0,"rgba(34, 197, 94, 0.0)"),F.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),F.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),F.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=F,r.globalAlpha=xc*5,r.fillRect(A,S,L-A,y),r.globalAlpha=1}const B=m-8;for(let A=0;A<C;A++){if(M[A]===0)continue;const L=dt(v,A),F=f.dateToX(L),x=M[A]/P*Nc,z=C>1?A/(C-1):.5;let O,I,$;if(z<.5){const R=z*2;O=Math.round(34+200*R),I=Math.round(197+-18*R),$=Math.round(94+-86*R)}else{const R=(z-.5)*2;O=Math.round(234+5*R),I=Math.round(179+-111*R),$=Math.round(8+60*R)}r.fillStyle=`rgba(${O}, ${I}, ${$}, 0.6)`,r.fillRect(F,B-x,Math.max(E-1,1),x)}r.setLineDash(ei),r.lineWidth=1.5;for(const[A,L]of s.percentiles){const F=f.dateToX(L),x=ti[A]||"#94A3B8",z=`P${Math.round(A*100)}`;r.strokeStyle=x,r.beginPath(),r.moveTo(F,S),r.lineTo(F,m),r.stroke(),r.setLineDash([]),r.fillStyle=x,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const O=r.measureText(`${z}: ${ni(L)}`).width,I=`${z}: ${ni(L)}`,$=O+8,R=16,N=F-$/2,W=S+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(N+3,W),r.lineTo(N+$-3,W),r.arcTo(N+$,W,N+$,W+3,3),r.lineTo(N+$,W+R-3),r.arcTo(N+$,W+R,N+$-3,W+R,3),r.lineTo(N+3,W+R),r.arcTo(N,W+R,N,W+R-3,3),r.lineTo(N,W+3),r.arcTo(N,W,N+3,W,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=x,r.fillText(I,F,W+3),r.setLineDash(ei)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Gc(),i.push(r.on("montecarlo:run",(...l)=>{const f=l[0];c(f)}),r.on("montecarlo:result",(...l)=>{const f=l[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>d()),r.on("montecarlo:configure",(...l)=>{const f=l[0];f&&u(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&c()}))},middleware(r,l){l(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&c()},renderCanvas(r,l,f){!o||!s||p(r,l)},renderDOM(r,l){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Vc(),s=null,n=null}}}const ln=864e5,oi=400,Kn="nimbus-gantt-narrative-styles",ii=300;function Ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function jn(e,t){return Math.round((t.getTime()-e.getTime())/ln)}function ai(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function ri(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*ln)}function li(e,t){return new Date(e.getTime()+t*ln)}function jc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const C=Ve(E.startDate).getTime(),M=Ve(E.endDate).getTime();C<s&&(s=C),M>o&&(o=M)}const i=new Date(s),a=new Date(o),c=jn(i,a),d=new Date;d.setUTCHours(0,0,0,0);const u=new Map,h=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(u.has(E.source)||u.set(E.source,[]),u.get(E.source).push(E.target),h.has(E.target)||h.set(E.target,[]),h.get(E.target).push(E.source));const p=Qc(n,t),r=ri(i),l=ri(a),f=[];let b=r;for(;b.getTime()<=l.getTime();)f.push({start:new Date(b),end:li(b,6)}),b=li(b,7);const T=[];for(let E=0;E<f.length;E++){const C=f[E],M=C.start,P=C.end,_=[],U=[],B=[],A=[],L=[],F=[],x=[];for(const R of n){const N=Ve(R.startDate),W=Ve(R.endDate);N>=M&&N<=P&&(_.push(R),R.isMilestone?(F.push(R),x.push(`Milestone: ${R.name}`)):x.push(`Started: ${R.name}`)),W>=M&&W<=P&&(R.isCompleted||R.progress!==void 0&&R.progress>=1)&&(U.push(R),x.push(`Completed: ${R.name}`)),N<=P&&W>=M&&(L.push(R),N<M&&!R.isCompleted&&(R.progress===void 0||R.progress===0)&&B.push(R),!R.isCompleted&&R.progress!==void 0&&R.progress>0&&R.progress<1&&A.push(R))}for(const R of n)if(R.isMilestone){const N=Ve(R.startDate);N>=M&&N<=P&&!F.includes(R)&&(F.push(R),x.push(`Milestone: ${R.name}`))}const z=L.filter(R=>p.has(R.id)),O=qc(_,U,B,L,z),I=Zc(_,U,B,A,L,z,F,u,e),$=`Week ${E+1} (${ai(M)}–${ai(P)})`;T.push({weekLabel:$,headline:O,body:I,metrics:{started:_.length,completed:U.length,delayed:B.length,onTrack:A.length},events:x})}const g=n.length,m=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,S=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,y=g-m-S,v=g>0?Math.round(m/g*100):0,w=v>=75?"strong":v>=50?"moderate":v>=25?"early-stage":"just getting started",k=`This project spans ${c} days across ${f.length} weeks with ${g} tasks. Progress is ${w} at ${v}% completion (${m} done, ${S} in progress, ${y} not started).`,D=Jc(n,p,u,h,i,a,d);return{title:"Project Narrative",generatedAt:Date.now(),summary:k,chapters:T,insights:D}}function qc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Zc(e,t,n,s,o,i,a,c,d){const u=[];if(e.length>0)if(e.length<=3){const r=e.map(l=>l.name).join(", ");u.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(l=>l.name).join(", ");u.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(l=>l.name).join(", ");u.push(`${r} ${t.length===1?"was":"were"} completed.`)}else u.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&u.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(l=>l.name).join(", ");u.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const l=n.map(f=>f.name).join(", ");u.push(`${l} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else u.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const l of n){const f=c.get(l.id);if(f)for(const b of f){const T=d.get(b);T&&!r.includes(T.name)&&r.push(T.name)}}if(r.length>0){const l=r.slice(0,3).join(", ");u.push(`This puts downstream work at risk, including ${l}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&u.length<4){const r=i.slice(0,2).map(l=>l.name).join(" and ");u.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,l)=>l[1]-r[1]);return p.length>0&&p[0][1]>=3&&u.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),u.length===0&&u.push("No significant activity scheduled for this week."),u.join(" ")}function Jc(e,t,n,s,o,i,a){const c=[];if(t.size>0){const T=e.filter(S=>t.has(S.id)),g=T.slice(0,4).map(S=>S.name).join(", "),m=T.length>4?` and ${T.length-4} more`:"";c.push(`The critical path runs through ${g}${m} — any delay here pushes the project finish.`)}const d=new Map;for(const T of e)T.assignee&&!T.isCompleted&&d.set(T.assignee,(d.get(T.assignee)||0)+1);const u=Array.from(d.entries()).sort((T,g)=>g[1]-T[1]);u.length>0&&u[0][1]>=2&&c.push(`${u[0][0]} is carrying the heaviest load with ${u[0][1]} concurrent tasks.`);const h=e.filter(T=>T.isCompleted?!1:Ve(T.startDate)<a&&(T.progress===void 0||T.progress===0));h.length>0&&c.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=jn(o,i),r=jn(o,a);if(r>0&&p>0){const T=Math.round(r/p*100),g=e.filter(y=>y.isCompleted||y.progress!==void 0&&y.progress>=1).length,m=Math.round(g/e.length*100),S=m-T;Math.abs(S)>=5?S>0?c.push(`Project is running ahead: ${m}% of tasks completed with ${T}% of time elapsed.`):c.push(`Project is running behind: only ${m}% of tasks completed with ${T}% of time elapsed.`):c.push(`Project is tracking close to schedule: ${m}% complete at ${T}% of elapsed time.`)}const l=e.filter(T=>{if(T.isCompleted||T.progress!==void 0&&T.progress>0)return!1;const g=s.get(T.id);return!g||g.length===0});l.length>0&&l.length<=e.length*.5&&c.push(`${l.length} task${l.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,b="";for(const T of e){const g=n.get(T.id);g&&g.length>f&&(f=g.length,b=T.name)}return f>=3&&c.push(`"${b}" is a bottleneck with ${f} downstream tasks depending on it.`),c}function Qc(e,t){const n=new Map;for(const l of e)n.set(l.id,l);const s=new Map,o=new Map;for(const l of e)s.set(l.id,[]),o.set(l.id,0);for(const l of t.values())(l.type||"FS")==="FS"&&(!n.has(l.source)||!n.has(l.target)||(s.get(l.source).push({target:l.target,lag:l.lag||0}),o.set(l.target,(o.get(l.target)||0)+1)));const i=new Map,a=[];for(const l of e)o.get(l.id)===0&&a.push(l.id);for(const l of e){const f=Ve(l.endDate).getTime();i.set(l.id,f)}const c=new Map(o);for(;a.length>0;){const l=a.shift(),f=i.get(l);for(const b of s.get(l)){const T=n.get(b.target),g=Ve(T.endDate).getTime()-Ve(T.startDate).getTime(),m=f+b.lag*ln+g;m>i.get(b.target)&&i.set(b.target,m);const S=c.get(b.target)-1;c.set(b.target,S),S===0&&a.push(b.target)}}let d=-1/0,u="";for(const[l,f]of i)f>d&&(d=f,u=l);if(!u)return new Set;const h=new Set,p=new Map;for(const l of e)p.set(l.id,[]);for(const l of t.values())(l.type||"FS")==="FS"&&(!n.has(l.source)||!n.has(l.target)||p.get(l.target).push({source:l.source,lag:l.lag||0}));let r=u;for(;r;){h.add(r);const l=p.get(r);if(!l||l.length===0)break;let f="",b=-1/0;for(const T of l){const g=i.get(T.source)||0;g>b&&(b=g,f=T.source)}if(!f||h.has(f))break;r=f}return h}const ed=`
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
`;function td(){if(typeof document>"u"||document.getElementById(Kn))return;const e=document.createElement("style");e.id=Kn,e.textContent=ed,document.head.appendChild(e)}function nd(){if(typeof document>"u")return;const e=document.getElementById(Kn);e&&e.remove()}function sd(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function od(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function c(){if(!e)return;const r=e.getState();t=jc(r.tasks,r.dependencies)}function d(){n=!0,c(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function u(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const l=document.createElement("div");l.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",l.appendChild(f);const b=document.createElement("span");b.textContent="Project Story",l.appendChild(b),r.appendChild(l);const T=document.createElement("div");T.style.display="flex",T.style.alignItems="center",T.style.gap="4px";const g=document.createElement("button");g.className="ng-narrative-refresh",g.innerHTML="↻",g.title="Regenerate",g.addEventListener("click",()=>{c(),h()}),T.appendChild(g);const m=document.createElement("button");m.className="ng-narrative-close",m.innerHTML="×",m.addEventListener("click",u),T.appendChild(m),r.appendChild(T),a.appendChild(r);const S=document.createElement("div");if(S.className="ng-narrative-summary",S.textContent=t.summary,a.appendChild(S),t.chapters.length===0){const w=document.createElement("div");w.className="ng-narrative-empty",w.textContent="No weekly chapters to display.",a.appendChild(w)}else for(const w of t.chapters){const k=document.createElement("div");k.className="ng-narrative-chapter";const D=sd(w),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const C=document.createElement("div");C.className="ng-narrative-week-label",C.textContent=w.weekLabel,E.appendChild(C);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=w.headline,E.appendChild(M),k.appendChild(E);const P=document.createElement("div");if(P.className="ng-narrative-metrics",w.metrics.started>0&&P.appendChild(p("started",`${w.metrics.started} started`)),w.metrics.completed>0&&P.appendChild(p("completed",`${w.metrics.completed} done`)),w.metrics.delayed>0&&P.appendChild(p("delayed",`${w.metrics.delayed} delayed`)),w.metrics.onTrack>0&&P.appendChild(p("ontrack",`${w.metrics.onTrack} on track`)),P.children.length>0&&k.appendChild(P),w.body){const _=document.createElement("div");_.className="ng-narrative-body",_.textContent=w.body,k.appendChild(_)}a.appendChild(k)}if(t.insights.length>0){const w=document.createElement("div");w.className="ng-narrative-insights";const k=document.createElement("div");k.className="ng-narrative-insights-title",k.innerHTML="<span>💡</span> Key Insights",w.appendChild(k);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const C=document.createElement("span");C.className="ng-narrative-insight-icon",C.textContent="•",E.appendChild(C);const M=document.createElement("span");M.textContent=D,E.appendChild(M),w.appendChild(E)}a.appendChild(w)}const y=document.createElement("div");y.className="ng-narrative-timestamp";const v=new Date(t.generatedAt);y.textContent=`Generated ${v.toLocaleString()}`,a.appendChild(y)}function p(r,l){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=l,f}return{name:"NarrativePlugin",install(r){e=r,td(),c(),s.push(r.on("narrative:generate",()=>{c(),n&&h()}),r.on("narrative:show",()=>d()),r.on("narrative:hide",()=>u()),r.on("narrative:get",()=>{t||c()}))},renderDOM(r,l){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?u():d()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",u),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(c(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),nd(),e=null,t=null,n=!1}}}const id=864e5,ad=10,qn="nimbus-gantt-whatif-styles",ci=.25,rd=.6,cn=6,di="#38A169",ui="#E53E3E",gi="#A0AEC0",Zn=36,ld="#F6AD55",hi="#1a202c",cd=`
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
`;function Ke(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function fi(e){const t=Ke(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function dn(e,t){return Math.round((t.getTime()-e.getTime())/id)}function pi(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function dd(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function ud(e){return{...e}}function gd(){if(typeof document>"u"||document.getElementById(qn))return;const e=document.createElement("style");e.id=qn,e.textContent=cd,document.head.appendChild(e)}function hd(){if(typeof document>"u")return;const e=document.getElementById(qn);e&&e.remove()}function fd(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,dd(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,ud(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function mi(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function pd(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const c=[];let d=null,u=null,h=null,p=null,r=null,l=null,f=null;function b(){t||!e||(o=fd(e.getState()),i=[],t=!0,n=!1,D())}function T(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),M(),_())}function g(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),M())}function m(I){if(!t||!e||!o)return;a.length>=ad&&a.shift();const $=e.getState(),R=mi($.tasks),N=Ke(o.projectFinish),W=Ke(R),J=dn(N,W);let Z=0;for(const[ge,be]of o.tasks){const X=$.tasks.get(ge);if(!X){Z++;continue}(X.startDate!==be.startDate||X.endDate!==be.endDate||X.assignee!==be.assignee)&&Z++}for(const ge of $.tasks.keys())o.tasks.has(ge)||Z++;const ie={id:pi(),name:I,createdAt:Date.now(),changes:[...i],result:{projectFinish:R,criticalPathDelta:J,tasksAffected:Z}};a.push(ie),L()}function S(I){if(!e||!o)return;const $=a.find(R=>R.id===I);if($){t||b(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const R of $.changes)v(R);i=[...$.changes],E()}}function y(I){a=a.filter($=>$.id!==I),L()}function v(I){if(e)switch(I.type){case"move":case"resize":I.taskId&&I.after&&I.after.startDate&&I.after.endDate&&e.dispatch({type:I.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:I.taskId,startDate:I.after.startDate,endDate:I.after.endDate});break;case"add":I.after&&e.dispatch({type:"ADD_TASK",task:I.after});break;case"remove":I.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:I.taskId});break;case"reassign":I.taskId&&I.after&&e.dispatch({type:"UPDATE_TASK",taskId:I.taskId,changes:I.after});break;case"add-dependency":I.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:I.dependencyId||pi(),source:I.dependency.source,target:I.dependency.target,type:I.dependency.type||"FS"}});break;case"remove-dependency":I.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:I.dependencyId});break}}function w(){t&&(n=!n,n?C():M())}function k(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const I=e.getState(),$=mi(I.tasks),R=Ke(o.projectFinish),N=Ke($),W=dn(R,N);let J=0;for(const[Z,ie]of o.tasks){const ge=I.tasks.get(Z);if(!ge){J++;continue}(ge.startDate!==ie.startDate||ge.endDate!==ie.endDate||ge.assignee!==ie.assignee)&&J++}for(const Z of I.tasks.keys())o.tasks.has(Z)||J++;return{baselineFinish:o.projectFinish,sandboxFinish:$,deltaDays:W,tasksAffected:J}}function D(){d&&d.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function C(){if(!h)return;const I=k();let $="ng-whatif-summary-value--unchanged",R="No change";I.deltaDays<0?($="ng-whatif-summary-value--improved",R=`${Math.abs(I.deltaDays)} day${Math.abs(I.deltaDays)!==1?"s":""} earlier`):I.deltaDays>0&&($="ng-whatif-summary-value--worsened",R=`${I.deltaDays} day${I.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${fi(I.baselineFinish)} &rarr; ${fi(I.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${$}">${R}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${I.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function P(){s=!s,u&&u.classList.toggle("ng-open",s),s&&L()}function _(){s=!1,u&&u.classList.remove("ng-open")}function U(){r&&(r.classList.add("ng-active"),l==null||l.focus())}function B(){r&&r.classList.remove("ng-active"),l&&(l.value="")}function A(){if(!l)return;const I=l.value.trim();I&&(m(I),B())}function L(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(I=>{var W;const $=new Date(I.createdAt).toLocaleDateString(),R=((W=I.result)==null?void 0:W.criticalPathDelta)??0;let N="No impact";return R<0?N=`${Math.abs(R)}d earlier`:R>0&&(N=`${R}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${I.id}">
            <div class="ng-whatif-scenario-name">${F(I.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${$}</span>
              <span>${I.changes.length} changes</span>
              <span>${N}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${I.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${I.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${I.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function F(I){const $=document.createElement("div");return $.textContent=I,$.innerHTML}function x(I){const $=I.target,R=$.getAttribute("data-action"),N=$.getAttribute("data-id");if(!(!R||!N))switch(R){case"load":S(N),_();break;case"compare":S(N),n=!0,C(),_();break;case"delete":y(N);break}}function z(I,$){switch(I.type){case"TASK_MOVE":{const R=$.tasks.get(I.taskId);R&&i.push({type:"move",taskId:I.taskId,before:{startDate:R.startDate,endDate:R.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"TASK_RESIZE":{const R=$.tasks.get(I.taskId);R&&i.push({type:"resize",taskId:I.taskId,before:{startDate:R.startDate,endDate:R.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:I.task.id,after:{...I.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:I.taskId,before:$.tasks.get(I.taskId)?{...$.tasks.get(I.taskId)}:void 0});break;case"UPDATE_TASK":{const R=$.tasks.get(I.taskId);R&&i.push({type:"reassign",taskId:I.taskId,before:{...R},after:I.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:I.dependency.id,dependency:{source:I.dependency.source,target:I.dependency.target,type:I.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:I.dependencyId});break}E()}function O(I,$,R,N,W,J){const Z=Math.min(J,N/2,W/2);I.beginPath(),I.moveTo($+Z,R),I.lineTo($+N-Z,R),I.arcTo($+N,R,$+N,R+Z,Z),I.lineTo($+N,R+W-Z),I.arcTo($+N,R+W,$+N-Z,R+W,Z),I.lineTo($+Z,R+W),I.arcTo($,R+W,$,R+W-Z,Z),I.lineTo($,R+Z),I.arcTo($,R,$+Z,R,Z),I.closePath()}return{name:"WhatIfPlugin",install(I){e=I,gd(),c.push(I.on("whatif:enter",()=>b())),c.push(I.on("whatif:exit",()=>T())),c.push(I.on("whatif:compare",()=>w())),c.push(I.on("whatif:discard",()=>g())),c.push(I.on("whatif:save",(...$)=>{const R=typeof $[0]=="string"?$[0]:void 0;R?m(R):U()})),c.push(I.on("whatif:load",(...$)=>{const R=typeof $[0]=="string"?$[0]:void 0;R?S(R):P()})),c.push(I.on("whatif:list-scenarios",(...$)=>{const R=typeof $[0]=="function"?$[0]:void 0;R?R([...a]):P()})),c.push(I.on("whatif:delete-scenario",(...$)=>{const R=typeof $[0]=="string"?$[0]:void 0;R&&y(R)}))},middleware(I,$){if(!t){$(I);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(I.type)&&e){const N=e.getState();z(I,N)}$(I)},renderCanvas(I,$,R){if(!t||!e)return;const{theme:N,headerHeight:W,barHeight:J}=$.config,Z=$.scrollX,ie=$.scrollY,ge=W,be=e.getTimeScale(),X=N.barBorderRadius;if(I.save(),I.beginPath(),I.rect(0,ge,I.canvas.width,I.canvas.height-ge),I.clip(),I.translate(-Z,0),o){const te=new Set;for(const q of R){const ee=o.tasks.get(q.taskId),se=$.tasks.get(q.taskId);(!ee&&se||ee&&se&&(ee.startDate!==se.startDate||ee.endDate!==se.endDate||ee.assignee!==se.assignee))&&te.add(q.taskId)}for(const q of R){if(!te.has(q.taskId))continue;const ee=q.x,se=q.barY-ie,de=q.width,ae=q.barHeight;se+ae<ge||se>I.canvas.height||(I.save(),I.setLineDash([4,3]),I.strokeStyle="#F6AD55",I.lineWidth=2,O(I,ee,se,de,ae,X),I.stroke(),I.restore())}}if(n&&o){const te=J*rd;for(const q of R){if(q.isMilestone)continue;const ee=o.tasks.get(q.taskId);if(!ee)continue;const se=$.tasks.get(q.taskId);if(!se)continue;const de=Ke(ee.startDate),ae=Ke(ee.endDate),fe=Ke(se.startDate),ce=Ke(se.endDate),Te=dn(de,fe),ve=dn(ae,ce);if(Te===0&&ve===0)continue;let G=gi;ve<0?G=di:ve>0&&(G=ui);const H=be.dateToX(de),Y=be.dateToX(ae),V=Math.max(Y-H,2),K=q.barY-ie,j=K+J+2;I.save(),I.globalAlpha=ci,I.fillStyle=G,O(I,H,j,V,te,X),I.fill(),I.globalAlpha=ci*2,I.strokeStyle=G,I.lineWidth=1,I.stroke(),I.restore();const ne=H+V/2,oe=j+te/2,re=q.x+q.width/2,le=K+J/2;I.save(),I.globalAlpha=.6,I.strokeStyle=G,I.lineWidth=1.5,I.setLineDash([3,2]),I.beginPath(),I.moveTo(ne,oe),I.lineTo(re,le),I.stroke();const me=Math.atan2(le-oe,re-ne),Se=re,Ae=le;I.setLineDash([]),I.beginPath(),I.moveTo(Se,Ae),I.lineTo(Se-cn*Math.cos(me-Math.PI/6),Ae-cn*Math.sin(me-Math.PI/6)),I.lineTo(Se-cn*Math.cos(me+Math.PI/6),Ae-cn*Math.sin(me+Math.PI/6)),I.closePath(),I.fillStyle=G,I.fill(),I.restore()}}I.restore()},renderDOM(I,$){if(!d){d=document.createElement("div"),d.className="ng-whatif-banner ng-hidden";const R=document.createElement("div");R.className="ng-whatif-banner-left";const N=document.createElement("span");N.className="ng-whatif-badge",N.textContent="What-If Mode",R.appendChild(N);const W=document.createElement("span");W.textContent="Changes are hypothetical",W.style.fontSize="12px",W.style.opacity="0.7",R.appendChild(W);const J=document.createElement("span");J.textContent="·",J.style.opacity="0.4",R.appendChild(J),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",R.appendChild(p),d.appendChild(R);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",l=document.createElement("input"),l.type="text",l.placeholder="Scenario name...",l.addEventListener("keydown",se=>{se.key==="Enter"&&A(),se.key==="Escape"&&B()});const ie=document.createElement("button");ie.className="ng-whatif-btn ng-whatif-btn--primary",ie.textContent="Save",ie.addEventListener("click",A);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>B()),r.appendChild(l),r.appendChild(ie),r.appendChild(ge),Z.appendChild(r);const be=document.createElement("button");be.className="ng-whatif-btn",be.textContent="Scenarios",be.addEventListener("click",()=>P()),Z.appendChild(be);const X=document.createElement("button");X.className="ng-whatif-btn ng-whatif-btn--primary",X.textContent="Compare with Baseline",X.addEventListener("click",()=>w()),Z.appendChild(X);const te=document.createElement("button");te.className="ng-whatif-btn",te.textContent="Save Scenario",te.addEventListener("click",()=>U()),Z.appendChild(te);const q=document.createElement("button");q.className="ng-whatif-btn ng-whatif-btn--danger",q.textContent="Discard",q.addEventListener("click",()=>g()),Z.appendChild(q);const ee=document.createElement("button");ee.className="ng-whatif-btn ng-whatif-btn--danger",ee.textContent="Exit",ee.addEventListener("click",()=>T()),Z.appendChild(ee),d.appendChild(Z),I.appendChild(d)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",I.appendChild(h)),!u){u=document.createElement("div"),u.className="ng-whatif-panel";const R=document.createElement("div");R.className="ng-whatif-panel-title";const N=document.createElement("span");N.textContent="Saved Scenarios",R.appendChild(N);const W=document.createElement("button");W.className="ng-whatif-panel-close",W.textContent="×",W.addEventListener("click",()=>_()),R.appendChild(W),u.appendChild(R),f=document.createElement("div"),f.addEventListener("click",x),u.appendChild(f),I.appendChild(u),L()}D(),n&&C()},destroy(){for(const I of c)I();c.length=0,d&&(d.remove(),d=null),u&&(u.remove(),u=null),h&&(h.remove(),h=null),p=null,r=null,l=null,f=null,hd(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Jn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},md=261.63;function yd(e){return md*Math.pow(2,e/12)}function bd(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return yd(n?a+12:a)}const Qn="nimbus-gantt-sonification-styles",es=64,un=64,yi=.05,Td=.1,vd=.7,bi=.2,ts="#F6AD55",Sd=2,wd="rgba(246, 173, 85, 0.35)",Ti=12,kd=`
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
`;function ns(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Dd(){if(typeof document>"u"||document.getElementById(Qn))return;const e=document.createElement("style");e.id=Qn,e.textContent=kd,document.head.appendChild(e)}function Ed(){if(typeof document>"u")return;const e=document.getElementById(Qn);e&&e.remove()}function Cd(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,c=null,d=null,u=null,h=null;const p=new Map;let r="stopped",l=0,f=0,b=0,T=0,g=0,m=0,S=0,y=null,v=null,w=null,k=null,D=null,E=null;const C=[];let M=[],P=[];function _(){if(c)return;const X=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;X&&(c=new X,d=c.createGain(),d.gain.value=i,u=c.createAnalyser(),u.fftSize=256,h=new Uint8Array(u.frequencyBinCount),d.connect(u),u.connect(c.destination))}function U(){c&&c.state==="suspended"&&c.resume()}function B(){if(!a)return;const X=a.getState(),te=Date.now();let q=1/0,ee=-1/0;const se=[],de=new Set,ae=X.flatVisibleIds,fe=new Map;for(let ce=0;ce<ae.length;ce++)fe.set(ae[ce],ce);for(const[ce,Te]of X.tasks){const ve=ns(Te.startDate).getTime(),G=ns(Te.endDate).getTime();ve<q&&(q=ve),G>ee&&(ee=G);const H=Te.groupId||"__default__";de.add(H);const Y=fe.get(ce)??0,V=!Te.isCompleted&&G<te&&(Te.progress??0)<1;se.push({id:ce,startMs:ve,endMs:G,rowIndex:Y,progress:Te.progress??0,groupId:H,isCritical:!1,isOverdue:V})}M=se,P=Array.from(de),g=q===1/0?0:q,m=ee===-1/0?0:ee,S=Math.max(m-g,1)}function A(X){if(!c||!d||p.has(X.id))return;const te=Jn[n]||Jn.major,q=bd(X.rowIndex,te,X.isCritical),ee=c.createOscillator();ee.type=s,ee.frequency.value=q,X.isOverdue&&(ee.detune.value=25);const se=.3+X.progress*.7,de=X.isOverdue?1.3:1,ae=Math.min(se*de,1),fe=c.createGain();fe.gain.setValueAtTime(0,c.currentTime),fe.gain.linearRampToValueAtTime(ae,c.currentTime+yi),fe.gain.linearRampToValueAtTime(ae*vd,c.currentTime+yi+Td);const ce=c.createStereoPanner();if(P.length<=1)ce.pan.value=0;else{const Te=P.indexOf(X.groupId);ce.pan.value=P.length>1?Te/(P.length-1)*2-1:0}ee.connect(fe),fe.connect(ce),ce.connect(d),ee.start(),p.set(X.id,{taskId:X.id,oscillator:ee,gainNode:fe,panNode:ce})}function L(X){const te=p.get(X);if(!te||!c)return;const q=c.currentTime;te.gainNode.gain.cancelScheduledValues(q),te.gainNode.gain.setValueAtTime(te.gainNode.gain.value,q),te.gainNode.gain.linearRampToValueAtTime(0,q+bi),te.oscillator.stop(q+bi+.05),p.delete(X)}function F(){for(const X of Array.from(p.keys()))L(X)}function x(){if(r!=="playing"||!c)return;const X=c.currentTime-l;if(f=Math.min(X/o,1),f>=1){I();return}const te=g+f*S;for(const q of M){const ee=te>=q.startMs&&te<q.endMs,se=p.has(q.id);ee&&!se?A(q):!ee&&se&&L(q.id)}Z(),T=requestAnimationFrame(x)}function z(){_(),U(),c&&(B(),r==="paused"?l=c.currentTime-b*o:(l=c.currentTime,f=0),r="playing",N(),W(),T=requestAnimationFrame(x))}function O(){r==="playing"&&(r="paused",b=f,F(),cancelAnimationFrame(T),N())}function I(){r="stopped",f=0,b=0,F(),cancelAnimationFrame(T),N(),J()}function $(){r==="playing"?O():z()}function R(X){const te=ns(X).getTime(),q=Math.max(0,Math.min((te-g)/S,1));r==="playing"&&c?l=c.currentTime-q*o:(b=q,f=q)}function N(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=ie(),D.classList.remove("ng-son-btn--active")))}function W(){v&&v.classList.remove("ng-hidden")}function J(){v&&v.classList.add("ng-hidden")}function Z(){if(!u||!h||!k||!w)return;u.getByteFrequencyData(h);const X=w.width,te=w.height;k.clearRect(0,0,X,te);const q=k.createLinearGradient(0,0,0,te);q.addColorStop(0,"rgba(26, 32, 44, 0)"),q.addColorStop(1,"rgba(26, 32, 44, 0.6)"),k.fillStyle=q,k.fillRect(0,0,X,te);const ee=X/un*.8,se=X/un*.2,de=Math.floor(h.length/un);for(let ae=0;ae<un;ae++){let fe=0;for(let V=0;V<de;V++)fe+=h[ae*de+V]??0;const ce=fe/de,Te=ce/255*te*.85,ve=ae*(ee+se),G=te-Te,H=30+ce/255*15,Y=55+ce/255*15;k.fillStyle=`hsl(${H}, 90%, ${Y}%)`,k.fillRect(ve,G,ee,Te)}}function ie(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function be(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(X){a=X,Dd(),C.push(X.on("sonification:play",()=>z())),C.push(X.on("sonification:pause",()=>O())),C.push(X.on("sonification:stop",()=>I())),C.push(X.on("sonification:scrub",(...te)=>{const q=typeof te[0]=="string"?te[0]:void 0;q&&R(q)})),C.push(X.on("sonification:configure",(...te)=>{const q=te[0];q&&(q.tempo!==void 0&&(t=q.tempo),q.scale!==void 0&&(n=q.scale),q.instrument!==void 0&&(s=q.instrument),q.duration!==void 0&&(o=q.duration),q.volume!==void 0&&(i=q.volume,d&&(d.gain.value=i)))}))},renderCanvas(X,te,q){if(r==="stopped"||!a)return;const{headerHeight:ee}=te.config,se=te.scrollX,de=te.scrollY,ae=ee,fe=a.getTimeScale(),ce=g+f*S,Te=new Date(ce),ve=fe.dateToX(Te);X.save(),X.beginPath(),X.rect(0,ae,X.canvas.width,X.canvas.height-ae),X.clip(),X.translate(-se,0),X.save(),X.shadowColor=ts,X.shadowBlur=Ti,X.strokeStyle=ts,X.lineWidth=Sd,X.beginPath(),X.moveTo(ve,ae),X.lineTo(ve,X.canvas.height+de),X.stroke(),X.restore();const G=new Map;for(const H of q)G.set(H.taskId,H);for(const H of p.values()){const Y=G.get(H.taskId);if(!Y)continue;const V=Y.x,K=Y.barY-de,j=Y.width,ne=Y.barHeight;if(K+ne<ae||K>X.canvas.height)continue;const oe=((c==null?void 0:c.currentTime)??0)*4%(2*Math.PI),re=.15+.15*Math.sin(oe);X.save(),X.globalAlpha=re,X.shadowColor=wd,X.shadowBlur=Ti,X.fillStyle=ts;const le=Math.min(te.config.theme.barBorderRadius,j/2,ne/2);X.beginPath(),X.moveTo(V+le,K),X.lineTo(V+j-le,K),X.arcTo(V+j,K,V+j,K+le,le),X.lineTo(V+j,K+ne-le),X.arcTo(V+j,K+ne,V+j-le,K+ne,le),X.lineTo(V+le,K+ne),X.arcTo(V,K+ne,V,K+ne-le,le),X.lineTo(V,K+le),X.arcTo(V,K,V+le,K,le),X.closePath(),X.fill(),X.restore()}X.restore()},renderDOM(X,te){if(!y){y=document.createElement("div"),y.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=ie(),D.title="Play / Pause",D.addEventListener("click",()=>$()),y.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=be(),E.title="Stop",E.addEventListener("click",()=>I()),y.appendChild(E);const q=document.createElement("div");q.className="ng-son-sep",y.appendChild(q);const ee=document.createElement("div");ee.style.display="flex",ee.style.flexDirection="column",ee.style.alignItems="center",ee.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",ee.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),ee.appendChild(de),y.appendChild(ee);const ae=document.createElement("div");ae.style.display="flex",ae.style.flexDirection="column",ae.style.alignItems="center",ae.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ae.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const Y of Object.keys(Jn)){const V=document.createElement("option");V.value=Y,V.textContent=Y.charAt(0).toUpperCase()+Y.slice(1),Y===n&&(V.selected=!0),ce.appendChild(V)}ce.addEventListener("change",()=>{n=ce.value}),ae.appendChild(ce),y.appendChild(ae);const Te=document.createElement("div");Te.className="ng-son-sep",y.appendChild(Te);const ve=document.createElement("div");ve.style.display="flex",ve.style.flexDirection="column",ve.style.alignItems="center",ve.style.gap="2px";const G=document.createElement("span");G.className="ng-son-label",G.textContent="Vol",ve.appendChild(G);const H=document.createElement("input");H.type="range",H.className="ng-son-slider",H.min="0",H.max="100",H.value=String(Math.round(i*100)),H.addEventListener("input",()=>{i=Number(H.value)/100,d&&(d.gain.value=i)}),ve.appendChild(H),y.appendChild(ve),X.appendChild(y)}if(!v){v=document.createElement("div"),v.className="ng-sonification-waveform ng-hidden",w=document.createElement("canvas"),k=w.getContext("2d");const q=(typeof window<"u"?window.devicePixelRatio:1)||1,ee=X.getBoundingClientRect();w.width=ee.width*q,w.height=es*q,w.style.width="100%",w.style.height=es+"px",k&&k.scale(q,q),v.appendChild(w),X.appendChild(v)}},destroy(){for(const X of C)X();C.length=0,I(),F(),c&&(c.close(),c=null),d=null,u=null,h=null,y&&(y.remove(),y=null),v&&(v.remove(),v=null),w=null,k=null,D=null,E=null,Ed(),a=null,M=[],P=[]}}}const Id=.55,Md=[4,3],Ad=1,Rd=4,Ld=600;function Pd(e={}){let t=null;const n=vi(e.futureFadeStrength??Id,0,1),s=e.futureDashedBorder!==!1,o=e.futureDashPattern??Md,i=e.futureDashWidth??Ad,a=e.pastShowCheckmark!==!1,c=e.todayProvider??(()=>new Date);return{name:"TemporalAsymmetryPlugin",install(d){t=d},renderCanvas(d,u,h){if(!t||h.length===0)return;const{config:p,scrollX:r,scrollY:l,tasks:f}=u,{theme:b}=p,T=p.headerHeight,g=b.barBorderRadius,m=c();let S;try{S=t.getTimeScale().dateToX(m)}catch{return}const y=e.futureFadeColor??b.timelineBg??"#ffffff",v=typeof window<"u"&&window.devicePixelRatio||1,w=d.canvas.width/v,k=d.canvas.height/v;d.save();const D=T,E=k-D;d.beginPath(),d.rect(0,D,w,E),d.clip(),d.translate(-r,0);for(const C of h){if(C.isMilestone)continue;const M=f.get(C.taskId);if(!M||M.status==="group-header")continue;const P=C.x,_=C.barY-l,U=C.width,B=C.barHeight;if(_+B<0||_>E)continue;const A=P+U,L=P>=S,F=A<=S,x=!L&&!F;if(L||x){const z=L?P:S,O=L?U:A-S;O>.5&&(d.save(),d.beginPath(),Si(d,P,_,U,B,g),d.clip(),d.globalAlpha=n,d.fillStyle=y,d.fillRect(z,_,O,B),d.restore())}if(s&&(L||x)){const z=e.futureDashColor??_d(C.color,.4);if(d.save(),d.lineWidth=i,d.strokeStyle=z,d.setLineDash(o),L)$d(d,P,_,U,B,g);else{const O=_+.5,I=_+B-.5;d.beginPath(),d.moveTo(S,O),d.lineTo(A-g,O),d.moveTo(S,I),d.lineTo(A-g,I),d.moveTo(S,_),d.lineTo(S,_+B),d.stroke()}d.setLineDash([]),d.restore()}if(a&&F&&(M.progress??0)>=1){const z=P+Rd+5,O=_+B/2,I=e.pastCheckmarkColor??Od(C.color);d.save(),d.font=`${Ld} ${Math.max(10,b.fontSize-1)}px ${b.fontFamily}`,d.textBaseline="middle",d.textAlign="left",d.fillStyle=I,d.fillText("✓",z-5,O),d.restore()}}d.restore()},destroy(){t=null}}}function vi(e,t,n){return Math.max(t,Math.min(n,e))}function Si(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.quadraticCurveTo(t+s,n,t+s,n+a),e.lineTo(t+s,n+o-a),e.quadraticCurveTo(t+s,n+o,t+s-a,n+o),e.lineTo(t+a,n+o),e.quadraticCurveTo(t,n+o,t,n+o-a),e.lineTo(t,n+a),e.quadraticCurveTo(t,n,t+a,n)}function $d(e,t,n,s,o,i){e.beginPath(),Si(e,t,n,s,o,i),e.stroke()}function _d(e,t){const n=wi(e);if(!n)return e;const s=Math.round((n.r+n.g+n.b)/3),o=i=>Math.round(i*(1-t)+s*t);return Nd(o(n.r),o(n.g),o(n.b))}function Od(e){const t=wi(e);return t?.299*t.r+.587*t.g+.114*t.b>140?"#1f2937":"#ffffff":"#1f2937"}function wi(e){const t=e.replace("#","");return t.length===3?{r:parseInt(t[0]+t[0],16),g:parseInt(t[1]+t[1],16),b:parseInt(t[2]+t[2],16)}:t.length===6?{r:parseInt(t.substring(0,2),16),g:parseInt(t.substring(2,4),16),b:parseInt(t.substring(4,6),16)}:null}function Nd(e,t,n){const s=o=>vi(o,0,255).toString(16).padStart(2,"0");return`#${s(e)}${s(t)}${s(n)}`}const Hd=5e3,xd=3e4,Bd=500,Fd=new Set(["SET_DATA","UPDATE_TASK","ADD_TASK","REMOVE_TASK","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ot(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}})}function Ud(e={}){const t=Math.max(100,e.capacity??Hd),n=e.compactAfterIdleMs??xd,s=Math.min(t,Math.max(50,e.compactKeep??Bd)),o=[],i=[];let a=null,c=null,d=null,u=null;function h(){u&&clearTimeout(u),u=setTimeout(p,n)}function p(){if(o.length<=s)return;const m=o.length-s;o.splice(0,m),ot("history:compaction",{dropped:m,kept:o.length})}function r(m){var S;if(o.push(m),ot("history:entry-recorded",{actionType:m.action.type,ts:m.wallTs,source:m.source}),o.length>t){const y=o.splice(0,1);ot("history:overflow-drop",{ts:(S=y[0])==null?void 0:S.wallTs})}if(h(),e.onEntry)try{const y=e.onEntry(m);y&&typeof y.catch=="function"&&y.catch(()=>{})}catch{}}e.hydrate&&o.push(...e.hydrate),e.hydrateAnnotations&&i.push(...e.hydrateAnnotations);function l(m,S){switch(S.type){case"SET_DATA":{const y=Array.from(m.tasks.values()),v=Array.from(m.dependencies.values());return{type:"SET_DATA",tasks:y,dependencies:v}}case"UPDATE_TASK":{const y=m.tasks.get(S.taskId);if(!y)return null;const v={};for(const w of Object.keys(S.changes))v[w]=y[w];return{type:"UPDATE_TASK",taskId:S.taskId,changes:v}}case"ADD_TASK":return{type:"REMOVE_TASK",taskId:S.task.id};case"REMOVE_TASK":{const y=m.tasks.get(S.taskId);return y?{type:"ADD_TASK",task:y}:null}case"TASK_MOVE":case"TASK_RESIZE":{const y=m.tasks.get(S.taskId);return y?{type:S.type,taskId:S.taskId,startDate:y.startDate,endDate:y.endDate}:null}case"ADD_DEPENDENCY":return{type:"REMOVE_DEPENDENCY",dependencyId:S.dependency.id};case"REMOVE_DEPENDENCY":{const y=m.dependencies.get(S.dependencyId);return y?{type:"ADD_DEPENDENCY",dependency:y}:null}default:return null}}function f(m,S){if(!Fd.has(m.type)){S(m);return}const y=a?a():null;if(!y){S(m);return}const v=l(y,m);S(m);const w=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),k=Date.now();r({ts:w,wallTs:k,action:m,inverse:v,actor:e.defaultActor,source:e.defaultSource??"local"})}function b(m){if(!a)return null;const S=m.getTime(),y=a();if(o.length===0)return y;const v=o[0].wallTs;if(S<v)return ot("history:snapshot-miss",{target:S,baselineTs:v}),null;const w=new gn(y);for(let k=o.length-1;k>=0;k--){const D=o[k];if(D.wallTs<=S)break;D.inverse&&w.dispatch(D.inverse)}return w.getState()}function T(m){const S=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),y=Date.now(),v={ts:S,wallTs:y,...m};if(i.push(v),ot("history:annotation-added",{kind:v.kind,taskId:v.taskId}),e.onAnnotation)try{const w=e.onAnnotation(v);w&&typeof w.catch=="function"&&w.catch(()=>{})}catch{}}const g={entries:()=>o,annotations:()=>i,snapshotAt:b,appendAnnotation:T,lastWallTs:()=>o.length>0?o[o.length-1].wallTs:null,scrubTo:m=>{c==null||c.setTimeCursor(m),ot("history:scrub",{cursorWallTs:m?m.getTime():null})},scrubToNow:()=>{c==null||c.setTimeCursor(null),ot("history:scrub",{cursorWallTs:null})}};return{name:"HistoryPlugin",install(m){a=m.getState,c=m.__gantt??null,c&&(c.history=g,typeof c.registerReplayProvider=="function"&&(d=c.registerReplayProvider({snapshotAt:S=>b(S)}))),ot("history:hydrate",{entryCount:o.length})},middleware:f,destroy(){u&&(clearTimeout(u),u=null),d&&(d(),d=null),c&&c.history===g&&(c.history=null),c=null}}}const Yd="#3b82f6",Wd=2,Xd="#10b981",zd=864e5;function Gd(e={}){let t=null,n=null,s=null;const o=e.cursorColor??Yd,i=e.cursorWidth??Wd,a=e.showNowBracket!==!1,c=e.nowBracketColor??Xd,d=e.enableKeyboardShortcuts!==!1,u=e.stepMs??zd;function h(l){if(!n)return;const b=n.getTimeCursor()??new Date,T=new Date(b.getTime()+l);n.setTimeCursor(T)}function p(){if(!(n!=null&&n.history))return;const l=n.history.entries();l.length!==0&&n.setTimeCursor(new Date(l[0].wallTs))}function r(l){const f=document.activeElement;if(!(f&&(f.tagName==="INPUT"||f.tagName==="TEXTAREA"||f.isContentEditable))){if(l.key==="Home"){l.preventDefault(),p();return}if(l.key==="End"){l.preventDefault(),n==null||n.setTimeCursor(null);return}if(l.key==="ArrowLeft"&&(l.altKey||l.metaKey)){l.preventDefault(),h(-u);return}if(l.key==="ArrowRight"&&(l.altKey||l.metaKey)){l.preventDefault(),h(u);return}}}return{name:"TimeCursorPlugin",install(l){t=l,n=l.__gantt??null,d&&typeof document<"u"&&(s=r,document.addEventListener("keydown",s))},renderCanvas(l,f,b){if(!t)return;const{config:T,scrollX:g}=f,m=T.headerHeight,S=typeof window<"u"&&window.devicePixelRatio||1,y=l.canvas.width/S,v=l.canvas.height/S,w=m,k=v-w;let D;try{D=t.getTimeScale()}catch{return}if(l.save(),l.beginPath(),l.rect(0,w,y,k),l.clip(),l.translate(-g,0),a){const C=D.dateToX(new Date);l.save(),l.strokeStyle=c,l.lineWidth=3,l.beginPath(),l.moveTo(C-6,w+1),l.lineTo(C+6,w+1),l.moveTo(C-6,w+k-1),l.lineTo(C+6,w+k-1),l.stroke(),l.restore()}const E=f.timeCursorDate;if(E){const C=D.dateToX(E);l.save(),l.strokeStyle=o,l.lineWidth=i,l.beginPath(),l.moveTo(C,w),l.lineTo(C,w+k),l.stroke(),l.fillStyle=o,l.beginPath(),l.moveTo(C-6,w),l.lineTo(C+6,w),l.lineTo(C,w+8),l.closePath(),l.fill(),l.restore()}l.restore()},destroy(){s&&typeof document<"u"&&document.removeEventListener("keydown",s),s=null,t=null,n=null}}}const Vd=14,Kd=4,jd=6,qd="#6b7280",Zd={comment:"#3b82f6",decision:"#8b5cf6","agent-note":"#10b981",view:"#a3a3a3"};function Jd(e={}){let t=null,n=null;const s=e.height??Vd,o=e.position??"above-body",i=e.markerRadius??Kd,a=e.clusterDistancePx??jd,c=e.fallbackColor??qd,d={...Zd,...e.colorByKind??{}};return{name:"HistoryStripPlugin",install(u){t=u,n=u.__gantt??null},renderCanvas(u,h,p){if(!t||!(n!=null&&n.history))return;const r=n.history.annotations();if(r.length===0)return;const{config:l,scrollX:f}=h,b=l.headerHeight,T=typeof window<"u"&&window.devicePixelRatio||1,g=u.canvas.width/T;let m;try{m=t.getTimeScale()}catch{return}const S=o==="above-body"?b-s:b+2;u.save(),u.beginPath(),u.rect(0,S,g,s),u.clip(),u.translate(-f,0);const y=[];for(const k of r){const D=m.dateToX(new Date(k.wallTs));y.push({x:D,ann:k})}y.sort((k,D)=>k.x-D.x);const v=[];for(const k of y){const D=v[v.length-1];D&&Math.abs(k.x-D.x)<=a?(D.entries.push(k),D.x=D.entries.reduce((E,C)=>E+C.x,0)/D.entries.length):v.push({x:k.x,entries:[k]})}const w=[];for(const k of v){const D=S+s/2,E=k.entries.length>1,C=k.entries[0].ann.kind,M=d[C]??c;u.fillStyle=M,u.beginPath(),u.arc(k.x,D,E?i+1:i,0,Math.PI*2),u.fill(),E&&(u.fillStyle="#ffffff",u.font="600 9px sans-serif",u.textBaseline="middle",u.textAlign="center",u.fillText(String(k.entries.length),k.x,D+.5)),w.push({cx:k.x,cy:D,r:E?i+1:i,annotations:k.entries.map(P=>P.ann)})}u.restore()},destroy(){t=null,n=null}}}const ki="nimbus-gantt-ctxmenu-styles",pe="ng-ctxmenu",Di={maxCalls:1,windowMs:2e3};function Qd(e){if(e===!1)return()=>!0;const t=e??Di,n=[];return function(){const o=Date.now(),i=o-t.windowMs;for(;n.length>0&&n[0]<i;)n.shift();return n.length>=t.maxCalls?!1:(n.push(o),!0)}}function Ei(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:Date.now(),kind:e,...t??{}})}function eu(e={}){let t=null,n=null,s=null,o=null,i=null,a=null;const c=Qd(e.agentRateLimit===void 0?Di:e.agentRateLimit);async function d(g,m){if(e.onConfirmDestructive)try{return!!await e.onConfirmDestructive(g,m)}catch{return!1}if(typeof window<"u"&&typeof window.confirm=="function"){const S=g==="task"?`Delete task "${m}"?`:`Delete dependency "${m}"?`;try{return window.confirm(S)}catch{return!1}}return!0}function u(){if(typeof document>"u"||document.getElementById(ki))return;const g=document.createElement("style");g.id=ki,g.textContent=`
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
    `,document.head.appendChild(g)}function h(){if(s){try{s.remove()}catch{}s=null}a&&typeof document<"u"&&(document.removeEventListener("pointerdown",a,!0),document.removeEventListener("keydown",a,!0),a=null)}function p(g,m,S){if(typeof document>"u"||g.length===0)return;h(),u();const y=document.createElement("div");y.className=pe,y.setAttribute("role","menu"),y.style.left=`${m.x}px`,y.style.top=`${m.y}px`,y.addEventListener("pointerdown",v=>{v.stopPropagation()});for(const v of g){if(v.divider){const E=document.createElement("div");E.className=`${pe}-divider`,y.appendChild(E);continue}const w=document.createElement("div");w.className=`${pe}-item`,v.disabled&&w.setAttribute("aria-disabled","true");const k=document.createElement("span");k.className=`${pe}-icon`,v.agentSuggested&&k.classList.add(`${pe}-agent-glyph`),k.textContent=v.icon??(v.agentSuggested?"✦":""),w.appendChild(k);const D=document.createElement("span");if(D.className=`${pe}-label`,D.textContent=v.label,w.appendChild(D),v.shortcut){const E=document.createElement("span");E.className=`${pe}-shortcut`,E.textContent=v.shortcut,w.appendChild(E)}if(v.children&&v.children.length>0){const E=document.createElement("span");E.className=`${pe}-arrow`,E.textContent="▸",w.appendChild(E);let C=null;w.addEventListener("mouseenter",()=>{if(C)return;const M=w.getBoundingClientRect();C=document.createElement("div"),C.className=pe,C.style.left=`${M.right+2}px`,C.style.top=`${M.top}px`;for(const P of v.children){const _=r(P,S);C.appendChild(_)}document.body.appendChild(C)}),w.addEventListener("mouseleave",()=>{if(C){try{C.remove()}catch{}C=null}})}else v.disabled||w.addEventListener("click",E=>{E.stopPropagation(),l(v,S,m)});y.appendChild(w)}document.body.appendChild(y),s=y,a=v=>{v instanceof KeyboardEvent&&v.key!=="Escape"||v.type==="pointerdown"&&v.target instanceof Element&&v.target.closest(`.${pe}`)||h()},document.addEventListener("pointerdown",a,!0),document.addEventListener("keydown",a,!0),requestAnimationFrame(()=>{if(!s)return;const v=s.getBoundingClientRect(),w=window.innerWidth,k=window.innerHeight;let D=v.left,E=v.top;v.right>w&&(D=Math.max(4,w-v.width-4)),v.bottom>k&&(E=Math.max(4,k-v.height-4)),s.style.left=`${D}px`,s.style.top=`${E}px`})}function r(g,m){if(g.divider){const w=document.createElement("div");return w.className=`${pe}-divider`,w}const S=document.createElement("div");S.className=`${pe}-item`,g.disabled&&S.setAttribute("aria-disabled","true");const y=document.createElement("span");y.className=`${pe}-icon`,g.agentSuggested&&y.classList.add(`${pe}-agent-glyph`),y.textContent=g.icon??(g.agentSuggested?"✦":""),S.appendChild(y);const v=document.createElement("span");return v.className=`${pe}-label`,v.textContent=g.label,S.appendChild(v),g.disabled||S.addEventListener("click",w=>{w.stopPropagation(),l(g,m,{x:0,y:0})}),S}function l(g,m,S){if(h(),g.agentSuggested&&g.prompt&&e.onAgentRequest&&(t!=null&&t.agent)){if(!c()){Ei("ctxmenu:agent-rate-limited",{itemId:g.id});return}const y={hit:m,pos:S,prompt:g.prompt,snapshot:t.agent.getSnapshot()};try{const v=e.onAgentRequest(y);v&&typeof v.catch=="function"&&v.catch(()=>{})}catch{}return}if(g.onClick)try{const y=g.onClick();y&&typeof y.catch=="function"&&y.catch(()=>{})}catch{}}function f(g,m,S){return async()=>{await d(g,m)?S():Ei("ctxmenu:destructive-cancelled",{kind:g,label:m})}}function b(g,m){const S=[],y=!!e.onAgentRequest&&!e.hideAgentSubmenu;switch(g.zone){case"bar":return S.push({id:"edit",label:"Edit task…",icon:"✎",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"edit",g.task,m)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"reparent",g.task,m)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"change-bucket",g.task,m)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"mark-complete",g.task,m)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"delete",g.task,m)})}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-why",label:"Ask Claude: why is this scheduled here?",agentSuggested:!0,prompt:`Explain why task "${g.task.name}" (id ${g.task.id}) is scheduled from ${g.task.startDate} to ${g.task.endDate} given current dependencies, parent context, and bucket assignment.`},{id:"agent-blocks",label:"Ask Claude: what blocks this?",agentSuggested:!0,prompt:`What dependencies, capacity constraints, or upstream blockers are gating task "${g.task.name}" (id ${g.task.id})? Walk the dependency graph and list the critical path.`},{id:"agent-resched",label:"Ask Claude: reschedule with critical-path optimization",agentSuggested:!0,prompt:`Suggest a new schedule for task "${g.task.name}" (id ${g.task.id}) that optimizes the critical path. Stage hypotheses via gantt.agent if possible.`}),S;case"row-label":return S.push({id:"edit",label:"Edit name…",icon:"✎",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"edit",g.task,m)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"reparent",g.task,m)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"change-bucket",g.task,m)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"mark-complete",g.task,m)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var v;return(v=e.onTaskAction)==null?void 0:v.call(e,"delete",g.task,m)})}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-summarize",label:"Ask Claude: summarize this task",agentSuggested:!0,prompt:`Summarize task "${g.task.name}" (id ${g.task.id}) including its current status, parent, dependencies, and recent history if available.`}),S;case"date-header":{const v=g.date.toISOString().slice(0,10);return S.push({id:"scroll-here",label:`Scroll to ${v}`,icon:"↔",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"scroll-here",g.date,m)}},{id:"zoom-to",label:"Zoom to this range",icon:"⊕",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"zoom-to",g.date,m)}},{id:"add-milestone",label:`Add milestone on ${v}`,icon:"◆",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"add-milestone",g.date,m)}}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-summary",label:`Ask Claude: what's happening around ${v}?`,agentSuggested:!0,prompt:`Summarize tasks, milestones, and dependencies that intersect ${v}. Note any clusters, conflicts, or capacity hotspots.`}),S}case"canvas-empty":{const v=g.date.toISOString().slice(0,10),w=v,k=(()=>{const D=new Date(g.date);return D.setUTCDate(D.getUTCDate()+5),D.toISOString().slice(0,10)})();return S.push({id:"create-task",label:`Create work item starting ${v}`,icon:"＋",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:w,endDate:k,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},m)}},{id:"create-milestone",label:`Insert milestone on ${v}`,icon:"◆",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:v,endDate:v,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},m)}}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-suggest",label:"Ask Claude: suggest a task here",agentSuggested:!0,prompt:`Given the project context and the dates around ${v}${g.bucketId?` in bucket "${g.bucketId}"`:""}, suggest a sensible work item to insert. Consider open dependencies, capacity, and priority.`}),S}case"bucket-header":{const v=g.bucketTask.name||g.bucketId||"(bucket)";return S.push({id:"add-to-bucket",label:`Add task to ${v}`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:new Date().toISOString().slice(0,10),endDate:new Date(Date.now()+432e6).toISOString().slice(0,10),parentId:g.bucketTask.id,bucket:g.bucketId},m)}},{id:"collapse",label:`Collapse all in ${v}`,icon:"⊟",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"collapse",g.bucketTask,m)}},{id:"expand",label:`Expand all in ${v}`,icon:"⊞",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"expand",g.bucketTask,m)}}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-rebalance",label:`Ask Claude: rebalance ${v}`,agentSuggested:!0,prompt:`Review the tasks in bucket "${v}" for capacity, sequencing, and priority alignment. Suggest moves to/from adjacent buckets and reordering within.`}),S}case"below-rows":{const v=g.date.toISOString().slice(0,10);return S.push({id:"create-end",label:`Add new task at end (starts ${v})`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:v,endDate:new Date(g.date.getTime()+432e6).toISOString().slice(0,10),parentId:null,bucket:null},m)}}),S}case"dependency":return S.push({id:"change-fs",label:"Change type → Finish-to-Start (FS)",icon:"→",onClick:()=>{var v;return(v=e.onDependencyAction)==null?void 0:v.call(e,"change-type-fs",g.depId,m)}},{id:"change-ss",label:"Change type → Start-to-Start (SS)",icon:"↦",onClick:()=>{var v;return(v=e.onDependencyAction)==null?void 0:v.call(e,"change-type-ss",g.depId,m)}},{id:"change-ff",label:"Change type → Finish-to-Finish (FF)",icon:"↤",onClick:()=>{var v;return(v=e.onDependencyAction)==null?void 0:v.call(e,"change-type-ff",g.depId,m)}},{id:"change-sf",label:"Change type → Start-to-Finish (SF)",icon:"↔",onClick:()=>{var v;return(v=e.onDependencyAction)==null?void 0:v.call(e,"change-type-sf",g.depId,m)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete dependency",icon:"×",onClick:f("dependency",g.depId,()=>{var v;return(v=e.onDependencyAction)==null?void 0:v.call(e,"delete",g.depId,m)})}),y&&S.push({id:"div-agent",label:"",divider:!0},{id:"agent-explain-dep",label:"Ask Claude: is this dependency necessary?",agentSuggested:!0,prompt:`Evaluate dependency ${g.depId}. Is it logically required, or could the predecessor and successor run in parallel? Consider data flow, resource contention, and external constraints.`}),S;case"outside":default:return[]}}function T(g){if(!t||!n||g.button!==void 0&&g.button!==2)return;const m=t.hitTestAt(g.clientX,g.clientY);if(m.zone==="outside")return;g.preventDefault(),g.stopPropagation();const S={x:g.clientX,y:g.clientY};let y=null;if(e.onContextMenu)try{y=e.onContextMenu(m,S)}catch{y=null}const v=y&&Array.isArray(y)&&y.length>0?y:b(m,S);v.length>0&&p(v,S,m)}return{name:"ContextMenuPlugin",install(g){t=g.__gantt??null,n=(t&&t.rootEl)??null;const m=n??(typeof document<"u"?document:null);m&&(o=S=>T(S),m.addEventListener("contextmenu",o),e.disablePointerDownFallback||(i=S=>{S.button===2&&T(S)},m.addEventListener("pointerdown",i)))},destroy(){h();const g=n??(typeof document<"u"?document:null);g&&(o&&g.removeEventListener("contextmenu",o),i&&g.removeEventListener("pointerdown",i)),o=null,i=null,t=null,n=null}}}return Q.AutoSchedulePlugin=Yr,Q.BaselinePlugin=Xa,Q.CLOUD_NIMBUS_PRIORITY_BUCKETS=Ia,Q.ConfigPanelPlugin=xl,Q.ContextMenuPlugin=eu,Q.CriticalPathPlugin=_a,Q.DARK_THEME=Ds,Q.DarkThemePlugin=ir,Q.DependencyRenderer=ys,Q.EventBus=is,Q.ExportPlugin=Ja,Q.GroupingPlugin=ka,Q.HeatmapViewPlugin=jl,Q.HistoryPlugin=Ud,Q.HistoryStripPlugin=Jd,Q.HitTest=fs,Q.KeyboardPlugin=ia,Q.LIGHT_THEME=mn,Q.LayoutEngine=ds,Q.MSProjectPlugin=wr,Q.MilestonePlugin=ga,Q.MiniMapPlugin=rc,Q.MonteCarloPlugin=Kc,Q.MotionControlPlugin=mr,Q.NarrativePlugin=od,Q.NetworkGraphPlugin=Pl,Q.NimbusGantt=Ji,Q.PriorityGroupingPlugin=Ca,Q.ResourceLevelingPlugin=Ur,Q.RiskAnalysisPlugin=fl,Q.SonificationPlugin=Cd,Q.SplitTaskPlugin=Pr,Q.TelemetryPlugin=hr,Q.TemporalAsymmetryPlugin=Pd,Q.TimeCursorPlugin=Gd,Q.TimeScale=ls,Q.TimeTravelPlugin=Oc,Q.TimelineNotesPlugin=Dc,Q.TooltipManager=ks,Q.UndoRedoPlugin=sa,Q.VirtualScrollPlugin=Ka,Q.WhatIfPlugin=pd,Q.WorkCalendarPlugin=dr,Q.buildDependencyGraph=po,Q.computeCPM=vn,Q.computeSchedule=On,Q.exportMSProjectXML=An,Q.getAllParentIds=Is,Q.getDescendantIds=Ms,Q.hoursWeightedProgress=Ma,Q.importMSProjectXML=Mn,Q.parseDate=bt,Q.resolveConfig=Es,Q.rollupHoursDeduped=ta,Object.defineProperty(Q,Symbol.toStringTag,{value:"Module"}),Q})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
