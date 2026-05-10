var NimbusGantt=(function(J){"use strict";function Fe(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let c=n.get(u);c||(c=[],n.set(u,c)),c.push(l)}const s=[];function o(l,u){const c=l.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return c!==h?c-h:l.name.localeCompare(u.name)}function i(l,u,c){const h=n.get(l);return h?(h.sort(o),h.map(p=>{const d=n.has(p.id)&&t.has(p.id),f=c,w={task:p,children:[],depth:u,expanded:d,visible:f,rowIndex:-1};return f&&(w.rowIndex=s.length,s.push(p.id)),w.children=i(p.id,u+1,f&&d),w})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function mt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class dn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=wi(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function wi(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Fe(n,e.expandedIds),a=mt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Fe(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Fe(n,e.expandedIds),i=mt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Fe(n,e.expandedIds),i=mt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Fe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Fe(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Fe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=mt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};case"SET_TIME_CURSOR":return{...e,timeCursorDate:t.date};default:return e}}function ts(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class ns{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const un=864e5,Si=un*7,ki={day:40,week:120,month:180,quarter:200},ss=["January","February","March","April","May","June","July","August","September","October","November","December"],os=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class is{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=ki[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/un)}countWeeks(){return Math.ceil(this.totalMs/Si)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=as(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=gn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${ss[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=as(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${os[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=gn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),c=this.dateToX(l);t.push({label:`${ss[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:c-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:os[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=gn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=Di(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}}function as(e,t){return new Date(e.getTime()+t*un)}function Di(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function gn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class rs{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const c=yt(u.startDate),h=yt(u.endDate),p=s.dateToX(c),r=s.dateToX(h)-p,d=Math.max(r,o.minBarWidth),f=a*o.rowHeight,w=f+(o.rowHeight-o.barHeight)/2,v=d*(u.progress||0),g=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:f,width:d,barY:w,barHeight:o.barHeight,progressWidth:v,color:g,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function yt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Pt=864e5,ls=1,Ei=2,Ci=.5,Ii=2,cs=8,Mi=6,hn=2;class Ai{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:c}=u,h=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const d=u.headerHeight,f=a-d;this.fillRect(0,0,i,a,c.timelineBg),o.save(),o.beginPath(),o.rect(0,d,i,f),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,d,f,c),this.renderGridLines(s,d,f,c,h),this.renderAltRows(t,n,d,c,h,p);const w=this.getTodayX(t,u,s);u.showToday&&w!==null&&this.renderTodayBackground(w,s,d,f,c),this.renderGroupRowBgs(t,n,u,h,p,d,f),this.renderTaskBars(t,n,u,c,h,p,d,f),this.renderDragSnapGuide(t,n,s,d,f,c),u.showToday&&w!==null&&this.renderTodayLine(w,d,f,c),o.restore(),this.renderHeader(s,u,c,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const c=l.getTime();for(;u.getTime()<=c;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+Pt),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}u.setTime(u.getTime()+Pt)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=Ci;for(const u of l){const c=this.snapToPixel(u);a.moveTo(c,n),a.lineTo(c,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,c=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*c-a;if(r+c<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,c,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+Pt),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:u,displayWidth:c}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const d=p.y-i+a;d+h<a||d>a+l||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,d,c,h),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,d,c,2)),u.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const l=t.dragState;if(!l||l.type!=="move"&&l.type!=="resize-left"&&l.type!=="resize-right")return;const u=n.find(v=>v.taskId===l.taskId);if(!u)return;const c=new Date;c.setHours(0,0,0,0);const h=new Date(c.getTime()+Pt),p=s.dateToX(h)-s.dateToX(c);if(p<=0)return;const r=l.currentX-l.startX;let d;l.type==="move"||l.type==="resize-left"?d=u.x+r:d=u.x+u.width+r;const f=Math.round(d/p)*p,{ctx:w}=this;w.save(),w.strokeStyle=a.barSelectedBorder||"#3b82f6",w.lineWidth=1,w.setLineDash([4,3]),w.globalAlpha=.85,w.beginPath(),w.moveTo(f+.5,o),w.lineTo(f+.5,o+i),w.stroke(),w.restore()}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:c}=this,h=o.barBorderRadius,p=t.dragState,r=p?p.currentX-p.startX:0,d=4;for(const f of n){let w=f.x;const v=f.barY-a+l;let g=f.width;const y=f.barHeight;if(v+y<l||v>l+u)continue;const b=p&&p.taskId===f.taskId;if(b){if(p.type==="move")w+=r;else if(p.type==="resize-left"){const k=w+r,D=g-r;D>=d&&(w=k,g=D)}else if(p.type==="resize-right"){const k=g+r;k>=d&&(g=k)}}if(f.isMilestone){this.renderMilestone(w,v,y,f.color,o,t.selectedIds.has(f.taskId));continue}const m=t.tasks.get(f.taskId),T=m&&m.status!=="group-header"&&m.style?m.style:null,S=T?this.resolveFillOpacity(T):1;if(S<1?(c.save(),c.globalAlpha=S,this.fillRoundedRect(w,v,g,y,h,f.color),c.restore()):this.fillRoundedRect(w,v,g,y,h,f.color),s.showProgress&&f.progressWidth>0){const k=this.darkenColor(f.color,.2);c.save(),c.beginPath(),this.roundedRectPath(w,v,g,y,h),c.clip(),c.fillStyle=k,c.fillRect(w,v,f.progressWidth,y),c.restore()}t.selectedIds.has(f.taskId)&&this.strokeRoundedRect(w,v,g,y,h,o.barSelectedBorder,hn),b&&this.strokeRoundedRect(w,v,g,y,h,o.barSelectedBorder,hn),T&&T.borderStyle&&T.borderStyle!=="none"&&this.renderDecoratorBorder(T,w,v,g,y,h,f.color),this.renderBarLabel(f,w,v,g,y,o),T&&T.badge&&T.badge.text&&this.renderDecoratorBadge(T.badge,w,v,g,y,f.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,l){const{ctx:u}=this,c=t.borderWidth??2,h=t.borderColor??this.darkenColor(l,.3),p=t.borderStyle??"solid";let r;switch(p){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(u.save(),u.setLineDash(r),u.strokeStyle=h,u.lineWidth=c,this.roundedRectPath(n,s,o,i,a),u.stroke(),p==="double"){const d=c+1,f=Math.max(0,a-d);u.lineWidth=c,this.roundedRectPath(n+d,s+d,Math.max(0,o-d*2),Math.max(0,i-d*2),f),u.stroke()}u.restore()}renderDecoratorBadge(t,n,s,o,i,a,l){const{ctx:u}=this,c=t.text,h=t.placement??"end",p=Math.max(14,i*.65),r=6;u.save();const d=`${Math.round(l.fontSize*.85)}px ${l.fontFamily}`;u.font=d,u.textBaseline="middle";const w=u.measureText(c).width+r*2,v=s+(i-p)/2,g=h==="start"?n+2:n+o-w-2;u.shadowColor="rgba(0,0,0,0.25)",u.shadowBlur=3,u.shadowOffsetY=1;const y=t.color??"#ffffff";u.fillStyle=y,this.roundedRectPath(g,v,w,p,p/2),u.fill(),u.shadowColor="transparent",u.shadowBlur=0,u.shadowOffsetY=0,u.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),u.textAlign="center",u.fillText(c,g+w/2,v+p/2),u.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-Ii*2)/2,c=n+s/2;l.save(),l.beginPath(),l.moveTo(t,c-u),l.lineTo(t+u,c),l.lineTo(t,c+u),l.lineTo(t-u,c),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=hn,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const c=l.measureText(t.label).width,h=s+i/2;c+cs*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+cs,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+Mi,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=Ei,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const c=u.length||2,h=l/c,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let d=0;d<u.length;d++){const f=u[d],w=d*h;for(const v of f){const g=v.x-o,y=v.width;if(g+y<0||g>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=ls;const b=this.snapToPixelRaw(g+y);i.moveTo(b,w),i.lineTo(b,w+h),i.stroke(),i.save(),i.beginPath(),i.rect(g,w,y,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(v.label,g+y/2,w+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=ls,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const ds="ng-tree-grid-styles";function Li(e,t){const n=e.querySelector(`#${ds}`);n&&n.remove();const s=document.createElement("style");s.id=ds,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function Ri(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function _t(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class Pi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;Li(this.rootEl,a),this.columns=o,this.columnWidths=o.map(c=>c.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=Ri(n),u=l.map(c=>c.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const c=document.createElement("span");c.className="ng-th-text",c.textContent=a.header,u.appendChild(c);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=c=>{const h=c.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,d=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),d[n]&&(d[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const c of t)l.set(c.task.id,c);for(const[c,h]of this.rows)a.has(c)||(h.remove(),this.rows.delete(c));let u=null;for(let c=0;c<t.length;c++){const h=t[c],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,c,s):(r=this.createRow(h,c,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const c=this.createCell(t,u,s);l.appendChild(c)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const c=document.createElement("span");c.className="ng-expand-icon",t.expanded&&c.classList.add("ng-expanded"),c.innerHTML="&#9654;",c.setAttribute("data-expand",t.task.id),o.appendChild(c)}else{const c=document.createElement("span");c.className="ng-expand-spacer",o.appendChild(c)}if(t.children.length===0&&!t.task.groupBg){const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",o.appendChild(c)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const c=document.createElement("span");c.className="ng-status-dot",c.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(c)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=_t(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=_t(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let c=0;c<a.length;c++){const h=a[c],p=l[c];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const d=`${n.depth*20+8}px`;p.style.paddingLeft!==d&&(p.style.paddingLeft=d);const f=p.querySelector(".ng-expand-icon"),w=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(f)n.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{w&&w.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(f){f.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const v=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!v){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const T=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");T?p.insertBefore(m,T):p.appendChild(m)}}else v&&v.remove();const g=p.querySelector(".ng-status-dot"),y=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(y&&n.children.length===0)if(g)g.style.background=y;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${y};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const T=p.querySelector(".ng-grid-cell-text");T?p.insertBefore(m,T):p.appendChild(m)}else g&&g.remove();const b=p.querySelector(".ng-grid-cell-text");if(b){const m=_t(n.task,h);b.textContent!==m&&(b.textContent=m)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",p.appendChild(d)}}else r&&(p.textContent="")}else{const r=_t(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class _i{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class us{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const c=i+s.progressWidth;if(Math.abs(t-c)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const gs=864e5;function $t(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/gs)}function Tt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Oe(e,t){const n=Tt(e),s=new Date(n.getTime()+t*gs),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function hs(e,t,n){return Math.max(t,Math.min(n,e))}const $i=3,Oi=300;class Ni{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new us,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.panning){t.preventDefault();const l=t.clientX-this.panStartClientX,u=t.clientY-this.panStartClientY,c=this.options.scrollManager;if(c){const h=Math.max(0,this.panOrigScrollX-l),p=Math.max(0,this.panOrigScrollY-u);c.setScrollPosition(h,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const u=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=u.x,this.panOrigScrollY=u.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l){this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const u=Hi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=$t(i,o);let l="";if(this.dragHit.type==="bar"){const d=Oe(this.dragOriginalStartDate,a),f=Oe(this.dragOriginalEndDate,a);l=`${d} → ${f}`}else if(this.dragHit.type==="bar-left-edge")l=`Start → ${Oe(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")l=`End → ${Oe(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const d=this.dragHit.layout,{canvasX:f}=this.toCanvasCoords(t),w=f-d.x;l=`${Math.round(hs(w/d.width,0,1)*100)}%`}if(!l)return;if(!this.gestureLabelEl){const d=document.createElement("div");d.setAttribute("data-nga-gesture-label","1"),d.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(d),this.gestureLabelEl=d,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=l;const u=12,c=window.innerWidth||document.documentElement.clientWidth,h=this.gestureLabelEl.offsetWidth,p=Math.min(t.clientX+u,c-h-4),r=t.clientY+u;this.gestureLabelEl.style.left=`${p}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<$i?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Oi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var u,c,h,p,r,d,f,w,v,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,l=t.clientX-this.dragStartX;switch(a){case"bar":{const y=t.clientY-this.dragStartY,b=Math.abs(l),m=Math.abs(y),T=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),S=m>b*1.5&&m>12;if(T&&S){const C=this.options.getLayouts(),M=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),A=C.find(P=>P.rowIndex===M),R=A?A.taskId:null;let O=null;const $=C.slice().sort((P,x)=>P.rowIndex-x.rowIndex);for(const P of $){if(P.rowIndex>M)break;const x=P.taskId;typeof x=="string"&&x.indexOf("__bucket_header__")===0&&(O=x.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",M,"target=",R,"bucket=",O)}catch{}(c=(u=this.options).onBarReorderDrag)==null||c.call(u,s,R,M,O);break}const k=$t(l,o),D=Oe(this.dragOriginalStartDate,k),E=Oe(this.dragOriginalEndDate,k);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:D,endDate:E});try{console.log("[NG engine] drag commit move",s.id,D,E,"hasCb=",!!this.options.onTaskMove)}catch{}(p=(h=this.options).onTaskMove)==null||p.call(h,s,D,E);break}case"bar-left-edge":{const y=$t(l,o),b=Oe(this.dragOriginalStartDate,y),m=Tt(this.dragOriginalEndDate),S=Tt(b).getTime()>=m.getTime()?Oe(this.dragOriginalEndDate,-1):b;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:S,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,S,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(d=(r=this.options).onTaskResize)==null||d.call(r,s,S,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=$t(l,o),b=Oe(this.dragOriginalEndDate,y),m=Tt(this.dragOriginalStartDate),S=Tt(b).getTime()<=m.getTime()?Oe(this.dragOriginalStartDate,1):b;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:S});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,S,"hasCb=",!!this.options.onTaskResize)}catch{}(w=(f=this.options).onTaskResize)==null||w.call(f,s,this.dragOriginalStartDate,S);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:b}=this.toCanvasCoords(t),m=b-y.x,T=hs(m/y.width,0,1),S=Math.round(T*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:S}}),(g=(v=this.options).onTaskProgressChange)==null||g.call(v,s,S);break}}this.options.dispatch({type:"DRAG_END"})}}function Hi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const Ne=12,bt=6,Ot=4,xi=3;class fs{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const c=new Map;for(const r of s)c.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const d=c.get(r.source),f=c.get(r.target);if(!d||!f)continue;const w=r.type||"FS",{sourceX:v,sourceY:g,targetX:y,targetY:b}=this.getConnectionPoints(w,d,f,a,l);this.drawRoutedPath(t,w,v,g,y,b,o),this.drawArrowhead(t,w,y,b,o),this.drawConnectionDot(t,v,g,o),this.drawConnectionDot(t,y,b,o)}t.restore()}hitTest(t,n,s,o,i,a,l=8){const{dependencies:u}=s;if(u.size===0||n<a)return null;const c=new Map;for(const p of o)c.set(p.taskId,p);let h=null;for(const p of u.values()){const r=c.get(p.source),d=c.get(p.target);if(!r||!d)continue;const f=p.type||"FS",{sourceX:w,sourceY:v,targetX:g,targetY:y}=this.getConnectionPoints(f,r,d,i,a),b=t-g,m=n-y,T=Math.sqrt(b*b+m*m);if(T<=l+bt){(!h||T<h.dist)&&(h={depId:p.id,dist:T});continue}const S=f==="FS"||f==="SS"?g-Ne:g+Ne,k=Math.min(S,g),D=Math.max(S,g);if(t>=k-l&&t<=D+l&&Math.abs(n-y)<=l){const A=Math.abs(n-y);(!h||A<h.dist)&&(h={depId:p.id,dist:A})}const E=f==="FS"||f==="FF"?w+Ne:w-Ne,C=Math.min(w,E),M=Math.max(w,E);if(t>=C-l&&t<=M+l&&Math.abs(n-v)<=l){const A=Math.abs(n-v);(!h||A<h.dist)&&(h={depId:p.id,dist:A})}}return(h==null?void 0:h.depId)??null}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",c=n==="FS"||n==="SS",h=u?s+Ne:s-Ne,p=c?i-Ne:i+Ne;if(u?c?p>=h:i+Ne>=h:c?i-Ne<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const d=(o+a)/2;t.lineTo(h,o),t.lineTo(h,d),t.lineTo(p,d),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-bt,o-Ot),t.lineTo(s-bt,o+Ot)):(t.moveTo(s,o),t.lineTo(s+bt,o-Ot),t.lineTo(s+bt,o+Ot)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,xi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Nt=12,Bi=100,Fi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Ui=`
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
`;function ct(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function ps(e){const t=e.split("-");if(t.length!==3)return ct(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?ct(e):`${Fi[n]} ${s}`}function vt(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${ct(e)}</span><span class="ng-tooltip-value">${ct(t)}</span></div>`}function Yi(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=vt("Status",e.status||"None"),i+=vt("Assignee",e.assignee||"Unassigned"),i+=vt("Dates",`${ps(e.startDate)} → ${ps(e.endDate)}`),n>0&&(i+=vt("Progress",`${n}%`)),s!=null&&(i+=vt("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${ct(t)}"><span class="ng-tooltip-name">${ct(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class ms{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Ui,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const c=this.customRenderer(t);typeof c=="string"?this.tooltipEl.innerHTML=c:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(c))}else this.tooltipEl.innerHTML=Yi(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+Nt,u=s+Nt;l+i.width>a.width&&(l=n-Nt-i.width),u+i.height>a.height&&(u=s-Nt-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Bi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const fn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},ys={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Wi=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function Ts(e){const t=Xi(e.theme);return{columns:e.columns??Wi,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function Xi(e){return!e||e==="light"?{...fn}:e==="dark"?{...ys}:{...fn,...e}}function dt(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const bs="nimbus-gantt-root-styles";function zi(){if(typeof document>"u"||document.getElementById(bs))return;const e=document.createElement("style");e.id=bs,e.textContent=`
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
  `,document.head.appendChild(e)}class Gi{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.replayProvider=null,this.agent={getSnapshot:()=>{const h=this.getDisplayState();return{cursorDate:h.timeCursorDate?h.timeCursorDate.toISOString():null,zoomLevel:h.zoomLevel,tasks:Array.from(h.tasks.values()),dependencies:Array.from(h.dependencies.values()),selectedIds:Array.from(h.selectedIds),expandedIds:Array.from(h.expandedIds),flatVisibleIds:h.flatVisibleIds.slice()}},updateTask:(h,p)=>{this.store.dispatch({type:"UPDATE_TASK",taskId:h,changes:p})},addTask:h=>{this.store.dispatch({type:"ADD_TASK",task:h})},removeTask:h=>{this.store.dispatch({type:"REMOVE_TASK",taskId:h})},moveTask:(h,p,r)=>{this.store.dispatch({type:"TASK_MOVE",taskId:h,startDate:p,endDate:r})},addDependency:h=>{this.store.dispatch({type:"ADD_DEPENDENCY",dependency:h})},removeDependency:h=>{this.store.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:h})},setSelection:h=>{this.store.dispatch({type:"DESELECT_ALL"});for(const p of h)this.store.dispatch({type:"SELECT_TASK",taskId:p,multi:!0})},setZoom:h=>{this.store.dispatch({type:"SET_ZOOM",level:h})},scrubTo:h=>{this.store.dispatch({type:"SET_TIME_CURSOR",date:h?new Date(h):null})},history:()=>{const h=this.history;return h?{entries:h.entries().map(p=>({ts:p.ts,wallTs:p.wallTs,actionType:p.action.type,source:p.source,actor:p.actor})),annotations:h.annotations().slice(),lastWallTs:h.lastWallTs()}:null},appendAnnotation:(h,p,r)=>{const d=this.history;return d?(d.appendAnnotation({kind:h,taskId:p,payload:r}),!0):!1}},this.container=t,this.config=Ts(n),zi(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=Fe(s,i),u=mt(s),c={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new ns,this.store=new dn(c),this.layoutEngine=new rs,this.timeScale=this.createTimeScale(c),this.canvasRenderer=new Ai(this.timelinePanel),this.treeGrid=new Pi(this.gridPanel),this.scrollManager=new _i(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new fs,this.tooltipManager=new ms(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new Ni(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,d,f)=>{var w;p?this.tooltipManager.show(p,r,d,f):this.tooltipManager.hide();try{(w=n.onHover)==null||w.call(n,p,r,d,f)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){dt("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){dt("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(dt("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const u=ts(this.store.getState(),t);for(const c of u)this.store.dispatch(c);dt("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=ts(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,l=0;for(const u of n){let c=null;if(u.type==="UPDATE_TASK"?c=u.taskId:u.type==="ADD_TASK"?c=u.task.id:u.type==="REMOVE_TASK"&&(c=u.taskId),c&&typeof s=="number"){const h=this.lastAppliedTs.get(c);if(h!==void 0&&s<h){l++;continue}}this.store.dispatch(u),c&&typeof s=="number"&&this.lastAppliedTs.set(c,s),u.type==="UPDATE_TASK"?o++:u.type==="ADD_TASK"?i++:u.type==="REMOVE_TASK"&&a++}l>0&&dt("remote:dropped-stale",{kind:t.kind,count:l}),o+i+a>0&&dt("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getDisplayState(){const t=this.store.getState(),n=t.timeCursorDate;return!n||!this.replayProvider?t:this.replayProvider.snapshotAt(n)??t}registerReplayProvider(t){return this.replayProvider=t,()=>{this.replayProvider===t&&(this.replayProvider=null)}}setTimeCursor(t){this.store.dispatch({type:"SET_TIME_CURSOR",date:t})}getTimeCursor(){return this.store.getState().timeCursorDate??null}getState(){return this.store.getState()}hitTestAt(t,n){const s=this.rootEl.getBoundingClientRect();if(!(t>=s.left&&t<=s.right&&n>=s.top&&n<=s.bottom))return{zone:"outside"};const i=this.getDisplayState(),{config:a,scrollX:l,scrollY:u,flatVisibleIds:c,tasks:h}=i,{headerHeight:p,rowHeight:r}=a,d=this.gridPanel.getBoundingClientRect(),f=this.timelinePanel.getBoundingClientRect(),w=t>=d.left&&t<=d.right&&n>=d.top&&n<=d.bottom&&d.width>0,v=t>=f.left&&t<=f.right&&n>=f.top&&n<=f.bottom;if(v&&n-f.top<p){const S=t-f.left+l;let k;try{k=this.timeScale.xToDate(S)}catch{k=new Date}const D=n-f.top,E=(()=>{try{return this.timeScale.getHeaderRows()}catch{return[]}})(),C=Math.max(1,E.length),M=p/C,A=Math.min(C-1,Math.max(0,Math.floor(D/M))),R=Vi(i.zoomLevel,C,A);return{zone:"date-header",date:k,level:R}}const g=p,y=(v?n-f.top:n-d.top)-g;if(y<0)return{zone:"outside"};const b=Math.floor((y+u)/r),T=(S=>S<0||S>=c.length?null:h.get(c[S])??null)(b);if(v&&T){if(T.status==="group-header")return{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:b};const S=this.layouts.find(k=>k.taskId===T.id)??null;if(S){const k=t-f.left+l;if(k>=S.x&&k<=S.x+S.width){const C=k<=S.x+6?"left-edge":k>=S.x+S.width-6?"right-edge":"body";return{zone:"bar",task:T,rowIndex:b,barType:C}}}}if(w&&T)return T.status==="group-header"?{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:b}:{zone:"row-label",task:T,rowIndex:b};if(v){const S=t-f.left+l,k=n-f.top;try{const D=this.dependencyRenderer.hitTest(S,k,i,this.layouts,u,p);if(D)return{zone:"dependency",depId:D}}catch{}}if(b>=c.length){let S;try{S=this.timeScale.xToDate(t-f.left+l)}catch{S=new Date}return{zone:"below-rows",date:S}}if(v){let S;try{S=this.timeScale.xToDate(t-f.left+l)}catch{S=new Date}const k=Ki(i,b);return{zone:"canvas-empty",date:S,rowIndex:b,nearestTask:T,bucketId:k}}return{zone:"outside"}}capabilities(){const t=this;return{version:"0.187.0",pushRemoteEvent:typeof this.pushRemoteEvent=="function",timeCursor:!0,history:!!t.history,replayProvider:!!this.replayProvider,pluginsInstalled:this.plugins.map(n=>n.name).join(",")}}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.getDisplayState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const c=u.getContext("2d");c&&l.renderCanvas(c,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new is(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){const t=this,n={getState:()=>this.store.getState(),dispatch:s=>this.store.dispatch(s),on:(s,o)=>this.eventBus.on(s,o),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:s=>this.timeScale.dateToX(s),xToDate:s=>this.timeScale.xToDate(s),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const s=this.store.getState(),{tree:o,flatIds:i}=Fe(s.tasks,s.expandedIds);s.tree=o,s.flatVisibleIds.length=0;for(const a of i)s.flatVisibleIds.push(a)}};return n.__gantt=t,n}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new dn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function Vi(e,t,n){if(t===2){if(e==="day")return n===0?"month":"day";if(e==="week")return n===0?"month":"week";if(e==="month")return n===0?"year":"month";if(e==="quarter")return n===0?"year":"quarter"}return e}function Ki(e,t){if(t<0||t>=e.flatVisibleIds.length)return null;let n=e.tasks.get(e.flatVisibleIds[t]);for(;n;){if(n.status==="group-header")return n.groupId??n.id;if(!n.parentId)break;n=e.tasks.get(n.parentId)}const s=e.tasks.get(e.flatVisibleIds[t]);return(s==null?void 0:s.groupId)??null}function vs(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function ws(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of vs(a)){let u=s.get(l);u||(u=[],s.set(l,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const u of l)o.has(u)||(o.add(u),i.push(u))}return o}function ji(e,t){const n=ws(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const qi=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function pn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Zi(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function c(d){s.push(d),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const d=pn(n.getState()),f=s.pop();o.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const d=pn(n.getState()),f=o.pop();s.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(d){(d.ctrlKey||d.metaKey)&&(d.key==="z"||d.key==="Z")&&(d.shiftKey?(d.preventDefault(),p()):(d.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(d){n=d,u=d.on("render",()=>{if(l)return;const f=document.querySelector(".nimbus-gantt");f&&(l=f.parentElement??f,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(d,f){if(i){f(d);return}if(qi.has(d.type)&&n){const w=pn(n.getState());c(w),o=[]}f(d)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const wt=["day","week","month","quarter"];function Ji(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function mn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Qi(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=Ji(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c>0&&e.dispatch({type:"SELECT_TASK",taskId:l[c-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[c+1]})}break}case"ArrowRight":{if(u)if(mn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}break}case"ArrowLeft":{if(u)if(mn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}break}case"Enter":{if(!u)return;i.preventDefault();const c=a.tasks.get(u);if(c&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:c,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const c=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:c})}break}case"+":case"=":{i.preventDefault();const c=wt.indexOf(a.zoomLevel);c>0&&e.dispatch({type:"SET_ZOOM",level:wt[c-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const c=wt.indexOf(a.zoomLevel);c<wt.length-1&&e.dispatch({type:"SET_ZOOM",level:wt[c+1]});break}case" ":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA"||c.tagName==="BUTTON")return;mn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const Ss="#D4A017",ea="rgba(212, 160, 23, 0.25)",ta=[6,4],na=1,sa=2,oa=4,ks=8,Ds=10,Es=16,ia=6;function aa(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,c=s.filter(r=>r.isMilestone);if(c.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of c){const d=r.x,f=r.barY-a,w=r.barHeight,v=f+w/2,g=r.color===l.barDefaultColor?Ss:r.color||Ss;t.save(),t.beginPath(),t.strokeStyle=ea,t.lineWidth=na,t.setLineDash(ta),t.moveTo(d,h),t.lineTo(d,h+p),t.stroke(),t.setLineDash([]),t.restore();const y=(w-sa*2)/2;t.save(),t.beginPath(),t.moveTo(d,v-y),t.lineTo(d+y,v),t.lineTo(d,v+y),t.lineTo(d-y,v),t.closePath(),t.fillStyle=g,t.fill(),t.strokeStyle=Cs(g,.25),t.lineWidth=1,t.stroke(),t.restore();const b=d+y+oa,m=v-Es/2;if(t.save(),t.beginPath(),t.strokeStyle=Cs(g,.15),t.lineWidth=1.5,t.moveTo(b,m),t.lineTo(b,m+Es),t.stroke(),t.beginPath(),t.moveTo(b,m),t.lineTo(b+ks,m+Ds/2),t.lineTo(b,m+Ds),t.closePath(),t.fillStyle=g,t.fill(),t.restore(),r.label){const T=b+ks+ia,S=v;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,T,S),t.restore()}}t.restore()},destroy(){e=null}}}function Cs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const ra="rgba(100, 116, 139, 0.12)",la="rgba(100, 116, 139, 0.25)",Is="#334155",ca="rgba(100, 116, 139, 0.2)",da="#475569",ua=8,ga=6,ha=2,Ke=5,fa=12,pa=28,ma=8;function ya(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(h){const p=new Map,r=[];for(const d of h.flatVisibleIds){const f=h.tasks.get(d);if(f)if(f.groupId){let w=p.get(f.groupId);w||(w={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,w)),w.taskIds.push(d)}else r.push(d)}n=Array.from(p.values()),o=[],s=new Map;for(const d of r)o.push(d);for(const d of n){const f=o.length,w=`__group_header__${d.groupId}`;if(o.push(w),s.set(f,d),!d.collapsed)for(const v of d.taskIds)o.push(v)}}function c(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const d=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const w=f.getBoundingClientRect(),v=r.clientY-w.top,g=d.config.headerHeight;if(v<g)return;const y=v-g+d.scrollY,b=Math.floor(y/d.config.rowHeight),m=s.get(b);m&&(r.preventDefault(),r.stopPropagation(),c(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let d=!1;for(const f of r.tasks.values())if(f.groupId){d=!0;break}if(!d){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const f=new Set;for(const w of n)if(w.collapsed)for(const v of w.taskIds)f.add(v);if(f.size>0){const w=r.flatVisibleIds.filter(v=>!f.has(v));if(w.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const v of w)r.flatVisibleIds.push(v)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:d,scrollX:f,scrollY:w}=p,{theme:v}=d,g=d.headerHeight,y=d.rowHeight,b=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-g;h.save(),h.beginPath(),h.rect(0,g,b,m),h.clip();let T=0;const S=[];for(const k of p.flatVisibleIds){const D=p.tasks.get(k);D&&!D.groupId&&S.push(k)}T=S.length;for(const k of n){const D=g+T*y-w;if(D+y>=g&&D<g+m){h.fillStyle=ra,h.fillRect(0,D,b,y),h.beginPath(),h.strokeStyle=la,h.lineWidth=1,h.moveTo(0,Math.round(D+y)+.5),h.lineTo(b,Math.round(D+y)+.5),h.stroke();const E=fa,C=D+y/2;h.save(),h.beginPath(),h.fillStyle=Is,k.collapsed?(h.moveTo(E,C-Ke),h.lineTo(E+Ke,C),h.lineTo(E,C+Ke)):(h.moveTo(E-Ke/2,C-Ke/2),h.lineTo(E+Ke/2,C-Ke/2),h.lineTo(E,C+Ke/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${v.fontSize}px ${v.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=Is;const M=pa,A=D+y/2;h.fillText(k.groupName,M,A);const R=h.measureText(k.groupName).width;h.restore();const O=`${k.taskIds.length}`;h.save(),h.font=`${v.fontSize-1}px ${v.fontFamily}`;const P=h.measureText(O).width+ga*2,x=v.fontSize+ha*2,W=M+R+ma,K=A-x/2;h.beginPath();const q=ua;h.moveTo(W+q,K),h.lineTo(W+P-q,K),h.arcTo(W+P,K,W+P,K+q,q),h.lineTo(W+P,K+x-q),h.arcTo(W+P,K+x,W+P-q,K+x,q),h.lineTo(W+q,K+x),h.arcTo(W,K+x,W,K+x-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=ca,h.fill(),h.fillStyle=da,h.textBaseline="middle",h.textAlign="center",h.fillText(O,W+P/2,A),h.restore()}T+=1,k.collapsed||(T+=k.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const ut="__bucket_header__";function Ms(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Ta(e){return e.groupId??null}function ba(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function va(e){const t=[...e.buckets].sort((r,d)=>r.order-d.order),n=new Map;t.forEach((r,d)=>n.set(r.id,d));const s=e.getBucket??Ta,o=e.getBucketProgress??ba,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function c(r,d){l=t.map(f=>({config:f,taskIds:[],allTaskIds:[],collapsed:i.has(f.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const f of d){const w=r.tasks.get(f);if(!w)continue;const v=s(w);if(!v)continue;const g=n.get(v);g!==void 0&&l[g].taskIds.push(f)}for(const[f,w]of r.tasks){if(f.startsWith(ut))continue;const v=s(w);if(!v)continue;const g=n.get(v);g!==void 0&&l[g].allTaskIds.push(f)}for(const f of l){if(f.allTaskIds.length===0){f.progress=0,f.startDate=null,f.endDate=null,f.totalHours=0,f.totalLogged=0;continue}const w=[];let v=1/0,g=-1/0,y=0,b=0;for(const m of f.allTaskIds){const T=r.tasks.get(m);if(!T)continue;if(w.push(T),T.startDate){const k=yt(T.startDate).getTime();!isNaN(k)&&k<v&&(v=k)}if(T.endDate){const k=yt(T.endDate).getTime();!isNaN(k)&&k>g&&(g=k)}const S=T.metadata;typeof(S==null?void 0:S.hoursHigh)=="number"&&(y+=S.hoursHigh),typeof(S==null?void 0:S.hoursLogged)=="number"&&(b+=S.hoursLogged)}f.startDate=isFinite(v)?new Date(v):null,f.endDate=isFinite(g)?new Date(g):null,f.totalHours=y,f.totalLogged=b,f.progress=Math.max(0,Math.min(1,o(w)))}}function h(r){if(!r.startDate||!r.endDate)return null;const d=r.totalHours>0&&r.totalLogged>=r.totalHours,f=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),w=r.totalHours>0?`${r.totalHours}h (${f}% budget)`:`${r.allTaskIds.length} items`;return{id:`${ut}${r.config.id}`,name:w,startDate:Ms(r.startDate),endDate:Ms(r.endDate),progress:r.progress,color:d?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const d=a.getState();a.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...d)=>{const f=d[0];let w=null;typeof f=="string"?w=f:f&&typeof f=="object"&&"id"in f&&(w=String(f.id)),w&&w.startsWith(ut)&&p(w.substring(ut.length))}))},middleware(r,d){if(d(r),!a)return;const f=a.getState(),w=[];for(const y of f.tasks.keys())y.startsWith(ut)&&w.push(y);for(const y of w)f.tasks.delete(y);const v=f.flatVisibleIds.filter(y=>!y.startsWith(ut));let g=!1;for(const y of f.tasks.values())if(s(y)!=null){g=!0;break}if(!g){if(l=[],v.length!==f.flatVisibleIds.length){f.flatVisibleIds.length=0;for(const y of v)f.flatVisibleIds.push(y)}return}c(f,v);for(const y of l){if(y.allTaskIds.length===0)continue;const b=h(y);if(b){f.tasks.set(b.id,b);for(const m of y.allTaskIds){const T=f.tasks.get(m);T&&(T.parentId=b.id)}y.collapsed?f.expandedIds.delete(b.id):f.expandedIds.add(b.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const wa=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function Sa(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const As=864e5,ka=6,Da=2,Ea=2,Ca=.18,Ia=.4;function Ls(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function yn(e,t){return Math.round((t.getTime()-e.getTime())/As)}function gt(e,t){return new Date(e.getTime()+t*As)}function Tn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const M=E.lag||0;s.get(E.source).push({target:E.target,lag:M,depId:E.id}),o.get(E.target).push({source:E.source,lag:M,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[E,C]of e){const M=Ls(C.startDate),A=Ls(C.endDate);l.set(E,M),u.set(E,A),a.set(E,Math.max(yn(M,A),0))}const c=new Map,h=new Map,p=[],r=[],d=new Map(i);for(const E of n)d.get(E)===0&&(r.push(E),c.set(E,l.get(E)),h.set(E,u.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),c.get(E);const C=h.get(E);for(const M of s.get(E)){const{target:A,lag:R}=M,O=gt(C,R),$=c.get(A);(!$||O.getTime()>$.getTime())&&(c.set(A,O),h.set(A,gt(O,a.get(A))));const P=d.get(A)-1;d.set(A,P),P===0&&r.push(A)}}for(const E of n)c.has(E)||(c.set(E,l.get(E)),h.set(E,u.get(E)),p.push(E));let f=-1/0;for(const E of h.values())E.getTime()>f&&(f=E.getTime());const w=new Date(f);let v=1/0;for(const E of c.values())E.getTime()<v&&(v=E.getTime());const g=new Date(v),y=yn(g,w),b=new Map,m=new Map;for(const E of n)s.get(E).length===0&&(m.set(E,w),b.set(E,gt(w,-a.get(E))));for(let E=p.length-1;E>=0;E--){const C=p[E];if(!m.has(C)){let M=1/0;for(const A of s.get(C)){const R=b.get(A.target);if(R){const O=gt(R,-A.lag);O.getTime()<M&&(M=O.getTime())}}M===1/0?m.set(C,w):m.set(C,new Date(M)),b.set(C,gt(m.get(C),-a.get(C)))}}for(const E of n)m.has(E)||(m.set(E,w),b.set(E,gt(w,-a.get(E))));const T=.5,S=new Set,k=new Map;for(const E of n){const C=c.get(E),M=h.get(E),A=b.get(E),R=m.get(E),O=yn(C,A),$=Math.abs(O)<T;$&&S.add(E),k.set(E,{earlyStart:C,earlyFinish:M,lateStart:A,lateFinish:R,totalFloat:O,isCritical:$})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&S.has(E.source)&&S.has(E.target)&&D.add(E.id);return{criticalTaskIds:S,criticalDependencyIds:D,taskAnalysis:k,projectDuration:y}}function Ma(){let e,t=null,n=[];function s(){const o=e.getState();t=Tn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:c,barHeight:h}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,d=i.scrollY,f=u,w=e.getTimeScale(),v=new Map;for(const m of a)v.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const m of a){const T=t.taskAnalysis.get(m.taskId);if(!T||T.isCritical||T.totalFloat<=0)continue;const S=m.barY-d,k=h*Ia,D=m.x+m.width,C=w.dateToX(T.lateFinish)-D;C>1&&(o.fillStyle=m.color,o.globalAlpha=Ca,o.fillRect(D,S+h-k,C,k),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const T=m.x,S=m.barY-d,k=m.width,D=m.barHeight;if(!(S+D<f||S>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=ka;for(let E=0;E<Da;E++){o.strokeStyle=p,o.lineWidth=Ea,o.beginPath();const C=l.barBorderRadius,M=Math.min(C,k/2,D/2);o.moveTo(T+M,S),o.lineTo(T+k-M,S),o.arcTo(T+k,S,T+k,S+M,M),o.lineTo(T+k,S+D-M),o.arcTo(T+k,S+D,T+k-M,S+D,M),o.lineTo(T+M,S+D),o.arcTo(T,S+D,T,S+D-M,M),o.lineTo(T,S+M),o.arcTo(T,S,T+M,S,M),o.closePath(),o.stroke()}o.restore()}}const g=6,y=4,b=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const T=v.get(m.source),S=v.get(m.target);if(!T||!S)continue;const k=T.x+T.width,D=T.barY+T.barHeight/2-d,E=S.x,C=S.barY+S.barHeight/2-d;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=k+b,A=E-b;if(o.moveTo(k,D),A>=M)o.lineTo(M,D),o.lineTo(M,C),o.lineTo(E,C);else{const R=(D+C)/2;o.lineTo(M,D),o.lineTo(M,R),o.lineTo(A,R),o.lineTo(A,C),o.lineTo(E,C)}o.stroke(),o.beginPath(),o.moveTo(E,C),o.lineTo(E-g,C-y),o.lineTo(E-g,C+y),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Aa=864e5,La=.6,Rs=.25,Ra="#38A169",Pa="#E53E3E",_a="#A0AEC0",$a=10,Oa=4,je=16,Na=3;function Ht(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ha(e,t){return Math.round((t.getTime()-e.getTime())/Aa)}function xa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:Ht(s.startDate),end:Ht(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var w,v;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,c=o.scrollX,h=o.scrollY,p=l,r=n.getTimeScale(),d=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-c,0);const f=u*La;for(const g of i){if(g.isMilestone)continue;const y=t.get(g.taskId);if(!y)continue;const b=g.barY-h;if(b+u+f<p||b>s.canvas.height)continue;const m=r.dateToX(y.start),T=r.dateToX(y.end),S=Math.max(T-m,2),k=b+u+1;Ht(((w=o.tasks.get(g.taskId))==null?void 0:w.startDate)||"");const D=Ht(((v=o.tasks.get(g.taskId))==null?void 0:v.endDate)||""),E=Ha(y.end,D);let C;E<0?C=Ra:E>0?C=Pa:C=_a,s.save(),s.globalAlpha=Rs,s.fillStyle=C;const M=Math.min(d,S/2,f/2);if(s.beginPath(),s.moveTo(m+M,k),s.lineTo(m+S-M,k),s.arcTo(m+S,k,m+S,k+M,M),s.lineTo(m+S,k+f-M),s.arcTo(m+S,k+f,m+S-M,k+f,M),s.lineTo(m+M,k+f),s.arcTo(m,k+f,m,k+f-M,M),s.lineTo(m,k+M),s.arcTo(m,k,m+M,k,M),s.closePath(),s.fill(),s.globalAlpha=Rs*2,s.strokeStyle=C,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const A=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${$a}px ${a.fontFamily}`;const $=s.measureText(A).width+Oa*2,P=g.x+g.width+4,x=k+(f-je)/2;s.globalAlpha=.85,s.fillStyle=C;const W=Na;s.beginPath(),s.moveTo(P+W,x),s.lineTo(P+$-W,x),s.arcTo(P+$,x,P+$,x+W,W),s.lineTo(P+$,x+je-W),s.arcTo(P+$,x+je,P+$-W,x+je,W),s.lineTo(P+W,x+je),s.arcTo(P,x+je,P,x+je-W,W),s.lineTo(P,x+W),s.arcTo(P,x,P+W,x,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(A,P+$/2,x+je/2),s.restore()}}s.restore()},destroy(){}}}const Ps=5,Ba=5,Fa=.3,Ua=15;function Ya(){let e,t=null,n=0,s=0;const o=[];function i(c){const{rowHeight:h,headerHeight:p}=c.config,r=c.scrollY,d=c.flatVisibleIds.length,f=a(c),w=Math.floor(r/h),v=Math.ceil((r+f)/h);let g=Math.max(0,w-Ps),y=Math.min(d,v+Ps);if(Math.abs(s)>0){const m=Math.min(Ua,Math.ceil(Math.abs(s*Fa)/h));s>0?y=Math.min(d,y+m):g=Math.max(0,g-m)}const b=new Set;for(let m=g;m<y&&m<c.flatVisibleIds.length;m++)b.add(c.flatVisibleIds[m]);return{startRow:g,endRow:y,totalRows:d,visibleTaskIds:b}}function a(c){const p=c.flatVisibleIds.length*c.config.rowHeight-c.scrollY;return Math.min(800,Math.max(p,200))}function l(c){const h=performance.now();for(o.push({y:c,time:h});o.length>Ba;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],d=(r.time-p.time)/1e3;d>0&&(s=(r.y-p.y)/d)}n=c}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const c=e.getState();return(!t||c.scrollY!==n)&&(l(c.scrollY),t=i(c)),t},filterLayouts(c){const h=u.getVisibleRange();return h.totalRows===0?[]:c.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(c){return u.getVisibleRange().visibleTaskIds.has(c)},getContentHeight(){if(!e)return 0;const c=e.getState();return c.flatVisibleIds.length*c.config.rowHeight+c.config.headerHeight}};return{name:"VirtualScrollPlugin",install(c){e=c},middleware(c,h){if(h(c),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(c.type)&&(t=null,c.type==="SET_SCROLL"||c.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const Ue=864e5,bn=1,_s=2,$s=.5,Os=2,xt=8,Ns=6,Hs=2,Bt=1e4;function vn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function xs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function it(e){return Math.round(e)+.5}function Bs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Fs(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let c=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(c,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const d=p.align==="right"?c+r-8:p.align==="center"?c+r/2:c+8;e.fillText(p.header,d,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(c+r,0),e.lineTo(c+r,s),e.stroke(),c+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const d=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,d,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,d+l),e.lineTo(n,d+l),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const w of a){const v=w.width??120,g=Bs(r,w.field);e.save(),e.beginPath(),e.rect(f,d,v,l),e.clip(),e.textBaseline="middle";const y=w.tree?8:0;e.textAlign=w.align==="right"?"right":w.align==="center"?"center":"left";const b=w.align==="right"?f+v-8:w.align==="center"?f+v/2:f+8+y;e.fillText(g,b,d+l/2),e.restore(),f+=v}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Us(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,c=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,c,p),i.showWeekends){const{start:f,end:w}=t.dateRange,v=new Date(f);v.setUTCHours(0,0,0,0);const g=w.getTime();for(;v.getTime()<=g;){const y=v.getUTCDay();if(y===0||y===6){const b=o+s.dateToX(v),m=new Date(v.getTime()+Ue),T=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(b,l,T-b,h)}v.setTime(v.getTime()+Ue)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=$s;for(const f of r){const w=it(o+f);e.moveTo(w,l),e.lineTo(w,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+f*u,c,u));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:w,end:v}=t.dateRange;if(f.getTime()>=w.getTime()&&f.getTime()<=v.getTime()){const g=o+s.dateToX(f),y=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(g,l,y,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=_s,e.moveTo(it(g),l),e.lineTo(it(g),p),e.stroke()}}const d=a.barBorderRadius;for(const f of n){const w=o+f.x,v=f.barY,g=f.width,y=f.barHeight;if(f.isMilestone){const b=(y-Os*2)/2,m=v+y/2;e.beginPath(),e.moveTo(w,m-b),e.lineTo(w+b,m),e.lineTo(w,m+b),e.lineTo(w-b,m),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(wn(e,w,v,g,y,d),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const b=xs(f.color,.2);e.save(),e.beginPath(),wn(e,w,v,g,y,d),e.clip(),e.fillStyle=b,e.fillRect(w,v,f.progressWidth,y),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),wn(e,w,v,g,y,d),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Hs,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const b=e.measureText(f.label).width,m=v+y/2;b+xt*2<=g?(e.beginPath(),e.rect(w,v,g,y),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,w+xt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,w+g+Ns,m)),e.restore()}}Wa(e,t,n,a,o),Xa(e,s,i,a,o)}function Wa(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const c of n)i.set(c.taskId,c);const a=12,l=6,u=4;e.save();for(const c of t.dependencies.values()){const h=i.get(c.source),p=i.get(c.target);if(!h||!p)continue;const r=c.type||"FS",d=h.barY+h.barHeight/2,f=p.barY+p.barHeight/2;let w,v;const g=r==="FS"||r==="FF",y=r==="FS"||r==="SS";switch(r){case"FS":w=o+h.x+h.width,v=o+p.x;break;case"SS":w=o+h.x,v=o+p.x;break;case"FF":w=o+h.x+h.width,v=o+p.x+p.width;break;case"SF":w=o+h.x,v=o+p.x+p.width;break}const b=g?w+a:w-a,m=y?v-a:v+a,T=g?y?m>=b:v+a>=b:y?v-a<=b:m<=b;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(w,d),T)e.lineTo(b,d),e.lineTo(b,f),e.lineTo(v,f);else{const S=(d+f)/2;e.lineTo(b,d),e.lineTo(b,S),e.lineTo(m,S),e.lineTo(m,f),e.lineTo(v,f)}e.stroke(),e.beginPath(),y?(e.moveTo(v,f),e.lineTo(v-l,f-u),e.lineTo(v-l,f+u)):(e.moveTo(v,f),e.lineTo(v+l,f-u),e.lineTo(v+l,f+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function Xa(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let c=0;c<a.length;c++){const h=a[c],p=c*u;for(const r of h){const d=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=bn,e.moveTo(it(d+f),p),e.lineTo(it(d+f),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(d,p,f,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,d+f/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=bn,e.moveTo(o,it(i)),e.lineTo(o+t.getTotalWidth(),it(i)),e.stroke()}function wn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function St(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function za(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),c=s+u,h=e.flatVisibleIds.length*l,p=a+h,r=i.barBorderRadius,d=[];d.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${c}" height="${p}" viewBox="0 0 ${c} ${p}">`),d.push(`<style>text { font-family: ${St(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),d.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),d.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const m of o.columns){const T=m.width??120;d.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${St(m.header)}</text>`),d.push(`<line x1="${f+T}" y1="0" x2="${f+T}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=T}for(let m=0;m<e.flatVisibleIds.length;m++){const T=e.tasks.get(e.flatVisibleIds[m]);if(!T)continue;const S=a+m*l;m%2===1&&d.push(`<rect x="0" y="${S}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let k=0;for(const D of o.columns){const E=D.width??120,C=Bs(T,D.field),M=D.tree?8:0;d.push(`<text x="${k+8+M}" y="${S+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${C}]]></text>`),k+=E}d.push(`<line x1="0" y1="${S+l}" x2="${s}" y2="${S+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}d.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<line x1="0" y1="${a}" x2="${c}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const w=n.getHeaderRows(),v=w.length||2,g=a/v;for(let m=0;m<w.length;m++){const T=w[m],S=m*g;for(const k of T){const D=s+k.x+k.width/2,E=S+g/2,C=m===0?' font-weight="600"':"";d.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${C} fill="${i.timelineHeaderText}">${St(k.label)}</text>`),d.push(`<line x1="${s+k.x+k.width}" y1="${S}" x2="${s+k.x+k.width}" y2="${S+g}" stroke="${i.timelineGridColor}" stroke-width="${bn}" />`)}}const y=n.getGridLines();for(const m of y)d.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${$s}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&d.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:T}=e.dateRange,S=new Date(m);for(S.setUTCHours(0,0,0,0);S.getTime()<=T.getTime();){if(S.getUTCDay()===0||S.getUTCDay()===6){const k=s+n.dateToX(S),D=new Date(S.getTime()+Ue),E=s+n.dateToX(D);d.push(`<rect x="${k}" y="${a}" width="${E-k}" height="${h}" fill="${i.timelineWeekendBg}" />`)}S.setTime(S.getTime()+Ue)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:T,end:S}=e.dateRange;if(m.getTime()>=T.getTime()&&m.getTime()<=S.getTime()){const k=s+n.dateToX(m),D=n.getColumnWidth();d.push(`<rect x="${k}" y="${a}" width="${D}" height="${h}" fill="${i.todayBg}" />`),d.push(`<line x1="${k}" y1="${a}" x2="${k}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${_s}" />`)}}for(const m of t){const T=s+m.x,S=m.barY,k=m.width,D=m.barHeight;if(m.isMilestone){const E=(D-Os*2)/2,C=S+D/2;d.push(`<polygon points="${T},${C-E} ${T+E},${C} ${T},${C+E} ${T-E},${C}" fill="${m.color}" />`);continue}if(d.push(`<rect x="${T}" y="${S}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const E=xs(m.color,.2);d.push(`<clipPath id="clip-${m.taskId}"><rect x="${T}" y="${S}" width="${k}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),d.push(`<rect x="${T}" y="${S}" width="${m.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&d.push(`<rect x="${T}" y="${S}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Hs}" />`),m.label){const E=S+D/2;i.fontSize*.6*m.label.length+xt*2<=k?d.push(`<text x="${T+xt}" y="${E}" dominant-baseline="central" fill="${m.textColor}">${St(m.label)}</text>`):d.push(`<text x="${T+k+Ns}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${St(m.label)}</text>`)}}const b=new Map;for(const m of t)b.set(m.taskId,m);for(const m of e.dependencies.values()){const T=b.get(m.source),S=b.get(m.target);if(!T||!S)continue;const k=m.type||"FS",D=T.barY+T.barHeight/2,E=S.barY+S.barHeight/2;let C,M;const A=k==="FS"||k==="FF",R=k==="FS"||k==="SS";switch(k){case"FS":C=s+T.x+T.width,M=s+S.x;break;case"SS":C=s+T.x,M=s+S.x;break;case"FF":C=s+T.x+T.width,M=s+S.x+S.width;break;case"SF":C=s+T.x,M=s+S.x+S.width;break}const O=12,$=6,P=4,x=A?C+O:C-O,W=R?M-O:M+O,K=A?R?W>=x:M+O>=x:R?M-O<=x:W<=x;let q;if(K)q=`M${C},${D} L${x},${D} L${x},${E} L${M},${E}`;else{const F=(D+E)/2;q=`M${C},${D} L${x},${D} L${x},${F} L${W},${F} L${W},${E} L${M},${E}`}d.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),R?d.push(`<polygon points="${M},${E} ${M-$},${E-P} ${M-$},${E+P}" fill="${i.dependencyColor}" />`):d.push(`<polygon points="${M},${E} ${M+$},${E-P} ${M+$},${E+P}" fill="${i.dependencyColor}" />`)}return d.push("</svg>"),d.join(`
`)}function Ga(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:c,end:h}=l.dateRange,p=h.getTime()-c.getTime(),r=u.getColumnWidth(),d=l.zoomLevel;let f;switch(d){case"day":f=Math.round(p/Ue);break;case"week":f=Math.ceil(p/(Ue*7));break;case"month":{const v=c.getUTCFullYear(),g=c.getUTCMonth(),y=h.getUTCFullYear(),b=h.getUTCMonth();f=(y-v)*12+(b-g);break}case"quarter":{const v=c.getUTCFullYear(),g=Math.floor(c.getUTCMonth()/3),y=h.getUTCFullYear(),b=Math.floor(h.getUTCMonth()/3);f=(y-v)*4+(b-g);break}}const w=f*r;return{dateToX(v){return(v.getTime()-c.getTime())/p*w},getColumnWidth(){return r},getTotalWidth(){return w},getHeaderRows(){return ja(d,c,h,r,w)},getGridLines(){return this.getHeaderRows()[1].map(g=>g.x).filter(g=>g>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,d=l.flatVisibleIds.length*l.config.rowHeight,f=l.config.headerHeight+d,w=a??"gantt-export.png";if(r>Bt||f>Bt){o(l,c,u,h,r,f,w);return}const v=document.createElement("canvas");v.width=r,v.height=f;const g=v.getContext("2d");g&&(h>0&&Fs(g,l,h,f),Us(g,l,c,u,h),v.toBlob(y=>{y&&vn(y,w)},"image/png"))}function o(a,l,u,c,h,p,r){const d=Math.min(1,Bt/h,Bt/p),f=Math.ceil(h*d),w=Math.ceil(p*d),v=document.createElement("canvas");v.width=f,v.height=w;const g=v.getContext("2d");g&&(g.scale(d,d),c>0&&Fs(g,a,c,p),Us(g,a,l,u,c),v.toBlob(y=>{y&&vn(y,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=za(l,c,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});vn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const Ys=["January","February","March","April","May","June","July","August","September","October","November","December"],Ws=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Xs(e,t){return new Date(e.getTime()+t*Ue)}function Sn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Va(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ka(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function ja(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Ka(l,t,i,o);switch(e){case"day":{const l=[],u=[],c=Math.round(i/Ue);let h=new Date(t);for(let r=0;r<c;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Xs(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=Sn(p),d=a(p),f=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${Ys[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:d,width:f-d,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],c=Math.ceil(i/(Ue*7));for(let p=0;p<c;p++){const r=Xs(t,p*7);u.push({label:`${Ws[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=Sn(h),r=h.getTime()<t.getTime()?t:h,d=p.getTime()>n.getTime()?n:p;l.push({label:`${Ys[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(d)-a(r),date:new Date(r)}),h=p}return[l,u]}case"month":{const l=[],u=[],c=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),d=(p-c)*12+(r-h);let f=new Date(Date.UTC(c,h,1));for(let v=0;v<d;v++)u.push({label:Ws[f.getUTCMonth()],x:v*s,width:s,date:new Date(f)}),f=Sn(f);let w=new Date(Date.UTC(c,0,1));for(;w.getTime()<n.getTime();){const v=new Date(Date.UTC(w.getUTCFullYear()+1,0,1)),g=w.getTime()<t.getTime()?t:w,y=v.getTime()>n.getTime()?n:v;l.push({label:String(w.getUTCFullYear()),x:a(g),width:a(y)-a(g),date:new Date(g)}),w=v}return[l,u]}case"quarter":{const l=[],u=[],c=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),d=(p-c)*4+(r-h);let f=new Date(Date.UTC(c,h*3,1));for(let v=0;v<d;v++){const g=Math.floor(f.getUTCMonth()/3)+1;u.push({label:`Q${g}`,x:v*s,width:s,date:new Date(f)}),f=Va(f,3)}let w=new Date(Date.UTC(c,0,1));for(;w.getTime()<n.getTime();){const v=new Date(Date.UTC(w.getUTCFullYear()+1,0,1)),g=w.getTime()<t.getTime()?t:w,y=v.getTime()>n.getTime()?n:v;l.push({label:String(w.getUTCFullYear()),x:a(g),width:a(y)-a(g),date:new Date(g)}),w=v}return[l,u]}default:return[[],[]]}}const qa={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},kn="nimbus-gantt-dark-theme-transition";function Za(){if(typeof document>"u"||document.getElementById(kn))return;const e=document.createElement("style");e.id=kn,e.textContent=`
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
  `,document.head.appendChild(e)}function Ja(){if(typeof document>"u")return;const e=document.getElementById(kn);e&&e.remove()}function Qa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const d=n.getState();o={...d.config.theme};const f={...d.config.theme,...qa};Object.assign(d.config.theme,f),s=!0,p()}function c(){if(!n||!s||!o)return;const d=n.getState();Object.assign(d.config.theme,o),s=!1,p()}function h(){s?c():u()}function p(){if(!n)return;const d=n.getState();n.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}function r(d){d.matches?u():c()}return{name:"DarkThemePlugin",install(d){n=d,Za(),d.on("theme:toggle",()=>{h()}),d.on("theme:dark",()=>{u()}),d.on("theme:light",()=>{c()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=d.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const d=n.getState();Object.assign(d.config.theme,o)}Ja(),n=null,o=null,i=null,a=null,s=!1}}}const Re=864e5,er=[1,2,3,4,5],tr="rgba(128, 128, 128, 0.06)",nr="rgba(128, 128, 128, 0.04)",sr="#f87171",kt=4;function Dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function He(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function or(e){const t=new Set((e==null?void 0:e.workDays)??er),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const d=He(r);return t.has(d.getUTCDay())}function i(r){const d=Dt(r);return n.has(d)?!1:t.has(r.getUTCDay())}function a(r){let d=He(r);for(d=new Date(d.getTime()+Re);!i(d);)d=new Date(d.getTime()+Re);return Dt(d)}function l(r,d){if(d===0)return r;let f=He(r);const w=d>0?1:-1;let v=Math.abs(d);if(!i(f))for(f=new Date(f.getTime()+w*Re);!i(f);)f=new Date(f.getTime()+w*Re);for(;v>0;)f=new Date(f.getTime()+w*Re),i(f)&&v--;return Dt(f)}function u(r,d){const f=He(r),w=He(d);if(f.getTime()>w.getTime())return-u(d,r);let v=0,g=new Date(f.getTime());for(;g.getTime()<w.getTime();)i(g)&&v++,g=new Date(g.getTime()+Re);return v}function c(r,d="forward"){if(o(r))return r;let f=He(r);const w=d==="forward"?Re:-Re;for(let v=0;v<30;v++)if(f=new Date(f.getTime()+w),i(f))return Dt(f);return r}function h(r,d){if(r.type==="TASK_MOVE"){const f=c(r.startDate,"forward"),w=c(r.endDate,"backward"),v=He(w).getTime()<He(f).getTime()?f:w;d({...r,startDate:f,endDate:v});return}if(r.type==="TASK_RESIZE"){const f=c(r.startDate,"forward"),w=c(r.endDate,"backward"),v=He(w).getTime()<He(f).getTime()?f:w;d({...r,startDate:f,endDate:v});return}d(r)}function p(r,d,f){const{config:w}=d,v=w.headerHeight,g=d.flatVisibleIds.length*w.rowHeight,y=s==null?void 0:s.getTimeScale();if(!y||g===0)return;const{start:b,end:m}=d.dateRange,T=d.scrollX,S=d.scrollY;r.save();const k=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(k,0,0,k,0,0),r.beginPath(),r.rect(0,v,r.canvas.width/k,g),r.clip(),r.translate(-T,0);const D=new Date(b);D.setUTCHours(0,0,0,0);const E=m.getTime();for(y.getColumnWidth();D.getTime()<=E;){const C=Dt(D),M=n.has(C),A=!t.has(D.getUTCDay());if(M||A){const R=y.dateToX(D),O=new Date(D.getTime()+Re),P=y.dateToX(O)-R;if(r.fillStyle=tr,r.fillRect(R,v-S,P,g+S),A&&!M){r.save(),r.beginPath(),r.rect(R,v,P,g),r.clip(),r.strokeStyle=nr,r.lineWidth=1;const x=8,W=g;for(let K=-W;K<P+W;K+=x)r.beginPath(),r.moveTo(R+K,v),r.lineTo(R+K+W,v+W),r.stroke();r.restore()}}if(M){const R=y.dateToX(D),O=new Date(D.getTime()+Re),$=y.dateToX(O),P=(R+$)/2;r.save(),r.setTransform(k,0,0,k,0,0),r.translate(-T,0);const x=v-kt-3;r.beginPath(),r.moveTo(P,x-kt),r.lineTo(P+kt,x),r.lineTo(P,x+kt),r.lineTo(P-kt,x),r.closePath(),r.fillStyle=sr,r.fill(),r.restore()}D.setTime(D.getTime()+Re)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...d)=>{const f=d[0],w=d[1],v=d[2],g=l(f,w);v&&v(g)}),r.on("calendar:workDaysBetween",(...d)=>{const f=d[0],w=d[1],v=d[2],g=u(f,w);v&&v(g)}),r.on("calendar:isWorkDay",(...d)=>{const f=d[0],w=d[1],v=o(f);w&&w(v)}),r.on("calendar:nextWorkDay",(...d)=>{const f=d[0],w=d[1],v=a(f);w&&w(v)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function ir(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function ar(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function rr(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=ir(),a=[],l=Date.now();let u=null,c=null,h=!1,p=[];const r=[];function d(m,T){if(h)return;const S={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:T};a.push(S),o&&o(S)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function w(){c===null&&(c=setInterval(()=>{f()},s))}function v(){c!==null&&(clearInterval(c),c=null)}const g=ar(()=>{if(!u)return;const m=u.getState();d("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let y=0;function b(m,T){switch(m.type){case"SET_ZOOM":{const S=u?u.getState().zoomLevel:"unknown";T(m),d("gantt.zoom",{oldLevel:S,newLevel:m.level});return}case"TASK_MOVE":{const S=y>0?Date.now()-y:0;T(m),d("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:S}),y=0;return}case"TASK_RESIZE":{T(m),d("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{y=Date.now(),T(m);return}case"SELECT_TASK":{T(m),d("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{T(m),g();return}case"TOGGLE_EXPAND":{const S=u?u.getState().expandedIds.has(m.taskId):!1;T(m),d(S?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{T(m),d("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{T(m),d("gantt.collapse",{all:!0});return}default:T(m);return}}return{name:"TelemetryPlugin",install(m){u=m,w();const T=m.getState();d("gantt.init",{taskCount:T.tasks.size,dependencyCount:T.dependencies.size,zoomLevel:T.zoomLevel}),setTimeout(()=>{h||d("gantt.feature.used",{plugins:p})},0);const S=m.on("taskClick",(...k)=>{const D=k[0];D&&d("gantt.task.click",{taskId:D.id})});r.push(S)},middleware:b,destroy(){h=!0;const m=Date.now()-l;d("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),f(),v();for(const T of r)T();r.length=0,u=null}}}const zs=5,Dn=.15,En=.85,lr=2,Gs=30,Ye=["day","week","month","quarter"];function Vs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function cr(e,t,n){return Math.max(t,Math.min(n,e))}function dr(e){const t=cr((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,c=0,h=0,p=0,r=null,d=null,f=null,w=null,v=null,g=null,y=0,b=0,m=0,T=!1;function S($,P,x){m=$,y=P,b=x,T=!0,r===null&&(r=$)}function k(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(w=$=>{u||$.alpha==null||$.beta==null||$.gamma==null||S($.alpha,$.beta,$.gamma)},window.addEventListener("deviceorientation",w),!0)}function D(){w&&(window.removeEventListener("deviceorientation",w),w=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function C($){try{const P=JSON.parse($);P.type==="orientation"?S(P.alpha,P.beta,P.gamma):P.type==="gesture"&&M(P.gesture)}catch{}}function M($){if(!l)return;const P=l.getState();switch($){case"tap":{P.selectedIds.size===0&&P.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:P.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const x=Ye.indexOf(P.zoomLevel);x<Ye.length-1&&l.dispatch({type:"SET_ZOOM",level:Ye[x+1]});break}case"swipe-right":{const x=Ye.indexOf(P.zoomLevel);x>0&&l.dispatch({type:"SET_ZOOM",level:Ye[x-1]});break}}}function A(){if(u||typeof WebSocket>"u")return;const $=E();try{v=new WebSocket($),v.onmessage=P=>{typeof P.data=="string"&&C(P.data)},v.onclose=()=>{v=null,u||(g=setTimeout(A,3e3))},v.onerror=()=>{v&&v.close()}}catch{u||(g=setTimeout(A,3e3))}}function R(){g!==null&&(clearTimeout(g),g=null),v&&(v.onmessage=null,v.onclose=null,v.onerror=null,v.close(),v=null)}function O(){if(!(u||!l)){if(T){c=c*En+y*Dn,h=h*En+b*Dn,p=p*En+m*Dn;const $=l.getState(),P=lr*a;if(n){const x=Vs(h,zs);if(x!==0){const W=x*P,K=Math.max(0,$.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const x=Vs(c,zs);if(x!==0){const W=x*P,K=Math.max(0,$.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=Ye.indexOf($.zoomLevel);if(W>Gs&&K>0){const q=Ye[K-1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}else if(W<-Gs&&K<Ye.length-1){const q=Ye[K+1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}}}f=requestAnimationFrame(O)}}return{name:"MotionControlPlugin",install($){l=$,d=$.getState().zoomLevel,(!k()||i)&&A(),f=requestAnimationFrame(O)},destroy(){u=!0,f!==null&&(cancelAnimationFrame(f),f=null),D(),R(),l=null}}}const Et="http://schemas.microsoft.com/project",ur=8,Ks=4800,gr={0:"FF",1:"FS",2:"SF",3:"SS"},hr={FF:0,FS:1,SF:2,SS:3};function js(e){return e?e.substring(0,10):""}function qs(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(Et,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function fr(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function pr(e){return`PT${e*ur}H0M0S`}function Ct(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Cn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(Et,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let g=0;g<l.length;g++){const y=l[g],b=Ee(y,"UID"),m=Ee(y,"Name");b&&m&&i.set(b,m)}const u=new Map,c=o.getElementsByTagNameNS(Et,"Assignment"),h=c.length>0?c:o.getElementsByTagName("Assignment");for(let g=0;g<h.length;g++){const y=h[g],b=Ee(y,"TaskUID"),m=Ee(y,"ResourceUID");if(b&&m){const T=i.get(m);T&&u.set(b,T)}}const p=[],r=[],d=o.getElementsByTagNameNS(Et,"Task"),f=d.length>0?d:o.getElementsByTagName("Task"),w=[];let v=1;for(let g=0;g<f.length;g++){const y=f[g],b=Ee(y,"UID"),m=Ee(y,"Name"),T=Ee(y,"Start"),S=Ee(y,"Finish"),k=Ee(y,"PercentComplete"),D=Ee(y,"Summary")==="1",E=Ee(y,"Milestone")==="1",C=parseInt(Ee(y,"OutlineLevel")||"0",10);if(b==="0"&&!m)continue;const M=`msp-${b}`,A=js(T),R=js(S);if(!A&&!E)continue;let O;C>0&&w[C-1]&&(O=w[C-1]),w[C]=M,w.length=C+1;const $={id:M,name:m||`Task ${b}`,startDate:A||R,endDate:R||A,progress:k?parseInt(k,10)/100:0,isMilestone:E,parentId:O,sortOrder:g},P=u.get(b);P&&($.assignee=P),D&&($.metadata={...$.metadata,isSummary:!0}),p.push($);const x=y.getElementsByTagNameNS(Et,"PredecessorLink"),W=x.length>0?x:y.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],F=Ee(q,"PredecessorUID"),I=parseInt(Ee(q,"Type")||"1",10),N=Ee(q,"LinkLag"),L=N?parseInt(N,10):0;if(!F||F==="0")continue;const H={id:`msp-dep-${v++}`,source:`msp-${F}`,target:M,type:gr[I]??"FS",lag:L!==0?L/Ks:void 0};r.push(H)}}return{tasks:p,dependencies:r}}function In(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(b){let m=1,T=b;for(;T!=null&&T.parentId;)m++,T=e.tasks.get(T.parentId);return m}const c=new Map,h=new Map;for(const b of a){const m=b.parentId??"__root__",T=(c.get(m)??0)+1;if(c.set(m,T),!b.parentId)h.set(b.id,String(T));else{const S=h.get(b.parentId)??"0";h.set(b.id,`${S}.${T}`)}}const p=new Set;for(const b of a)b.parentId&&p.add(b.parentId);const r=new Map;a.forEach((b,m)=>{r.set(b.id,m+1)});const d=new Map;for(const b of l){const m=d.get(b.target)??[];m.push(b),d.set(b.target,m)}const f=new Set;for(const b of a)b.assignee&&f.add(b.assignee);const w=Array.from(f),v=new Map;w.forEach((b,m)=>{v.set(b,m+1)});const g=[];g.push('<?xml version="1.0" encoding="UTF-8"?>'),g.push('<Project xmlns="http://schemas.microsoft.com/project">'),g.push(`  <Name>${Ct(n)}</Name>`),g.push(`  <Author>${Ct(s)}</Author>`),g.push(`  <CreationDate>${o}</CreationDate>`),g.push("  <CalendarUID>1</CalendarUID>"),g.push("  <Calendars>"),g.push("    <Calendar>"),g.push("      <UID>1</UID>"),g.push(`      <Name>${Ct(i)}</Name>`),g.push("      <IsBaseCalendar>1</IsBaseCalendar>"),g.push("    </Calendar>"),g.push("  </Calendars>"),g.push("  <Tasks>");for(const b of a){const m=r.get(b.id)??0,T=u(b),S=h.get(b.id)??"1",k=p.has(b.id),D=b.isMilestone??!1,E=qs(b.startDate),C=qs(b.endDate),M=fr(E,C),A=pr(M),R=Math.round((b.progress??0)*100);g.push("    <Task>"),g.push(`      <UID>${m}</UID>`),g.push(`      <ID>${m}</ID>`),g.push(`      <Name>${Ct(b.name)}</Name>`),g.push(`      <Start>${b.startDate}T08:00:00</Start>`),g.push(`      <Finish>${b.endDate}T17:00:00</Finish>`),g.push(`      <Duration>${A}</Duration>`),g.push(`      <PercentComplete>${R}</PercentComplete>`),g.push(`      <Summary>${k?"1":"0"}</Summary>`),g.push(`      <Milestone>${D?"1":"0"}</Milestone>`),g.push(`      <OutlineLevel>${T}</OutlineLevel>`),g.push(`      <OutlineNumber>${S}</OutlineNumber>`);const O=d.get(b.id);if(O)for(const $ of O){const P=r.get($.source)??0;if(P===0)continue;const x=hr[$.type??"FS"]??1,W=Math.round(($.lag??0)*Ks);g.push("      <PredecessorLink>"),g.push(`        <PredecessorUID>${P}</PredecessorUID>`),g.push(`        <Type>${x}</Type>`),g.push(`        <LinkLag>${W}</LinkLag>`),g.push("      </PredecessorLink>")}g.push("    </Task>")}g.push("  </Tasks>"),g.push("  <Resources>");for(const b of w){const m=v.get(b)??0;g.push("    <Resource>"),g.push(`      <UID>${m}</UID>`),g.push(`      <Name>${Ct(b)}</Name>`),g.push("    </Resource>")}g.push("  </Resources>"),g.push("  <Assignments>");let y=1;for(const b of a){if(!b.assignee)continue;const m=r.get(b.id)??0,T=v.get(b.assignee)??0;m===0||T===0||(g.push("    <Assignment>"),g.push(`      <UID>${y++}</UID>`),g.push(`      <TaskUID>${m}</TaskUID>`),g.push(`      <ResourceUID>${T}</ResourceUID>`),g.push("    </Assignment>"))}return g.push("  </Assignments>"),g.push("</Project>"),g.join(`
`)}function mr(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var c;const u=(c=l.target)==null?void 0:c.result;if(!(!u||!e))try{const h=Cn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=Cn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),c=In(u,a);l&&l(c)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),c=In(u,a),h=new Blob([c],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const yr=[4,3],Tr=1.5,br=.5,vr=.06,wr=4,Sr=8,kr=.35,Dr=1,Zs=.2,It=6,Js=864e5;function xe(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Qs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Mn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function An(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Er(e){let t=0;for(const n of e){const s=xe(n.startDate).getTime(),o=xe(n.endDate).getTime();t+=Math.max(o-s,Js)}return t}function Cr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=xe(l.startDate).getTime(),h=xe(s.startDate).getTime()-u,p=i.segments.map(r=>{const d=new Date(xe(r.startDate).getTime()+h),f=new Date(xe(r.endDate).getTime()+h);return{startDate:Qs(d),endDate:Qs(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,c=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==c){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:c,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),d=c.barBorderRadius,f=h;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-l,0);for(const w of i){if(w.isMilestone)continue;const v=t.get(w.taskId);if(!v||v.segments.length===0)continue;const g=w.barY-u,y=w.barHeight,b=g+y/2;if(g+y<f||g>s.canvas.height)continue;const m=[];for(const C of v.segments){const M=r.dateToX(xe(C.startDate)),A=r.dateToX(xe(C.endDate)),R=Math.max(A-M,4);m.push({startX:M,endX:M+R,width:R})}s.save(),s.fillStyle=c.timelineBg,s.fillRect(w.x-1,g-1,w.width+2,y+2),s.restore();for(let C=0;C<m.length-1;C++){const M=m[C].endX,A=m[C+1].startX,R=A-M;if(!(R<=0)){s.save(),s.globalAlpha=vr,s.strokeStyle=w.color,s.lineWidth=wr,s.beginPath(),s.rect(M,g,R,y),s.clip();for(let O=M-y;O<A+y;O+=Sr)s.beginPath(),s.moveTo(O,g+y),s.lineTo(O+y,g),s.stroke();s.restore()}}for(let C=0;C<m.length-1;C++){const M=m[C].endX,A=m[C+1].startX;s.save(),s.globalAlpha=br,s.strokeStyle=Mn(w.color,Zs),s.lineWidth=Tr,s.setLineDash(yr),s.beginPath(),s.moveTo(M,b),s.lineTo(A,b),s.stroke(),s.setLineDash([]),s.restore()}const T=o.tasks.get(w.taskId),S=(T==null?void 0:T.progress)??0,k=Er(v.segments);let E=S*k;for(let C=0;C<m.length;C++){const M=m[C],A=Math.max(xe(v.segments[C].endDate).getTime()-xe(v.segments[C].startDate).getTime(),Js);if(s.save(),An(s,M.startX,g,M.width,y,d),s.fillStyle=w.color,s.fill(),s.strokeStyle=Mn(w.color,Zs),s.lineWidth=Dr,s.stroke(),s.restore(),E>0&&a.showProgress){const R=Math.min(E,A),O=R/A,$=M.width*O;s.save(),An(s,M.startX,g,M.width,y,d),s.clip(),s.globalAlpha=kr,s.fillStyle=Mn(w.color,.3),s.fillRect(M.startX,g,$,y),s.restore(),E-=R}}if(w.label){const C=m[0],M=m[m.length-1],A=M.endX-C.startX;s.save(),s.font=`${c.fontSize}px ${c.fontFamily}`;const O=s.measureText(w.label).width;s.textBaseline="middle",s.textAlign="left",O+It*2<=C.width?(s.fillStyle=w.textColor,An(s,C.startX,g,C.width,y,d),s.clip(),s.fillText(w.label,C.startX+It,b)):O+It<=A?(s.fillStyle=w.textColor,s.fillText(w.label,C.startX+It,b)):(s.fillStyle=c.gridTextColor,s.fillText(w.label,M.endX+It,b)),s.restore()}}s.restore()},destroy(){n=null}}}const Ln=864e5,eo=1e3,Ft=4,Ir=.6,Mr="#E53E3E",Ar="#48BB78",Lr="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ht(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Ut(e,t){return Math.round((t.getTime()-e.getTime())/Ln)}function to(e,t){return new Date(e.getTime()+t*Ln)}function qe(e,t){return ht(to(he(e),t))}function We(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ht(n)),o;for(;i.getTime()<s.getTime();)o.push(ht(i)),i.setTime(i.getTime()+Ln);return o}class Rn{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const c of s){const p=(i.get(c)??0)-o;p<=0?i.delete(c):i.set(c,p),(l=a.get(c))==null||l.delete(n),((u=a.get(c))==null?void 0:u.size)===0&&a.delete(c)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const c of s){let h=(a==null?void 0:a.get(c))??0;if((u=l==null?void 0:l.get(c))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Yt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Rr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const c=parseInt(l,10);isNaN(c)||(u=c)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function no(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function Pr(e,t,n,s,o){const i=new Map;for(const g of s)e.has(g.taskId)&&n.has(g.resourceId)&&(i.has(g.taskId)||i.set(g.taskId,[]),i.get(g.taskId).push({resourceId:g.resourceId,units:g.units||1}));const a=new Map,l=new Map;for(const g of e.keys())a.set(g,[]),l.set(g,[]);for(const g of t.values()){if((g.type||"FS")!=="FS"||!e.has(g.source)||!e.has(g.target))continue;const b=g.lag||0;a.get(g.source).push({target:g.target,lag:b}),l.get(g.target).push({source:g.source,lag:b})}const u=new Map;for(const[g,y]of e){const b=he(y.startDate),m=he(y.endDate);u.set(g,{taskId:g,startDate:y.startDate,endDate:y.endDate,duration:Math.max(Ut(b,m),0)})}const c=new Rn;function h(){c.clear();for(const[g,y]of u){const b=i.get(g);if(!b)continue;const m=We(y.startDate,y.endDate);for(const T of b)c.allocate(T.resourceId,g,m,T.units)}}function p(g,y){const b=u.get(g);if(!b)return new Set;const m=new Set,T=b.startDate;if(y===T||he(y).getTime()<he(T).getTime())return m;const S=i.get(g);if(S){const k=We(b.startDate,b.endDate);for(const D of S)c.deallocate(D.resourceId,g,k,D.units)}if(b.startDate=y,b.endDate=qe(y,b.duration),m.add(g),S){const k=We(b.startDate,b.endDate);for(const D of S)c.allocate(D.resourceId,g,k,D.units)}return m}function r(g){const y=new Set,b=u.get(g);if(!b)return y;const m=a.get(g)??[];for(const{target:T,lag:S}of m){const k=u.get(T);if(!k)continue;const D=qe(b.endDate,S);if(he(k.startDate).getTime()<he(D).getTime()){const E=p(T,D);for(const C of E){y.add(C);const M=r(C);for(const A of M)y.add(A)}}}return y}function d(g){const y=l.get(g)??[];let b=u.get(g).startDate;b=e.get(g).startDate;for(const{source:T,lag:S}of y){const k=u.get(T);if(!k)continue;const D=qe(k.endDate,S);he(D).getTime()>he(b).getTime()&&(b=D)}return b}h();for(let g=0;g<eo;g++){const y=Yt(c,n);if(y.length===0)break;let b=!1;const m=y[0],T=m.taskIds.map(S=>o.get(S)).filter(S=>S!==void 0).sort(no);if(!(T.length<2))for(let S=1;S<T.length;S++){const k=T[S],D=u.get(k.taskId);if(!D)continue;const E=u.get(T[0].taskId);if(!E)continue;const C=E.endDate,M=d(k.taskId),A=he(C).getTime()>he(M).getTime()?C:M;he(A).getTime()>he(D.startDate).getTime()&&(p(k.taskId,A),r(k.taskId),b=!0);const R=c.getLoad(m.resourceId,m.date),O=n.get(m.resourceId).maxUnits;if(R<=O)break}}const f=new Map;let w=0;for(const[g,y]of u){const b=e.get(g),m=Ut(he(b.startDate),he(y.startDate));m!==0&&(f.set(g,{startDate:y.startDate,endDate:y.endDate,delayDays:m}),w+=m)}const v=Yt(c,n);return{adjustedTasks:f,totalDelay:w,conflicts:v,resolved:v.length===0}}function _r(e,t,n,s,o){const i=new Map;for(const y of s)e.has(y.taskId)&&n.has(y.resourceId)&&(i.has(y.taskId)||i.set(y.taskId,[]),i.get(y.taskId).push({resourceId:y.resourceId,units:y.units||1}));const a=new Map;for(const y of e.keys())a.set(y,[]);for(const y of t.values())(y.type||"FS")==="FS"&&(!e.has(y.source)||!e.has(y.target)||a.get(y.target).push({source:y.source,lag:y.lag||0}));const l=Array.from(e.keys()).map(y=>o.get(y)).filter(y=>y!==void 0).sort(no),u=new Map,c=new Rn,h=new Set,p=new Map;for(const[y,b]of e)p.set(y,Math.max(Ut(he(b.startDate),he(b.endDate)),0));function r(y){let m=e.get(y).startDate;const T=a.get(y)??[];for(const{source:S,lag:k}of T){const D=u.get(S);if(!D)continue;const E=qe(D.endDate,k);he(E).getTime()>he(m).getTime()&&(m=E)}return m}function d(y,b,m){const T=i.get(y);if(!T||T.length===0)return b;let S=b;const k=365*5;for(let D=0;D<k;D++){const E=qe(S,m),C=We(S,E);let M=!0;for(const A of T){const R=n.get(A.resourceId);if(!R||R.maxUnits===0)continue;const O=R.calendar?new Set(R.calendar):null;if(O&&C.some(P=>O.has(P))){M=!1;break}if(!c.canFit(A.resourceId,y,C,A.units,R.maxUnits)){M=!1;break}}if(M)return S;S=qe(S,1)}return b}const f=new Set(l.map(y=>y.taskId));for(let y=0;y<eo&&f.size>0;y++){let b=!1;for(const m of l){if(!f.has(m.taskId)||!(a.get(m.taskId)??[]).every(R=>h.has(R.source)))continue;const k=m.taskId,D=p.get(k)??0,E=r(k),C=d(k,E,D),M=qe(C,D);u.set(k,{taskId:k,startDate:C,endDate:M,duration:D});const A=i.get(k);if(A){const R=We(C,M);for(const O of A)c.allocate(O.resourceId,k,R,O.units)}h.add(k),f.delete(k),b=!0}if(!b){for(const m of f){const T=e.get(m),S=p.get(m)??0;u.set(m,{taskId:m,startDate:T.startDate,endDate:T.endDate,duration:S});const k=i.get(m);if(k){const D=We(T.startDate,T.endDate);for(const E of k)c.allocate(E.resourceId,m,D,E.units)}h.add(m)}f.clear()}}const w=new Map;let v=0;for(const[y,b]of u){const m=e.get(y),T=Ut(he(m.startDate),he(b.startDate));T!==0&&(w.set(y,{startDate:b.startDate,endDate:b.endDate,delayDays:T}),v+=T)}const g=Yt(c,n);return{adjustedTasks:w,totalDelay:v,conflicts:g,resolved:g.length===0}}function $r(e,t,n,s){const o=[],i=We(n,qe(s,1)),a=i.length;for(const[l,u]of t){const c=new Map;let h=0,p=0;for(const f of i){const w=e.getLoad(l,f);c.set(f,w),h+=w,w>p&&(p=w)}const r=u.maxUnits===0?1:u.maxUnits,d=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:c,overallUtilization:Math.min(d,1),peakUtilization:p})}return o}function so(e,t,n,s){const o=new Rn,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const c=s.get(a),h=(c==null?void 0:c.startDate)??l.startDate,p=(c==null?void 0:c.endDate)??l.endDate,r=We(h,p);for(const d of u)o.allocate(d.resourceId,a,r,d.units)}return o}function Or(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function c(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:d,dependencies:f}=r;if(d.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const w=u(),v=Rr(d,w,n);s==="parallel"?i=_r(d,f,t,e.assignments,v):i=Pr(d,f,t,e.assignments,v);const g=h(d,i.adjustedTasks),y=so(d,t,e.assignments,i.adjustedTasks);return a=$r(y,t,g.start,g.end),i}function h(r,d){let f=1/0,w=-1/0;for(const[v,g]of r){const y=d.get(v),b=he((y==null?void 0:y.startDate)??g.startDate).getTime(),m=he((y==null?void 0:y.endDate)??g.endDate).getTime();b<f&&(f=b),m>w&&(w=m)}if(f===1/0){const v=ht(new Date);return{start:v,end:v}}return{start:ht(new Date(f)),end:ht(new Date(w))}}function p(r){const d=[];for(const f of e.assignments)f.taskId===r&&d.push(f.resourceId);return d}return{name:"ResourceLevelingPlugin",install(r){o=r,c(),l.push(r.on("resourceLeveling:run",(...d)=>{const f=d[0],w=c();f&&f(w)})),l.push(r.on("resourceLeveling:result",(...d)=>{const f=d[0];f&&f(i)})),l.push(r.on("resourceLeveling:utilization",(...d)=>{const f=d[0];f&&f(a)})),l.push(r.on("resourceLeveling:conflicts",(...d)=>{const f=d[0];if(!f)return;const w=r.getState(),v=so(w.tasks,t,e.assignments,new Map);f(Yt(v,t))}))},middleware(r,d){d(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&c()},renderCanvas(r,d,f){if(!i||a.length===0)return;const{config:w}=d,{headerHeight:v,rowHeight:g}=w,y=d.scrollX,b=d.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,v,r.canvas.width,r.canvas.height-v),r.clip(),r.translate(-y,0);const T=new Map;for(const S of a)T.set(S.resourceId,S);for(const S of f){const k=p(S.taskId);if(k.length===0)continue;const D=T.get(k[0]);if(!D)continue;const E=t.get(k[0]);if(!E)continue;const C=E.maxUnits===0?1:E.maxUnits,A=S.barY+S.barHeight-b+1;if(A+Ft<v||A>r.canvas.height)continue;const R=d.tasks.get(S.taskId);if(!R)continue;const O=i.adjustedTasks.get(S.taskId),$=(O==null?void 0:O.startDate)??R.startDate,P=(O==null?void 0:O.endDate)??R.endDate,x=m.dateToX(he($)),K=m.dateToX(he(P))-x;if(K<2)continue;r.fillStyle=Lr,r.fillRect(x,A,K,Ft);const q=We($,P);for(const F of q){const I=D.dailyLoad.get(F)??0;if(I===0)continue;const N=m.dateToX(he(F)),H=m.dateToX(to(he(F),1))-N,ee=Math.min(I/C,2)/2*Ft,Z=I>C;r.globalAlpha=Ir,r.fillStyle=Z?Mr:Ar,r.fillRect(N,A+Ft-ee,H,ee),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const oo=864e5;function ye(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ze(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function io(e,t){return Math.round((ye(t).getTime()-ye(e).getTime())/oo)}function ao(e,t){return Ze(new Date(ye(e).getTime()+t*oo))}function ro(){return{addDays:ao,daysBetween:io}}function Pn(e,t,...n){try{const s=e;if(typeof s.emit=="function")return s.emit(t,...n),!0}catch{}return!1}function lo(e,t){const n=new Map,s=new Map,o=new Map;for(const c of e)n.set(c,[]),s.set(c,[]),o.set(c,0);for(const c of t.values()){if(!e.has(c.source)||!e.has(c.target))continue;const h={source:c.source,target:c.target,type:c.type||"FS",lag:c.lag||0,depId:c.id};n.get(c.source).push(h),s.get(c.target).push(h),o.set(c.target,(o.get(c.target)||0)+1)}const i=new Map(o),a=[],l=[];for(const c of e)i.get(c)===0&&a.push(c);for(;a.length>0;){const c=a.shift();l.push(c);for(const h of n.get(c)){const p=i.get(h.target)-1;i.set(h.target,p),p===0&&a.push(h.target)}}const u=new Set;for(const c of e)l.includes(c)||u.add(c);return{successors:n,predecessors:s,inDegree:o,circularTaskIds:u,topoOrder:l}}function co(e,t,n,s){const o=new Set(e.keys()),i=[],a=new Map;if(o.size===0)return{scheduledTasks:a,violations:i,projectStart:n.projectStart||Ze(new Date),projectEnd:n.projectStart||Ze(new Date),totalDuration:0};const l=n.constraints||new Map,u=lo(o,t);for(const b of u.circularTaskIds){const m=e.get(b);i.push({taskId:b,type:"circular",message:`Task "${(m==null?void 0:m.name)||b}" is part of a circular dependency chain`})}const c=new Map;for(const[b,m]of e){const T=s.daysBetween(m.startDate,m.endDate);c.set(b,Math.max(T,0))}let h;if(n.projectStart)h=n.projectStart;else{let b=1/0;for(const m of e.values()){const T=ye(m.startDate).getTime();T<b&&(b=T)}h=Ze(new Date(b))}const p=new Map,r=new Map,d=new Set;for(const[b,m]of e)p.set(b,m.startDate),r.set(b,m.endDate);for(const b of u.topoOrder){const m=e.get(b),T=c.get(b),S=l.get(b),k=u.predecessors.get(b);let D;if(k.length===0)D=h;else{let C=h;for(const M of k){const A=p.get(M.source),R=r.get(M.source);let O;switch(M.type){case"FS":O=s.addDays(R,M.lag);break;case"SS":O=s.addDays(A,M.lag);break;case"FF":{const $=s.addDays(R,M.lag);O=s.addDays($,-T);break}case"SF":{const $=s.addDays(A,M.lag);O=s.addDays($,-T);break}default:O=s.addDays(R,M.lag)}ye(O).getTime()>ye(C).getTime()&&(C=O)}D=C}if(S)switch(S.type){case"ASAP":break;case"ALAP":d.add(b);break;case"SNET":S.date&&ye(D).getTime()<ye(S.date).getTime()&&(D=S.date);break;case"SNLT":S.date&&ye(D).getTime()>ye(S.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" cannot start by ${S.date} (earliest possible: ${D}). SNLT constraint violated.`});break;case"MSO":S.date&&(ye(D).getTime()>ye(S.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" has MSO constraint ${S.date} but dependencies require start no earlier than ${D}.`}),D=S.date);break;case"FNET":{if(S.date){const C=s.addDays(S.date,-T);ye(D).getTime()<ye(C).getTime()&&(D=C)}break}case"FNLT":{if(S.date){const C=s.addDays(D,T);ye(C).getTime()>ye(S.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" cannot finish by ${S.date} (earliest finish: ${C}). FNLT constraint violated.`})}break}case"MFO":if(S.date){const C=s.addDays(S.date,-T);ye(D).getTime()>ye(C).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" has MFO constraint ${S.date} but dependencies require start no earlier than ${D} (finish would be ${s.addDays(D,T)}).`}),D=C}break}const E=s.addDays(D,T);p.set(b,D),r.set(b,E)}if(d.size>0){let b=-1/0;for(const T of r.values()){const S=ye(T).getTime();S>b&&(b=S)}const m=Ze(new Date(b));for(let T=u.topoOrder.length-1;T>=0;T--){const S=u.topoOrder[T];if(!d.has(S))continue;const k=c.get(S),D=u.successors.get(S);let E;if(D.length===0)E=s.addDays(m,-k);else{let M=1/0;for(const A of D){const R=p.get(A.target);let O;switch(A.type){case"FS":O=s.addDays(R,-A.lag);break;case"SS":O=s.addDays(s.addDays(R,-A.lag),k);break;case"FF":O=s.addDays(r.get(A.target),-A.lag);break;case"SF":O=s.addDays(s.addDays(r.get(A.target),-A.lag),k);break;default:O=s.addDays(R,-A.lag)}const $=s.addDays(O,-k),P=ye($).getTime();P<M&&(M=P)}E=Ze(new Date(M))}const C=p.get(S);ye(E).getTime()<ye(C).getTime()&&(E=C),p.set(S,E),r.set(S,s.addDays(E,k))}}for(const b of o)a.set(b,{startDate:p.get(b),endDate:r.get(b)});let f=1/0,w=-1/0;for(const{startDate:b,endDate:m}of a.values()){const T=ye(b).getTime(),S=ye(m).getTime();T<f&&(f=T),S>w&&(w=S)}const v=Ze(new Date(f)),g=Ze(new Date(w)),y=s.daysBetween(v,g);return{scheduledTasks:a,violations:i,projectStart:v,projectEnd:g,totalDuration:y}}function Nr(e){const t={respectWorkCalendar:!1,...e};let n,s,o=null,i=[];function a(){if(!t.respectWorkCalendar){s=ro();return}let c=null;Pn(n,"calendar:addWorkDays","2026-01-05",1,h=>{c=h}),c!==null?s={addDays(h,p){let r=ao(h,p);return Pn(n,"calendar:addWorkDays",h,p,d=>{r=d}),r},daysBetween(h,p){let r=io(h,p);return Pn(n,"calendar:workDaysBetween",h,p,d=>{r=d}),r}}:s=ro()}function l(){const c=n.getState(),h=co(c.tasks,c.dependencies,t,s);o=h;for(const[p,r]of h.scheduledTasks){const d=c.tasks.get(p);d&&(d.startDate!==r.startDate||d.endDate!==r.endDate)&&n.dispatch({type:"TASK_MOVE",taskId:p,startDate:r.startDate,endDate:r.endDate})}return h}function u(c,h){h(c),(c.type==="ADD_DEPENDENCY"||c.type==="REMOVE_DEPENDENCY")&&l()}return{name:"AutoSchedulePlugin",install(c){n=c,a(),i.push(n.on("autoSchedule:run",(...h)=>{const p=h[0],r=l();p&&p(r)})),i.push(n.on("autoSchedule:result",(...h)=>{const p=h[0];p&&p(o)})),i.push(n.on("autoSchedule:setConstraint",(...h)=>{const p=h[0],r=h[1];t.constraints||(t.constraints=new Map),r?t.constraints.set(p,r):t.constraints.delete(p)})),i.push(n.on("autoSchedule:setConstraints",(...h)=>{const p=h[0];t.constraints=p}))},middleware:u,destroy(){for(const c of i)c();i=[],o=null}}}const Hr=864e5,xr=75,Br=50,uo=25,Wt=.3,Xt=.25,go=.2,_n=.15,zt=.1,Fr=.3,ho=.5,Ur=20,fo=40,Yr=3,Wr=5,Xr=30,po=.25,mo=4,zr=2,Gr=5,$n=5,yo=4,To=.4,Vr=.003,Je=260,ft=260,bo=16,Xe=14,Kr="rgba(30, 30, 46, 0.92)",On="#e0e0e0",jr=10,Gt=32,qr=6,Vt="#EF4444",Kt="#F97316",jt="#EAB308",qt="#22C55E";function Se(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ie(e,t){return Math.round((t.getTime()-e.getTime())/Hr)}function Ce(e,t,n){return Math.max(t,Math.min(n,e))}function Zr(e){return e>=xr?"critical":e>=Br?"high":e>=uo?"medium":"low"}function Jr(e){switch(e){case"critical":return Vt;case"high":return Kt;case"medium":return jt;case"low":return qt}}function Zt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Qr(e,t){const n=new Map,s=new Map;for(const g of e.keys())n.set(g,[]),s.set(g,[]);for(const g of t.values())!e.has(g.source)||!e.has(g.target)||(n.get(g.source).push(g.target),s.get(g.target).push(g.source));const o=new Map,i=new Set;function a(g){if(o.has(g))return o.get(g);if(i.has(g))return 0;i.add(g);let y=0;for(const b of n.get(g)||[])y+=1+a(b);return o.set(g,y),y}for(const g of e.keys())a(g);const l=new Map;for(const[g,y]of e){const b=Se(y.startDate),m=Se(y.endDate);l.set(g,Math.max(Ie(b,m),0))}const u=new Map,c=new Map,h=new Map;for(const g of e.keys())h.set(g,(s.get(g)||[]).length),u.set(g,l.get(g)||0),c.set(g,null);const p=[],r=new Map(h);for(const[g,y]of r)y===0&&p.push(g);for(;p.length>0;){const g=p.shift();for(const y of n.get(g)||[]){const b=u.get(g)+(l.get(y)||0);b>u.get(y)&&(u.set(y,b),c.set(y,g));const m=r.get(y)-1;r.set(y,m),m===0&&p.push(y)}}const d=new Set;let f=0,w=null;for(const[g,y]of u)y>f&&(f=y,w=g);let v=w;for(;v!==null;)d.add(v),v=c.get(v)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:d}}function el(e){const t=Zt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=Se(o.startDate),a=Se(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function tl(e,t,n){const s=[],o=Zt(),i=Se(e.startDate),a=Se(e.endDate),l=Math.max(Ie(i,a),1),u=Math.max(Ie(i,o),0),c=Math.max(Ie(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=Ie(a,o);p=Ce(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*Wt)})}else{const D=c/l;D<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*Wt)})):(p=Ce(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*Wt)}))}let d=0;const f=Ce(u/l,0,1),w=f-h;w>ho?(d=Ce(Math.round(w*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(w*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Xt)})):w>Fr?(d=Ce(Math.round(w*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(w*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Xt)})):w>.1&&(d=Ce(Math.round(w*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(d*Xt)}));let v=0;const g=t.downstreamCount.get(e.id)||0,y=t.criticalPathIds.has(e.id);if(g>0){v=Ce(Math.round(Math.log2(g+1)*20),0,70),y&&(v=Ce(Math.round(v*1.5),0,100));const D=y?" (on critical path)":"";s.push({type:"dependency-chain",description:`${g} downstream dependent${g===1?"":"s"}${D}`,impact:Math.round(v*go)})}let b=0;l>fo?(b=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(b*_n)})):l>Ur&&(b=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(b*_n)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*zt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>Wr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*zt)})):D.length>Yr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*zt)}))}const T=Ce(Math.round(p*Wt+d*Xt+v*go+b*_n+m*zt),0,100),S=Zr(T);let k;return r&&h===0?k="Task is overdue with no progress — escalate immediately":r?k="Task is past its deadline — review scope or extend timeline":w>ho?k="Task is significantly behind schedule — investigate blockers":l>fo&&h<po?k="Large task with little progress — consider splitting into smaller work items":(S==="high"||S==="critical")&&(k="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:S,riskScore:T,factors:s,suggestion:k}}function nl(e,t,n,s,o){const i=Zt();let a=0,l=0,u=0;for(const[y,b]of e){if(b.isCompleted||(b.progress??0)>=1)continue;l++;const m=Se(b.startDate),T=Se(b.endDate),S=Math.max(Ie(m,T),1),k=Math.max(Ie(m,i),0),D=Ce(k/S,0,1);(b.progress??0)>=D-.1&&a++;const C=t.get(y);C&&(C.riskLevel==="high"||C.riskLevel==="critical")&&u++}const c=l>0?a/l:1;let h=0;for(const y of n.criticalPathIds){const b=e.get(y);if(!b||b.isCompleted)continue;const m=Se(b.endDate);i.getTime()>m.getTime()&&(h+=Ie(m,i))}const p=[],r=[];for(const[y,b]of s.activeTasks)p.push(b.length),b.length>mo&&r.push(y);let d=100;if(p.length>1){const y=p.reduce((b,m)=>b+m,0)/p.length;if(y>0){const b=p.reduce((T,S)=>T+(S-y)**2,0)/p.length,m=Math.sqrt(b)/y;d=Ce(Math.round(100-m*50),0,100)}}let f=100;if(l>0){let y=0,b=0,m=0;for(const T of e.values()){if(T.isCompleted)continue;const S=Se(T.startDate),k=Se(T.endDate),D=Math.max(Ie(S,k),1),E=Math.max(Ie(S,i),0),C=Ce(E/D,0,2);y+=T.progress??0,b+=C,m++}if(m>0){const T=y/m,S=b/m;if(S>0){const k=T/S;f=Ce(Math.round(k*100),0,100)}}}const w=c*100,v=Ce(100-h*10,0,100);return{overallScore:Ce(Math.round(w*.25+v*.25+d*.25+f*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function sl(e,t,n,s){const o=[],i=Zt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const d=Se(r.endDate),f=Ie(d,i),w=r.progress??0;f>Gr&&w===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const d=Se(r.startDate),f=Se(r.endDate),w=Ie(d,f),v=r.progress??0;if(w>Xr&&v<po){const g=Math.ceil(w/15);o.push({type:"split",description:`"${r.name}" spans ${w} days — split into ${g} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>mo?l.push({assignee:p,taskIds:r}):r.length<zr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const d=r.filter(f=>!t.criticalPathIds.has(f));d.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:d,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const d=Se(r.endDate),f=Ie(i,d);if(f>=0&&f<=5){const w=s.get(p);w&&w.riskScore>=uo&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const c=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>Se(p.startDate).getTime()-Se(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const d of r)h.add(`${d}->${p}`);for(let p=0;p<c.length;p++)for(let r=p+1;r<c.length;r++){const d=c[p],f=c[r],w=Se(d.endDate),v=Se(f.startDate);if(w.getTime()<=v.getTime()&&!(h.has(`${d.id}->${f.id}`)||h.has(`${f.id}->${d.id}`))){const y=Ie(w,v);y>0&&o.push({type:"parallel",description:`"${d.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${y} days on the critical path`,taskIds:[d.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function ol(e,t,n,s,o,i,a){if(e.save(),i){const l=To+(1-To)*(.5+.5*Math.sin(a*Vr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function il(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,c=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?qt:i>=50?jt:i>=25?Kt:Vt;e.beginPath(),e.arc(t,n,s,a,c),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=On,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function al(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Vt,label:"Critical"},{count:o.high,color:Kt,label:"High"},{count:o.medium,color:jt,label:"Medium"},{count:o.low,color:qt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const c=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+c),e.closePath(),e.fillStyle=u.color,e.fill(),l+=c}}function rl(e,t,n,s,o){const i=t-Je-bo,a=n+bo;e.save(),e.beginPath();const l=jr;e.moveTo(i+l,a),e.lineTo(i+Je-l,a),e.arcTo(i+Je,a,i+Je,a+l,l),e.lineTo(i+Je,a+ft-l),e.arcTo(i+Je,a+ft,i+Je-l,a+ft,l),e.lineTo(i+l,a+ft),e.arcTo(i,a+ft,i,a+ft-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Kr,e.fill(),e.fillStyle=On,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Xe,a+Xe);const u=i+Xe+Gt+4,c=a+Xe+20+Gt+8;il(e,u,c,Gt,qr,s.overallScore);const h=24,p=i+Je-Xe-h-4,r=c;al(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const d=r+h+8,f=[{count:o.critical,color:Vt,label:"C"},{count:o.high,color:Kt,label:"H"},{count:o.medium,color:jt,label:"M"},{count:o.low,color:qt,label:"L"}],w=28,v=p-f.length*w/2+w/2;for(let m=0;m<f.length;m++){const T=f[m],S=v+m*w;e.fillStyle=T.color,e.fillText(`${T.label}:${T.count}`,S,d)}const g=c+Gt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Xe,g);const y=g+18;e.font="10px sans-serif",e.fillStyle=On,e.fillText("Recommendations:",i+Xe,y);const b=s.recommendations.slice(0,3);for(let m=0;m<b.length;m++){const T=b[m],S=y+14+m*16,k=T.type==="escalate"?"⚠":T.type==="split"?"✂":T.type==="reassign"?"⇄":T.type==="parallel"?"⇉":T.type==="add-buffer"?"⏱":"ℹ",D=34,E=T.description.length>D?T.description.substring(0,D-1)+"…":T.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${k} ${E}`,i+Xe,S)}b.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Xe,y+14)),e.restore()}function ll(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:c,dependencies:h}=u;if(c.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=Qr(c,h),r=el(c),d=new Map;for(const[f,w]of c)d.set(f,tl(w,p,r));n=d,o=sl(c,p,r,n),s=nl(c,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",c=>{typeof c=="function"&&c(n)})),t.push(e.on("risk:health",c=>{typeof c=="function"&&c(s)})),t.push(e.on("risk:recommendations",c=>{typeof c=="function"&&c(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,c){c(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,c,h){if(n.size===0)return;const{headerHeight:p}=c.config,r=c.scrollX,d=c.scrollY,f=p,w=Date.now()-a;u.save(),u.beginPath(),u.rect(0,f,u.canvas.width,u.canvas.height-f),u.clip(),u.translate(-r,0);for(const v of h){const g=n.get(v.taskId);if(!g||g.riskLevel==="low")continue;const y=v.x,b=v.barY-d,m=v.width,T=v.barHeight;if(b+T<f||b>u.canvas.height||y+m<0)continue;const S=y+m-$n-yo,k=b+$n+yo,D=Jr(g.riskLevel),E=g.riskLevel==="critical";ol(u,S,k,$n,D,E,w)}if(u.restore(),i){const v={critical:0,high:0,medium:0,low:0};for(const g of n.values())v[g.riskLevel]++;u.save(),rl(u,u.canvas.width,p,s,v),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Pe=160,Qe=80,Nn=8,cl=240,dl=160,ul=100,gl=200,Jt=8,vo=.1,wo=3,hl=.001,fl=500,pl=5,ml=864e5,yl={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function So(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Tl(e,t){return Math.round((t.getTime()-e.getTime())/ml)}function ko(e,t,n){return e+(t-e)*n}function Qt(e,t,n){return Math.max(t,Math.min(n,e))}function Hn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function bl(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const c of s.get(l)){const h=n.get(c),p=u+1;(h===void 0||p>h)&&n.set(c,p);const r=i.get(c)-1;i.set(c,r),r===0&&a.push(c)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function vl(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function wl(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<pl;a++){for(let l=1;l<e.length;l++){const u=e[l],c=new Map;for(const h of u){const p=o.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let l=e.length-2;l>=0;l--){const u=e[l],c=new Map;for(const h of u){const p=s.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function Sl(e,t){const n=new Map;if(t==="radial")return kl(e);const s=t==="lr",o=s?cl:dl,i=s?ul:gl;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],d=h+p*i;s?n.set(r,{x:a*o,y:d}):n.set(r,{x:d,y:a*o})}}return n}function kl(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function Mt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Dl(e,t){return e.color?e.color:e.status&&(t[e.status]||yl[e.status])||"#94A3B8"}function El(e){const t=So(e.startDate),n=So(e.endDate);return Math.max(Tl(t,n),0)}function Cl(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,c=new Map,h=[],p=null,r=0,d=0,f=1,w=!1,v=0,g=0,y=0,b=0,m=null,T=0,S=0,k=null,D=null,E=new Set,C=!1,M=0,A=0,R=0,O=0;function $(X,_){return{x:(X-r)/f,y:(_-d)/f}}function P(X,_){const{x:B,y:z}=$(X,_);for(const G of c.values()){const V=G.x,ne=G.y;if(B>=V&&B<=V+Pe&&z>=ne&&z<=ne+Qe)return G}return null}function x(){const X=e.getState(),{tasks:_,dependencies:B,config:z}=X;if(_.size===0){c=new Map,h=[];return}p=Tn(_,B);const G=bl(_,B),V=vl(G);wl(V,B,_);const ne=Sl(V,s);let oe=1/0,ae=-1/0,le=1/0,me=-1/0;for(const{x:ue,y:De}of ne.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Pe),le=Math.min(le,De),me=Math.max(me,De+Qe);const we=(oe+ae)/2,Me=(le+me)/2,Ae=c;c=new Map;for(const[ue,De]of _){const Le=ne.get(ue);if(!Le)continue;const Ve=Le.x-we,ot=Le.y-Me,Be=Ae.get(ue);c.set(ue,{id:ue,task:De,layer:G.get(ue)??0,orderInLayer:0,x:Be?Be.x:Ve,y:Be?Be.y:ot,targetX:Ve,targetY:ot,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let De=0;De<ue.length;De++){const Le=c.get(ue[De]);Le&&(Le.orderInLayer=De)}h=[];for(const ue of B.values())!_.has(ue.source)||!_.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const _=e.getState(),B=new Set;B.add(X);const z=new Map,G=new Map;for(const oe of _.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of _.dependencies.values())!_.tasks.has(oe.source)||!_.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])B.has(ae)||(B.add(ae),V.push(ae))}const ne=[X];for(;ne.length>0;){const oe=ne.shift();for(const ae of z.get(oe)||[])B.has(ae)||(B.add(ae),ne.push(ae))}return B}function K(){C&&cancelAnimationFrame(A),C=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,_=Qt(X/fl,0,1),B=1-Math.pow(1-_,3);let z=!1;for(const G of c.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),ne=Math.abs(G.y-G.targetY);V>.5||ne>.5?(G.x=ko(G.x,G.targetX,B),G.y=ko(G.y,G.targetY,B),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(F(),z&&_<1)A=requestAnimationFrame(q);else{C=!1;for(const G of c.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);F()}}function F(){if(!i||!o)return;const X=e.getState(),{config:_}=X,B=_.theme,z=_.colorMap,G=B.timelineBg==="#1A202C"||B.gridBg==="#1A202C"||B.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(B.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,R,O),i.save(),i.translate(r,d),i.scale(f,f);for(const V of h){const ne=c.get(V.sourceId),oe=c.get(V.targetId);if(!ne||!oe)continue;const ae=E.has(V.sourceId)&&E.has(V.targetId),le=k===V.sourceId||k===V.targetId,me=k!==null&&!le||D!==null&&!ae,we=ne.x+Pe,Me=ne.y+Qe/2,Ae=oe.x,ue=oe.y+Qe/2;i.save(),me?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=B.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const De=(we+Ae)/2;i.beginPath(),i.moveTo(we,Me),i.quadraticCurveTo(De,Me,(we+Ae)/2,(Me+ue)/2),i.quadraticCurveTo(De,ue,Ae,ue),i.stroke();const Le=Math.atan2(ue-(Me+ue)/2,Ae-De);i.beginPath(),i.moveTo(Ae,ue),i.lineTo(Ae-Jt*Math.cos(Le-Math.PI/6),ue-Jt*Math.sin(Le-Math.PI/6)),i.lineTo(Ae-Jt*Math.cos(Le+Math.PI/6),ue-Jt*Math.sin(Le+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Ve=V.dep.type||"FS",ot=V.dep.lag||0,Be=ot!==0?`${Ve} +${ot}d`:Ve!=="FS"?Ve:"";if(Be&&!me){const Rt=(we+Ae)/2,es=(Me+ue)/2-8;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Be,Rt,es)}i.restore()}for(const V of c.values()){const ne=k!==null&&k!==V.id&&!N(k,V.id)||D!==null&&!E.has(V.id),oe=k===V.id,ae=D===V.id,le=Dl(V.task,z),me=V.x,we=V.y;i.save(),ne&&(i.globalAlpha=.25),V.isCritical&&!ne&&(i.save(),i.shadowColor=B.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Mt(i,me,we,Pe,Qe,Nn),i.fillStyle="transparent",i.fill(),i.restore()),Mt(i,me,we,Pe,Qe,Nn),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=B.selectionColor||"#3182CE",i.lineWidth=2,Mt(i,me-2,we-2,Pe+4,Qe+4,Nn+2),i.stroke()),i.font=`600 12px ${B.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Me=Hn(i,V.task.name,Pe-20);i.fillText(Me,me+10,we+8);const Ae=we+26;i.beginPath(),i.arc(me+16,Ae+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(Hn(i,ue,Pe-40),me+24,Ae);const De=El(V.task),Le=De===1?"1 day":`${De} days`;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Le,me+10,we+42),V.task.assignee&&(i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(Hn(i,V.task.assignee,Pe/2-10),me+Pe-10,we+42));const Ve=V.task.progress??0,ot=we+Qe-6,Be=Pe-20,Rt=3;if(Mt(i,me+10,ot,Be,Rt,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),Ve>0){const es=Math.max(Rt,Be*Qt(Ve,0,1));Mt(i,me+10,ot,es,Rt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),I(G,B.fontFamily)}function I(X,_){if(!i)return;const B={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${_}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${B[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,R-12,12),i.restore()}function N(X,_){for(const B of h)if(B.sourceId===X&&B.targetId===_||B.sourceId===_&&B.targetId===X)return!0;return!1}function L(X){l=X;const _=X.querySelector(".ng-timeline-panel");if(!_)return;u=_.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",_.appendChild(o);const B=o.getContext("2d");B&&(i=B,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",Te),o.addEventListener("mouseup",Y),o.addEventListener("mouseleave",te),o.addEventListener("dblclick",j),o.addEventListener("wheel",Q,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",be))}function H(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(R=X.clientWidth,O=X.clientHeight,o.width=Math.round(R*a),o.height=Math.round(O*a),o.style.width=`${R}px`,o.style.height=`${O}px`)}function U(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),H(),Z(),x();for(const X of c.values())X.x=X.targetX,X.y=X.targetY;F()}}function ee(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),k=null,D=null,E=new Set)}function Z(){r=R/2,d=O/2,f=1}function re(X){if(!o)return{x:0,y:0};const _=o.getBoundingClientRect();return{x:X.clientX-_.left,y:X.clientY-_.top}}function ge(X){const{x:_,y:B}=re(X),z=P(_,B);z?(m=z,z.isDragging=!0,T=$(_,B).x-z.x,S=$(_,B).y-z.y,D=z.id,E=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),F()):(w=!0,v=_,g=B,y=r,b=d,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),F()))}function Te(X){if(!o)return;const{x:_,y:B}=re(X);if(m){const V=$(_,B);m.x=V.x-T,m.y=V.y-S,m.targetX=m.x,m.targetY=m.y,F();return}if(w){const V=_-v,ne=B-g;r=y+V,d=b+ne,F();return}const z=P(_,B),G=z?z.id:null;G!==k&&(k=G,o.style.cursor=k?"pointer":"default",F())}function Y(X){m&&(m.isDragging=!1,m=null),w=!1}function te(X){m&&(m.isDragging=!1,m=null),w=!1,k&&(k=null,F())}function j(X){const{x:_,y:B}=re(X),z=P(_,B);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function Q(X){if(X.preventDefault(),!o)return;const{x:_,y:B}=re(X),z=$(_,B),G=-X.deltaY*hl;f=Qt(f+G*f,vo,wo);const V=$(_,B);r+=(V.x-z.x)*f,d+=(V.y-z.y)*f,F()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const _=X.touches[0],B=o.getBoundingClientRect(),z=_.clientX-B.left,G=_.clientY-B.top,V=P(z,G);V?(m=V,V.isDragging=!0,T=$(z,G).x-V.x,S=$(z,G).y-V.y,D=V.id,E=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(w=!0,v=z,g=G,y=r,b=d),F()}else if(X.touches.length===2){w=!1,m&&(m.isDragging=!1,m=null);const _=X.touches[0],B=X.touches[1];se=Math.hypot(B.clientX-_.clientX,B.clientY-_.clientY),de=(_.clientX+B.clientX)/2,ie=(_.clientY+B.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const _=o.getBoundingClientRect();if(X.touches.length===1){const B=X.touches[0],z=B.clientX-_.left,G=B.clientY-_.top;if(m){const V=$(z,G);m.x=V.x-T,m.y=V.y-S,m.targetX=m.x,m.targetY=m.y,F()}else if(w){const V=z-v,ne=G-g;r=y+V,d=b+ne,F()}}else if(X.touches.length===2){const B=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-B.clientX,z.clientY-B.clientY),V=(B.clientX+z.clientX)/2,ne=(B.clientY+z.clientY)/2,oe=V-_.left,ae=ne-_.top;if(se>0){const le=G/se,me=$(oe,ae);f=Qt(f*le,vo,wo);const we=$(oe,ae);r+=(we.x-me.x)*f,d+=(we.y-me.y)*f}r+=V-de,d+=ne-ie,se=G,de=V,ie=ne,F()}}function be(X){m&&(m.isDragging=!1,m=null),w=!1,se=0}function ve(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",Te),o.removeEventListener("mouseup",Y),o.removeEventListener("mouseleave",te),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",Q),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",be),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),C&&(cancelAnimationFrame(A),C=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?ee():U()})),t.push(e.on("networkGraph:layout",(..._)=>{const B=_[0];B!==s&&(s=B,n&&(x(),K()))})),t.push(e.on("stateChange",()=>{n&&(x(),K())}))},renderDOM(X,_){o||L(X),n&&(H(),F())},destroy(){for(const X of t)X();t=[],ve(),c=new Map,h=[],p=null,n=!1}}}const Do=300,Eo="nimbus-gantt-config-panel",xn="nimbus-gantt-config-panel-styles",Co=300,Bn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],Il=`
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
    transition: opacity ${Co}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
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
`;function Ml(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(Eo);return e?JSON.parse(e):{}}catch{return{}}}function Al(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(Eo,JSON.stringify(e))}catch{}}function Io(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function en(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ll(){if(typeof document>"u"||document.getElementById(xn))return;const e=document.createElement("style");e.id=xn,e.textContent=Il,document.head.appendChild(e)}function Rl(){if(typeof document>"u")return;const e=document.getElementById(xn);e&&e.remove()}function tn(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const c=document.createElement("span");return c.className="ng-config-slider-value",c.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);c.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(u),a.appendChild(c),a}function At(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function nn(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=Mo(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function Mo(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function Pl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const k=e.getState();e.dispatch({type:"SET_SCROLL",x:k.scrollX,y:k.scrollY})}function c(k){Object.assign(t,k),Al(t)}function h(k,D,E){k[D]=E}function p(k,D){if(!e)return;const E=e.getState();h(E.config,k,D),c({[k]:D}),u()}function r(k,D){if(!e)return;const E=e.getState();h(E.config.theme,k,D),u()}function d(k){if(!e)return;const D=Bn.find(C=>C.name===k);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),c({themePreset:k}),u()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function w(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function v(k,D){var X;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?w():f()}),k.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",w),k.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",k.appendChild(o)),o.innerHTML="";const C=document.createElement("div");C.className="ng-config-panel-header",C.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",w),C.appendChild(M),o.appendChild(C);const A=g("Display Settings");A.appendChild(tn("Row height",24,60,E.rowHeight,2,_=>p("rowHeight",_))),A.appendChild(tn("Bar height",16,40,E.barHeight,2,_=>p("barHeight",_))),A.appendChild(tn("Grid width",0,500,E.gridWidth,10,_=>p("gridWidth",_))),A.appendChild(tn("Font size",10,16,E.theme.fontSize,1,_=>{h(D.config.theme,"fontSize",_),c({fontSize:_}),u()})),A.appendChild(At("Today marker",E.showToday,_=>{h(D.config,"showToday",_),c({showToday:_}),u()})),A.appendChild(At("Weekends",E.showWeekends,_=>{h(D.config,"showWeekends",_),c({showWeekends:_}),u()})),A.appendChild(At("Progress bars",E.showProgress,_=>{h(D.config,"showProgress",_),c({showProgress:_}),u()})),A.appendChild(At("Dependency arrows",a,_=>{a=_,c({showDependencies:_}),u()})),A.appendChild(At("Labels on bars",t.showBarLabels!==!1,_=>{c({showBarLabels:_}),u()})),o.appendChild(A);const R=g("Color Theme"),O=document.createElement("div");O.className="ng-config-row";const $=document.createElement("span");$.className="ng-config-label",$.textContent="Preset";const P=document.createElement("select");P.className="ng-config-select";const x=document.createElement("option");x.value="",x.textContent="Custom",P.appendChild(x);for(const _ of Bn){const B=document.createElement("option");B.value=_.name,B.textContent=_.name,t.themePreset===_.name&&(B.selected=!0),P.appendChild(B)}P.addEventListener("change",()=>{P.value&&d(P.value)}),O.appendChild($),O.appendChild(P),R.appendChild(O),R.appendChild(nn("Bar default",E.theme.barDefaultColor,_=>{r("barDefaultColor",_),c({customColors:{...t.customColors,barDefault:_}})})),R.appendChild(nn("Today line",E.theme.todayLineColor,_=>{r("todayLineColor",_),c({customColors:{...t.customColors,todayLine:_}})})),R.appendChild(nn("Grid lines",E.theme.timelineGridColor,_=>{r("timelineGridColor",_),c({customColors:{...t.customColors,gridLines:_}})})),R.appendChild(nn("Background",E.theme.timelineBg,_=>{r("timelineBg",_),c({customColors:{...t.customColors,background:_}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",R.appendChild(W);const K={...E.colorMap,...t.statusColorMap},q=document.createElement("div");function F(){q.innerHTML="";const _=Object.entries(K);for(const[z,G]of _){const V=document.createElement("div");V.className="ng-config-color-map-entry";const ne=document.createElement("input");ne.className="ng-config-color-map-status",ne.value=z,ne.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=Mo(G),oe.addEventListener("input",()=>{K[z]=oe.value,E.colorMap[z]=oe.value,c({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete E.colorMap[z],c({statusColorMap:{...K}}),F(),u()}),V.appendChild(ne),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const B=document.createElement("button");B.className="ng-config-color-map-add",B.textContent="+ Add status color",B.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",E.colorMap[z.trim()]="#3b82f6",c({statusColorMap:{...K}}),F(),u())}),q.appendChild(B)}F(),R.appendChild(q),o.appendChild(R);const I=g("Zoom & Time"),N=document.createElement("div");N.className="ng-config-row";const L=document.createElement("span");L.className="ng-config-label",L.textContent="Zoom";const H=document.createElement("div");H.className="ng-config-zoom-group";const U=["day","week","month","quarter"];for(const _ of U){const B=document.createElement("button");B.className="ng-config-zoom-btn"+(D.zoomLevel===_?" ng-active":""),B.textContent=_.charAt(0).toUpperCase()+_.slice(1),B.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:_}),c({zoomLevel:_}),H.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===B)))}),H.appendChild(B)}N.appendChild(L),N.appendChild(H),I.appendChild(N);const ee=document.createElement("div");ee.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=Io(D.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const _=en(re.value),B=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:_,end:B}),c({dateRangeStart:re.value})}),ee.appendChild(Z),ee.appendChild(re),I.appendChild(ee);const ge=document.createElement("div");ge.className="ng-config-row";const Te=document.createElement("span");Te.className="ng-config-label",Te.textContent="End date";const Y=document.createElement("input");Y.type="date",Y.className="ng-config-date-input",Y.value=Io(D.dateRange.end),Y.addEventListener("change",()=>{if(!e||!Y.value)return;const _=e.getState().dateRange.start,B=en(Y.value);e.dispatch({type:"SET_DATE_RANGE",start:_,end:B}),c({dateRangeEnd:Y.value})}),ge.appendChild(Te),ge.appendChild(Y),I.appendChild(ge);const te=document.createElement("div");te.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),te.appendChild(j),I.appendChild(te),o.appendChild(I);const Q=g("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),y("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>y("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&T(e.getState())}),se.appendChild(ce),Q.appendChild(se),o.appendChild(Q);const be=g("Plugin Toggles"),ve=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const _ of ve){const B=document.createElement("div");B.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=_.label;const G=((X=t.pluginToggles)==null?void 0:X[_.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const ne=document.createElement("div");ne.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",ne.appendChild(oe);let ae=G;ne.addEventListener("click",()=>{ae=!ae,ne.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const me={...t.pluginToggles,[_.key]:ae};c({pluginToggles:me}),y(_.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),B.appendChild(le),B.appendChild(ne),be.appendChild(B)}o.appendChild(be)}function g(k){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=k,D.appendChild(E),D}function y(k){e&&b.forEach(D=>D(k))}const b=[];function m(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],C=D.map($=>[$.id,`"${($.name||"").replace(/"/g,'""')}"`,$.startDate,$.endDate,String(Math.round(($.progress??0)*100))+"%",$.status||"",$.assignee||"",$.priority||"",$.groupName||""]),M=[E.join(","),...C.map($=>$.join(","))].join(`
`),A=new Blob([M],{type:"text/csv;charset=utf-8;"}),R=URL.createObjectURL(A),O=document.createElement("a");O.href=R,O.download="gantt-tasks.csv",document.body.appendChild(O),O.click(),document.body.removeChild(O),URL.revokeObjectURL(R)}function T(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],C=D.map(R=>[R.name,R.startDate,R.endDate,Math.round((R.progress??0)*100)+"%",R.status||"",R.assignee||""]),A=[E.join("	"),...C.map(R=>R.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(A).catch(()=>{})}function S(k){const D=t;if(D.rowHeight!==void 0&&h(k.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&h(k.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&h(k.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&h(k.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&h(k.config,"showToday",D.showToday),D.showWeekends!==void 0&&h(k.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&h(k.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=Bn.find(C=>C.name===D.themePreset);E&&Object.assign(k.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&h(k.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&h(k.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&h(k.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&h(k.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(k.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:en(D.dateRangeStart),end:en(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(k){e=k,Ll(),t=Ml();const D=k.on("render",()=>{D(),S(k.getState()),u()});l.push(D);const E=k.on("config:open",()=>f()),C=k.on("config:close",()=>w()),M=k.on("config:toggle",()=>{i?w():f()});l.push(E,C,M)},renderDOM(k,D){v(k,D)},destroy(){l.forEach(k=>k()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Rl(),e=null,i=!1}}}const Ao=864e5,Fn="nimbus-gantt-heatmap-styles",ke=28,_e=2,et=48,$e=160,_l=3,Lo="#1e1e2e",Ro="#166534",Po="#a16207",_o="#b91c1c",$l=`
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
`;function $o(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ol(e){return String(e.getUTCDate())}function Nl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Hl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Oo(e,t){return Math.round((t.getTime()-e.getTime())/Ao)}function No(e,t){return new Date(e.getTime()+t*Ao)}function pt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function xl(e,t){return e===0?Lo:e===1?Ro:e===2?Po:_o}function Bl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Fl(){if(typeof document>"u"||document.getElementById(Fn))return;const e=document.createElement("style");e.id=Fn,e.textContent=$l,document.head.appendChild(e)}function Ul(){if(typeof document>"u")return;const e=document.getElementById(Fn);e&&e.remove()}function Yl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Oo(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(No(o,h));const u=new Map;let c=0;for(const h of s)for(const p of l){const r=`${h}|${pt(p)}`;u.set(r,{assignee:h,date:p,dateKey:pt(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=$o(h.startDate),d=$o(h.endDate),f=Oo(r,d)+1;for(let w=0;w<f;w++){const v=No(r,w),g=`${p}|${pt(v)}`,y=u.get(g);y&&(y.tasks.push(h),y.count++,y.count>c&&(c=y.count))}}return{assignees:s,dates:l,cells:u,maxCount:c}}function Wl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&c(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&c(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function c(p){if(!t||!s)return;const r=Yl(p);let d=t.querySelector(".ng-heatmap-grid-wrapper");d||(d=document.createElement("div"),d.className="ng-heatmap-grid-wrapper",t.appendChild(d)),d.innerHTML="";const f=document.createElement("canvas"),w=$e+r.dates.length*(ke+_e),v=et+r.assignees.length*(ke+_e),g=window.devicePixelRatio||1;f.width=w*g,f.height=v*g,f.style.width=w+"px",f.style.height=v+"px",f.style.cursor="pointer";const y=f.getContext("2d");y.scale(g,g),y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle";let b="",m=$e;for(let T=0;T<r.dates.length;T++){const S=r.dates[T],k=Nl(S),D=$e+T*(ke+_e);if(k!==b){if(b&&T>0){const E=(m+D)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(b,E,12)}m=D,b=k}}if(b){const T=$e+r.dates.length*(ke+_e),S=(m+T)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(b,S,12)}y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let T=0;T<r.dates.length;T++){const S=r.dates[T],k=$e+T*(ke+_e)+ke/2,D=S.getUTCDay()===0||S.getUTCDay()===6;y.fillStyle=D?"#475569":"#64748b",y.fillText(Ol(S),k,32)}y.beginPath(),y.strokeStyle="#1e293b",y.lineWidth=1,y.moveTo(0,et-.5),y.lineTo(w,et-.5),y.stroke();for(let T=0;T<r.assignees.length;T++){const S=r.assignees[T],k=et+T*(ke+_e);y.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="left",y.textBaseline="middle",y.fillStyle="#cbd5e1",y.save(),y.beginPath(),y.rect(0,k,$e-8,ke),y.clip(),y.fillText(S,8,k+ke/2),y.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],C=`${S}|${pt(E)}`,M=r.cells.get(C),A=(M==null?void 0:M.count)??0,R=$e+D*(ke+_e),O=xl(A),$=Bl(A,r.maxCount);y.globalAlpha=$,y.fillStyle=O,h(y,R,k,ke,ke,_l),y.fill(),A>=2&&(y.globalAlpha=1,y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle",y.fillStyle="#fff",y.fillText(String(A),R+ke/2,k+ke/2)),y.globalAlpha=1}}d.appendChild(f),f.addEventListener("mousemove",T=>{if(!n)return;const S=f.getBoundingClientRect(),k=T.clientX-S.left,D=T.clientY-S.top,E=Math.floor((k-$e)/(ke+_e)),C=Math.floor((D-et)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<$e||D<et){n.classList.remove("ng-visible");return}const M=r.dates[E],A=r.assignees[C],R=`${A}|${pt(M)}`,O=r.cells.get(R);if(!O||O.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const $=document.createElement("div");$.className="ng-heatmap-tooltip-date",$.textContent=`${A} - ${Hl(M)}`,n.appendChild($);for(const W of O.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const P=T.clientX+12,x=T.clientY+12;n.style.left=P+"px",n.style.top=x+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",T=>{if(!e)return;const S=f.getBoundingClientRect(),k=T.clientX-S.left,D=T.clientY-S.top,E=Math.floor((k-$e)/(ke+_e)),C=Math.floor((D-et)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<$e||D<et)return;const M=r.dates[E],R=`${r.assignees[C]}|${pt(M)}`,O=r.cells.get(R);if(!(!O||O.count===0)){u();for(const $ of O.tasks)e.dispatch({type:"SELECT_TASK",taskId:$.id,multi:!0})}})}function h(p,r,d,f,w,v){p.beginPath(),p.moveTo(r+v,d),p.lineTo(r+f-v,d),p.quadraticCurveTo(r+f,d,r+f,d+v),p.lineTo(r+f,d+w-v),p.quadraticCurveTo(r+f,d+w,r+f-v,d+w),p.lineTo(r+v,d+w),p.quadraticCurveTo(r,d+w,r,d+w-v),p.lineTo(r,d+v),p.quadraticCurveTo(r,d,r+v,d),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Fl();const r=p.on("heatmap:toggle",()=>a()),d=p.on("heatmap:show",()=>l()),f=p.on("heatmap:hide",()=>u());i.push(r,d,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const d=document.createElement("div");d.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",d.appendChild(f);const w=document.createElement("div");w.className="ng-heatmap-legend";const v=[{color:Lo,label:"None"},{color:Ro,label:"1 task"},{color:Po,label:"2 tasks"},{color:_o,label:"3+ tasks"}];for(const y of v){const b=document.createElement("span");b.className="ng-heatmap-legend-swatch",b.style.background=y.color,w.appendChild(b);const m=document.createElement("span");m.textContent=y.label,w.appendChild(m)}d.appendChild(w);const g=document.createElement("button");g.className="ng-heatmap-close",g.textContent="Back to Gantt",g.addEventListener("click",u),d.appendChild(g),t.appendChild(d),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&c(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Ul(),e=null,s=!1,o=null}}}const tt=200,nt=80,Ho=12,xo=6,Xl="rgba(255, 255, 255, 0.95)",zl="#cbd5e1",Gl="rgba(59, 130, 246, 0.3)",Vl="rgba(59, 130, 246, 0.7)",Kl=1.5,jl=2,ql=1,Un="nimbus-gantt-minimap-styles",Zl=864e5,Jl=`
  .ng-minimap {
    position: absolute;
    bottom: ${Ho}px;
    right: ${Ho}px;
    width: ${tt}px;
    height: ${nt}px;
    z-index: 900;
    border-radius: ${xo}px;
    border: 1px solid ${zl};
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
    border-radius: ${xo}px;
  }
`;function Ql(){if(typeof document>"u"||document.getElementById(Un))return;const e=document.createElement("style");e.id=Un,e.textContent=Jl,document.head.appendChild(e)}function ec(){if(typeof document>"u")return;const e=document.getElementById(Un);e&&e.remove()}function tc(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,c=0,h=0,p=0,r=0;function d(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function w(){o=!1,t&&t.classList.add("ng-hidden")}function v(T,S){const k=T/l-p/2,D=S/u-r/2;return{x:Math.max(0,Math.min(k,c-p)),y:Math.max(0,Math.min(D,h-r))}}function g(T){if(!e||!n)return;T.preventDefault(),i=!0;const S=n.getBoundingClientRect(),k=T.clientX-S.left,D=T.clientY-S.top,E=v(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function y(T){if(!i||!e||!n)return;T.preventDefault();const S=n.getBoundingClientRect(),k=Math.max(0,Math.min(T.clientX-S.left,tt)),D=Math.max(0,Math.min(T.clientY-S.top,nt)),E=v(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function b(){i=!1}function m(T,S){if(!s||!n||!o)return;const k=window.devicePixelRatio||1;n.width=tt*k,n.height=nt*k,n.style.width=tt+"px",n.style.height=nt+"px",s.scale(k,k);const{config:D,scrollX:E,scrollY:C,dateRange:M}=T,A=e.getTimeScale(),R=Math.round((M.end.getTime()-M.start.getTime())/Zl),O=A.getColumnWidth();if(c=Math.max(R*O,1),h=Math.max(T.flatVisibleIds.length*D.rowHeight,1),p=c>0?Math.min(c,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const L=t.parentElement;p=L.clientWidth-D.gridWidth,r=L.clientHeight-D.headerHeight}l=tt/Math.max(c,1),u=nt/Math.max(h,1),s.fillStyle=Xl,s.fillRect(0,0,tt,nt);const $=new Map;for(const L of S)$.has(L.rowIndex)||$.set(L.rowIndex,[]),$.get(L.rowIndex).push(L);for(const L of S){const H=L.x*l,U=Math.max(L.width*l,1),ee=L.rowIndex*D.rowHeight*u;s.fillStyle=L.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(H,ee,U,Math.max(jl,D.rowHeight*u-ql))}s.globalAlpha=1;const P=E*l,x=C*u,W=p*l,K=r*u,q=Math.max(0,Math.min(P,tt-1)),F=Math.max(0,Math.min(x,nt-1)),I=Math.min(W,tt-q),N=Math.min(K,nt-F);s.fillStyle=Gl,s.fillRect(q,F,I,N),s.strokeStyle=Vl,s.lineWidth=Kl,s.strokeRect(q,F,I,N)}return{name:"MiniMapPlugin",install(T){e=T,Ql();const S=T.on("minimap:toggle",()=>d()),k=T.on("minimap:show",()=>f()),D=T.on("minimap:hide",()=>w());a.push(S,k,D),typeof document<"u"&&(document.addEventListener("mousemove",y),document.addEventListener("mouseup",b))},renderDOM(T,S){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",g),t.appendChild(n),T.appendChild(t));const k=(e==null?void 0:e.getLayouts())??[];m(S,k)},destroy(){a.forEach(T=>T()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",y),document.removeEventListener("mouseup",b)),t&&(t.remove(),t=null),n=null,s=null,ec(),e=null,o=!0,i=!1}}}const nc="#f59e0b",sc=[6,4],oc=1,at=16,ic=4,ac="rgba(15, 23, 42, 0.95)",rc="#e2e8f0",lc="#334155",cc=6,rt=10,Bo=220,Fo=12,Uo=13;function dc(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Lt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function uc(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Lt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function gc(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const c=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(h)*c,r=n+Math.sin(h)*c;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke()}function hc(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function fc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function pc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Yo={flag:uc,star:gc,warning:hc,info:fc,deadline:pc};function mc(e,t,n,s,o){e.save();const i=`${Fo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Uo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let c=0;if(t.description){const v=t.description.split(" ");let g="";for(const y of v){const b=g?g+" "+y:y;e.measureText(b).width>Bo-rt*2&&g?(u.push(g),c=Math.max(c,e.measureText(g).width),g=y):g=b}g&&(u.push(g),c=Math.max(c,e.measureText(g).width))}const h=Math.min(Bo,Math.max(l,c)+rt*2),p=Fo+4,r=Uo+4,d=rt*2+r+(u.length>0?4+u.length*p:0);let f=n-h/2;const w=s-d-8;if(f<4&&(f=4),f+h>o-4&&(f=o-h-4),e.beginPath(),yc(e,f,w,h,d,cc),e.fillStyle=ac,e.fill(),e.strokeStyle=lc,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=rc,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+rt,w+rt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let v=w+rt+r+4;for(const g of u)e.fillText(g,f+rt,v),v+=p}e.restore()}function yc(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Tc(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,c=null;function h(g){return n.find(y=>y.id===g)}function p(g){n.push(g),w()}function r(g){n=n.filter(y=>y.id!==g),w()}function d(g,y){const b=h(g);b&&(Object.assign(b,y),w())}function f(){return[...n]}function w(){if(!t)return;const g=t.getState();t.dispatch({type:"SET_SCROLL",x:g.scrollX,y:g.scrollY})}function v(g){const y=g.canvas;c!==y&&(c&&u&&c.removeEventListener("mousemove",u),c=y,u=b=>{const m=y.getBoundingClientRect();a=b.clientX-m.left,l=b.clientY-m.top;let T=null;for(const S of o){const k=a-S.x,D=l-S.y;if(Math.sqrt(k*k+D*D)<=S.size){T=S.note.id;break}}T!==s&&(s=T,y.style.cursor=s?"pointer":"",w())},y.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(g){t=g;const y=g.on("notes:add",(...S)=>{const k=S[0];k&&k.id&&k.date&&k.label&&p(k)}),b=g.on("notes:remove",(...S)=>{const k=S[0];k&&r(k)}),m=g.on("notes:update",(...S)=>{const k=S[0];if(k&&k.id){const{id:D,...E}=k;d(D,E)}}),T=g.on("notes:list",(...S)=>{const k=S[0];typeof k=="function"&&k(f())});i.push(y,b,m,T)},renderCanvas(g,y,b){if(!t||n.length===0)return;const{config:m,scrollX:T,scrollY:S,dateRange:k}=y,{theme:D}=m,E=m.headerHeight,C=t.getTimeScale();v(g);const M=g.canvas.width/(window.devicePixelRatio||1),A=g.canvas.height/(window.devicePixelRatio||1),R=E,O=A-R;o=[],g.save();for(const $ of n){const P=dc($.date);if(P<k.start||P>k.end)continue;const x=$.color||nc,W=$.icon||"flag",K=C.dateToX(P)-T;if(K<-at||K>M+at)continue;g.save(),g.beginPath(),g.setLineDash(sc),g.strokeStyle=x,g.globalAlpha=.5,g.lineWidth=oc,g.moveTo(K,R),g.lineTo(K,R+O),g.stroke(),g.setLineDash([]),g.globalAlpha=1,g.restore();const q=K,F=R+ic+at/2,I=Yo[W]||Yo.flag;g.save(),g.beginPath(),g.arc(q,F,at/2+3,0,Math.PI*2),g.fillStyle="rgba(0, 0, 0, 0.4)",g.fill(),g.restore(),g.save(),I(g,q,F,at,x),g.restore(),o.push({note:$,x:q,y:F,size:at/2+4}),s===$.id&&mc(g,$,q,F-at/2-4,M)}g.restore()},destroy(){i.forEach(g=>g()),i.length=0,c&&u&&c.removeEventListener("mousemove",u),t=null,c=null,u=null,s=null,o=[]}}}const bc=500,vc=40,Wo=7,Xo=3,zo=5,wc=500,Yn="nimbus-gantt-timetravel-styles",Go={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Sc=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${vc}px;
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
    width: ${Wo*2}px;
    height: ${Wo*2}px;
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
    width: ${Xo*2}px;
    height: ${Xo*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${zo*2}px;
    height: ${zo*2}px;
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
`;function kc(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Dc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Ec(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function Cc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function Ic(){if(typeof document>"u"||document.getElementById(Yn))return;const e=document.createElement("style");e.id=Yn,e.textContent=Sc,document.head.appendChild(e)}function Mc(){if(typeof document>"u")return;const e=document.getElementById(Yn);e&&e.remove()}const Vo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),sn=[.5,1,2,4];function Ac(e){const t=(e==null?void 0:e.maxSnapshots)??bc,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,c=1;const h=[];let p=null,r=null,d=null,f=null,w=null,v=null,g=null,y=!1;function b(F){if(!s||a)return;const I=s.getState(),N=Ec(I,F);i<o.length-1&&(o.length=i+1),o.push(N),o.length>t&&o.shift(),i=o.length-1}function m(F){if(!s||o.length===0)return;const I=Math.max(0,Math.min(F,o.length-1));i=I;const N=o[I];a=!0;const L=N.tasks.map(U=>({id:U.id,name:U.name,startDate:U.startDate,endDate:U.endDate,progress:U.progress,status:U.status})),H=N.dependencies.map(U=>({id:U.id,source:U.source,target:U.target}));s.dispatch({type:"SET_DATA",tasks:L,dependencies:H}),a=!1,R()}function T(){o.length>0&&m(o.length-1),k()}function S(){if(l||o.length<=1)return;l=!0;const F=sn[c],I=wc/F;u=setInterval(()=>{if(i>=o.length-1){k();return}m(i+1)},I),R()}function k(){l=!1,u!==null&&(clearInterval(u),u=null),R()}function D(){l?k():S()}function E(){c=(c+1)%sn.length,l&&(k(),S()),R()}function C(){k(),i>0&&m(i-1)}function M(){k(),i<o.length-1&&m(i+1)}function A(){k(),o.length=0,i=-1,a=!1,R()}function R(){if(p){if(f){const F=o.length,I=F>0?i+1:0;f.textContent=`${I} / ${F}`}w&&(w.textContent=l?"⏸":"▶",w.classList.toggle("ng-active",l)),v&&(v.textContent=`${sn[c]}x`),O(),$()}}function O(){if(!d||!r||o.length===0){d&&(d.style.display="none");return}d.style.display="block";const F=o.length<=1?50:i/(o.length-1)*100;d.style.left=`${F}%`}function $(){if(!g||!r||(g.innerHTML="",o.length===0))return;const F=200,I=o.length>F?Math.ceil(o.length/F):1;for(let N=0;N<o.length;N+=I){const L=o[N],H=o.length<=1?50:N/(o.length-1)*100,U=kc(L.action.split(" ")[0]==="Loaded"?"SET_DATA":P(L.action)),ee=Go[U]||Go.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${H}%`,Z.style.background=ee;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${L.action}
${Cc(L.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=N;Z.addEventListener("click",Te=>{Te.stopPropagation(),k(),m(ge)}),g.appendChild(Z)}}function P(F){return F.startsWith("Moved")?"TASK_MOVE":F.startsWith("Resized")?"TASK_RESIZE":F.startsWith("Added task")?"ADD_TASK":F.startsWith("Added dependency")?"ADD_DEPENDENCY":F.startsWith("Removed task")?"REMOVE_TASK":F.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":F.startsWith("Updated")?"UPDATE_TASK":(F.startsWith("Loaded"),"SET_DATA")}function x(F){if(!r||o.length<=1)return;const I=r.getBoundingClientRect(),N=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),L=Math.round(N*(o.length-1));k(),m(L)}function W(F){F.preventDefault(),F.stopPropagation(),y=!0,d&&d.classList.add("ng-dragging"),k()}function K(F){if(!y||!r||o.length<=1)return;const I=r.getBoundingClientRect(),N=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),L=Math.round(N*(o.length-1));m(L)}function q(){y&&(y=!1,d&&d.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(F){s=F,Ic(),h.push(F.on("timeTravel:record",()=>{s&&(s.getState(),b("Manual snapshot"))}),F.on("timeTravel:scrub",(...I)=>{const N=I[0];k(),m(N)}),F.on("timeTravel:play",()=>S()),F.on("timeTravel:pause",()=>k()),F.on("timeTravel:present",()=>T()),F.on("timeTravel:clear",()=>A()),F.on("timeTravel:history",(...I)=>{const N=I[0];typeof N=="function"&&N([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(F,I){let N="";n&&Vo.has(F.type)&&s&&!a&&(N=Dc(F,s.getState())),I(F),n&&Vo.has(F.type)&&!a&&N&&b(N)},renderDOM(F,I){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const N=document.createElement("button");N.className="ng-timetravel-btn",N.textContent="◀",N.title="Step backward",N.addEventListener("click",()=>C()),p.appendChild(N),w=document.createElement("button"),w.className="ng-timetravel-btn",w.textContent="▶",w.title="Play / Pause",w.addEventListener("click",()=>D()),p.appendChild(w);const L=document.createElement("button");L.className="ng-timetravel-btn",L.textContent="▶",L.title="Step forward",L.addEventListener("click",()=>M()),p.appendChild(L),v=document.createElement("span"),v.className="ng-timetravel-speed ng-timetravel-btn",v.textContent=`${sn[c]}x`,v.title="Click to cycle speed",v.addEventListener("click",()=>E()),p.appendChild(v),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",x);const H=document.createElement("div");H.className="ng-timetravel-rail",r.appendChild(H),g=document.createElement("div"),g.style.position="absolute",g.style.inset="0",r.appendChild(g),d=document.createElement("div"),d.className="ng-timetravel-playhead",d.addEventListener("mousedown",W),r.appendChild(d),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const U=document.createElement("button");U.className="ng-timetravel-btn ng-present",U.textContent="Present",U.title="Return to latest state",U.addEventListener("click",()=>T()),p.appendChild(U),F.appendChild(p)}R()},destroy(){k();for(const F of h)F();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,d=null,f=null,w=null,v=null,g=null,Mc(),o.length=0,i=-1,a=!1,l=!1,y=!1,s=null}}}const Ko=864e5,Lc=60,Rc=2,jo=[6,4],Wn="nimbus-gantt-montecarlo-styles",qo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},Pc=.08,_c=`
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
`;function Xn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function on(e,t){return Math.round((t.getTime()-e.getTime())/Ko)}function lt(e,t){return new Date(e.getTime()+t*Ko)}function Zo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Jo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function $c(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Oc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Nc(e,t){return e+Math.random()*(t-e)}function Hc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const c=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(l),r=[];for(let w=0;w<u;w++)p[w]===0&&(r.push(w),c[w]=o[w],h[w]=o[w]+s[w]);let d=0;for(;d<r.length;){const w=r[d++],v=h[w],g=i[w];for(let y=0;y<g.length;y++){const b=g[y];v>c[b]&&(c[b]=v,h[b]=v+s[b]),p[b]--,p[b]===0&&r.push(b)}}for(let w=0;w<u;w++)h[w]===0&&s[w]>0&&(c[w]=o[w],h[w]=o[w]+s[w]);let f=0;for(let w=0;w<u;w++)h[w]>f&&(f=h[w]);return f}function xc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),c=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let v=0;v<e;v++)h[v]===0&&(r.push(v),a[v]=n[v],l[v]=n[v]+t[v]);let d=0;for(;d<r.length;){const v=r[d++];p.push(v);const g=l[v];for(const y of s[v])g>a[y]&&(a[y]=g,l[y]=g+t[y]),h[y]--,h[y]===0&&r.push(y)}for(let v=0;v<e;v++)l[v]===0&&t[v]>0&&(a[v]=n[v],l[v]=n[v]+t[v],p.push(v));let f=0;for(let v=0;v<e;v++)l[v]>f&&(f=l[v]);for(let v=0;v<e;v++)s[v].length===0?(c[v]=f,u[v]=f-t[v]):(c[v]=1/0,u[v]=1/0);for(let v=p.length-1;v>=0;v--){const g=p[v];if(c[g]===1/0){let y=1/0;for(const b of s[g])u[b]<y&&(y=u[b]);y===1/0?c[g]=f:c[g]=y,u[g]=c[g]-t[g]}}const w=new Set;for(let v=0;v<e;v++){const g=u[v]-a[v];Math.abs(g)<.5&&w.add(v)}return w}function Bc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const H of e.keys())u.set(H,l.length),l.push(H);const c=l.length;if(c===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(c),p=new Float64Array(c);let r=1/0;for(const H of e.values()){const U=Xn(H.startDate).getTime();U<r&&(r=U)}const d=new Date(r);for(let H=0;H<c;H++){const U=e.get(l[H]),ee=Xn(U.startDate),Z=Xn(U.endDate);h[H]=Math.max(on(ee,Z),1),p[H]=on(d,ee)}const f=Array.from({length:c},()=>[]),w=Array.from({length:c},()=>[]),v=new Int32Array(c);for(const H of t.values()){if((H.type||"FS")!=="FS")continue;const ee=u.get(H.source),Z=u.get(H.target);ee===void 0||Z===void 0||(f[ee].push(Z),w[Z].push(ee),v[Z]++)}const g=f.map(H=>new Int32Array(H)),y=w.map(H=>new Int32Array(H)),b=new Float64Array(s),m=new Float64Array(c),T=new Float64Array(c),S=new Float64Array(c),k=new Float64Array(c),D=new Float64Array(c),E=Math.max(1,Math.floor(s/100));for(let H=0;H<s;H++){for(let U=0;U<c;U++){const ee=h[U];let Z;switch(i){case"triangular":{const re=ee*(1-o),ge=ee,Te=ee*(1+o*1.5);Z=$c(re,ge,Te);break}case"normal":{Z=Oc(ee,ee*o);break}case"uniform":{Z=Nc(ee*(1-o),ee*(1+o));break}}m[U]=Math.max(.5,Z),T[U]+=m[U],S[U]+=m[U]*m[U],m[U]>h[U]&&k[U]++}if(b[H]=Hc(l,u,h,m,p,g,y,v),H%E===0){const U=xc(c,m,p,g,y,v);for(const ee of U)D[ee]++}}const C=Array.from(b).sort((H,U)=>H-U),M=C.map(H=>lt(d,H)),A=new Map;for(const H of a){const U=Math.min(Math.floor(H*C.length),C.length-1);A.set(H,lt(d,C[U]))}let R=0;for(let H=0;H<s;H++)R+=C[H];const O=R/s,$=lt(d,O),P=Math.floor(s/2),x=lt(d,C[P]);let W=0;for(let H=0;H<s;H++){const U=C[H]-O;W+=U*U}const K=Math.sqrt(W/s),q=lt(d,C[0]),F=lt(d,C[C.length-1]),I=new Map;for(let H=0;H<c;H++){const U=T[H]/s,ee=S[H]/s-U*U;I.set(l[H],{meanDuration:U,stdDev:Math.sqrt(Math.max(0,ee)),delayProbability:k[H]/s})}const N=Math.floor(s/E),L=new Map;for(let H=0;H<c;H++)D[H]>0&&L.set(l[H],D[H]/N);return{iterations:s,finishDates:M,percentiles:A,meanFinishDate:$,medianFinishDate:x,earliestFinish:q,latestFinish:F,standardDeviation:K,taskRisk:I,criticalPathFrequency:L}}function Fc(){if(typeof document>"u"||document.getElementById(Wn))return;const e=document.createElement("style");e.id=Wn,e.textContent=_c,document.head.appendChild(e)}function Uc(){if(typeof document>"u")return;const e=document.getElementById(Wn);e&&e.remove()}function Yc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const d={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=Bc(f.tasks,f.dependencies,d),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function c(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",d=0;for(const[g,y]of s.criticalPathFrequency)y>d&&(d=y,r=g);let f=r;if(n){const g=n.getState().tasks.get(r);g&&(f=g.name)}let w=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const g of t.confidenceLevels){const y=s.percentiles.get(g);if(!y)continue;const b=Math.round(g*100),m=qo[g]||"#94A3B8";w+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${b}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${Jo(y)}</span>
        </div>
      `}if(w+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${Jo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&d>0){const g=Math.round(d*100);w+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${g}% of runs)
        </div>
      `}a.innerHTML=w;const v=a.querySelector(".ng-montecarlo-close");v&&v.addEventListener("click",()=>u())}function p(r,d){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:w}=d.config,v=d.scrollX,g=r.canvas.width/(window.devicePixelRatio||1),y=r.canvas.height/(window.devicePixelRatio||1),b=w,m=y-b,T=s.earliestFinish,S=s.latestFinish,k=Math.max(on(T,S),1),D=f.getColumnWidth(),E=Math.max(D,Rc),C=Math.max(Math.ceil(k),1),M=new Uint32Array(C);for(const P of s.finishDates){const x=on(T,P),W=Math.min(Math.max(Math.floor(x),0),C-1);M[W]++}let A=0;for(let P=0;P<C;P++)M[P]>A&&(A=M[P]);if(A===0)return;r.save(),r.beginPath(),r.rect(0,b,g,m),r.clip(),r.translate(-v,0);const R=s.finishDates[Math.floor(s.finishDates.length*.1)],O=s.finishDates[Math.floor(s.finishDates.length*.9)];if(R&&O){const P=f.dateToX(R),x=f.dateToX(O),W=r.createLinearGradient(P,0,x,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=Pc*5,r.fillRect(P,b,x-P,m),r.globalAlpha=1}const $=y-8;for(let P=0;P<C;P++){if(M[P]===0)continue;const x=lt(T,P),W=f.dateToX(x),K=M[P]/A*Lc,q=C>1?P/(C-1):.5;let F,I,N;if(q<.5){const L=q*2;F=Math.round(34+200*L),I=Math.round(197+-18*L),N=Math.round(94+-86*L)}else{const L=(q-.5)*2;F=Math.round(234+5*L),I=Math.round(179+-111*L),N=Math.round(8+60*L)}r.fillStyle=`rgba(${F}, ${I}, ${N}, 0.6)`,r.fillRect(W,$-K,Math.max(E-1,1),K)}r.setLineDash(jo),r.lineWidth=1.5;for(const[P,x]of s.percentiles){const W=f.dateToX(x),K=qo[P]||"#94A3B8",q=`P${Math.round(P*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,b),r.lineTo(W,y),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const F=r.measureText(`${q}: ${Zo(x)}`).width,I=`${q}: ${Zo(x)}`,N=F+8,L=16,H=W-N/2,U=b+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(H+3,U),r.lineTo(H+N-3,U),r.arcTo(H+N,U,H+N,U+3,3),r.lineTo(H+N,U+L-3),r.arcTo(H+N,U+L,H+N-3,U+L,3),r.lineTo(H+3,U+L),r.arcTo(H,U+L,H,U+L-3,3),r.lineTo(H,U+3),r.arcTo(H,U,H+3,U,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(I,W,U+3),r.setLineDash(jo)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Fc(),i.push(r.on("montecarlo:run",(...d)=>{const f=d[0];l(f)}),r.on("montecarlo:result",(...d)=>{const f=d[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...d)=>{const f=d[0];f&&c(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,d){d(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,d,f){!o||!s||p(r,d)},renderDOM(r,d){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Uc(),s=null,n=null}}}const an=864e5,Qo=400,zn="nimbus-gantt-narrative-styles",ei=300;function ze(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Gn(e,t){return Math.round((t.getTime()-e.getTime())/an)}function ti(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function ni(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*an)}function si(e,t){return new Date(e.getTime()+t*an)}function Wc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const C=ze(E.startDate).getTime(),M=ze(E.endDate).getTime();C<s&&(s=C),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=Gn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const c=new Map,h=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(c.has(E.source)||c.set(E.source,[]),c.get(E.source).push(E.target),h.has(E.target)||h.set(E.target,[]),h.get(E.target).push(E.source));const p=Vc(n,t),r=ni(i),d=ni(a),f=[];let w=r;for(;w.getTime()<=d.getTime();)f.push({start:new Date(w),end:si(w,6)}),w=si(w,7);const v=[];for(let E=0;E<f.length;E++){const C=f[E],M=C.start,A=C.end,R=[],O=[],$=[],P=[],x=[],W=[],K=[];for(const L of n){const H=ze(L.startDate),U=ze(L.endDate);H>=M&&H<=A&&(R.push(L),L.isMilestone?(W.push(L),K.push(`Milestone: ${L.name}`)):K.push(`Started: ${L.name}`)),U>=M&&U<=A&&(L.isCompleted||L.progress!==void 0&&L.progress>=1)&&(O.push(L),K.push(`Completed: ${L.name}`)),H<=A&&U>=M&&(x.push(L),H<M&&!L.isCompleted&&(L.progress===void 0||L.progress===0)&&$.push(L),!L.isCompleted&&L.progress!==void 0&&L.progress>0&&L.progress<1&&P.push(L))}for(const L of n)if(L.isMilestone){const H=ze(L.startDate);H>=M&&H<=A&&!W.includes(L)&&(W.push(L),K.push(`Milestone: ${L.name}`))}const q=x.filter(L=>p.has(L.id)),F=Xc(R,O,$,x,q),I=zc(R,O,$,P,x,q,W,c,e),N=`Week ${E+1} (${ti(M)}–${ti(A)})`;v.push({weekLabel:N,headline:F,body:I,metrics:{started:R.length,completed:O.length,delayed:$.length,onTrack:P.length},events:K})}const g=n.length,y=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,b=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,m=g-y-b,T=g>0?Math.round(y/g*100):0,S=T>=75?"strong":T>=50?"moderate":T>=25?"early-stage":"just getting started",k=`This project spans ${l} days across ${f.length} weeks with ${g} tasks. Progress is ${S} at ${T}% completion (${y} done, ${b} in progress, ${m} not started).`,D=Gc(n,p,c,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:k,chapters:v,insights:D}}function Xc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function zc(e,t,n,s,o,i,a,l,u){const c=[];if(e.length>0)if(e.length<=3){const r=e.map(d=>d.name).join(", ");c.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(d=>d.name).join(", ");c.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(d=>d.name).join(", ");c.push(`${r} ${t.length===1?"was":"were"} completed.`)}else c.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&c.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(d=>d.name).join(", ");c.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const d=n.map(f=>f.name).join(", ");c.push(`${d} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else c.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const d of n){const f=l.get(d.id);if(f)for(const w of f){const v=u.get(w);v&&!r.includes(v.name)&&r.push(v.name)}}if(r.length>0){const d=r.slice(0,3).join(", ");c.push(`This puts downstream work at risk, including ${d}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&c.length<4){const r=i.slice(0,2).map(d=>d.name).join(" and ");c.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,d)=>d[1]-r[1]);return p.length>0&&p[0][1]>=3&&c.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),c.length===0&&c.push("No significant activity scheduled for this week."),c.join(" ")}function Gc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const v=e.filter(b=>t.has(b.id)),g=v.slice(0,4).map(b=>b.name).join(", "),y=v.length>4?` and ${v.length-4} more`:"";l.push(`The critical path runs through ${g}${y} — any delay here pushes the project finish.`)}const u=new Map;for(const v of e)v.assignee&&!v.isCompleted&&u.set(v.assignee,(u.get(v.assignee)||0)+1);const c=Array.from(u.entries()).sort((v,g)=>g[1]-v[1]);c.length>0&&c[0][1]>=2&&l.push(`${c[0][0]} is carrying the heaviest load with ${c[0][1]} concurrent tasks.`);const h=e.filter(v=>v.isCompleted?!1:ze(v.startDate)<a&&(v.progress===void 0||v.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=Gn(o,i),r=Gn(o,a);if(r>0&&p>0){const v=Math.round(r/p*100),g=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,y=Math.round(g/e.length*100),b=y-v;Math.abs(b)>=5?b>0?l.push(`Project is running ahead: ${y}% of tasks completed with ${v}% of time elapsed.`):l.push(`Project is running behind: only ${y}% of tasks completed with ${v}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${y}% complete at ${v}% of elapsed time.`)}const d=e.filter(v=>{if(v.isCompleted||v.progress!==void 0&&v.progress>0)return!1;const g=s.get(v.id);return!g||g.length===0});d.length>0&&d.length<=e.length*.5&&l.push(`${d.length} task${d.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,w="";for(const v of e){const g=n.get(v.id);g&&g.length>f&&(f=g.length,w=v.name)}return f>=3&&l.push(`"${w}" is a bottleneck with ${f} downstream tasks depending on it.`),l}function Vc(e,t){const n=new Map;for(const d of e)n.set(d.id,d);const s=new Map,o=new Map;for(const d of e)s.set(d.id,[]),o.set(d.id,0);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||(s.get(d.source).push({target:d.target,lag:d.lag||0}),o.set(d.target,(o.get(d.target)||0)+1)));const i=new Map,a=[];for(const d of e)o.get(d.id)===0&&a.push(d.id);for(const d of e){const f=ze(d.endDate).getTime();i.set(d.id,f)}const l=new Map(o);for(;a.length>0;){const d=a.shift(),f=i.get(d);for(const w of s.get(d)){const v=n.get(w.target),g=ze(v.endDate).getTime()-ze(v.startDate).getTime(),y=f+w.lag*an+g;y>i.get(w.target)&&i.set(w.target,y);const b=l.get(w.target)-1;l.set(w.target,b),b===0&&a.push(w.target)}}let u=-1/0,c="";for(const[d,f]of i)f>u&&(u=f,c=d);if(!c)return new Set;const h=new Set,p=new Map;for(const d of e)p.set(d.id,[]);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||p.get(d.target).push({source:d.source,lag:d.lag||0}));let r=c;for(;r;){h.add(r);const d=p.get(r);if(!d||d.length===0)break;let f="",w=-1/0;for(const v of d){const g=i.get(v.source)||0;g>w&&(w=g,f=v.source)}if(!f||h.has(f))break;r=f}return h}const Kc=`
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
    transition: opacity ${ei}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Qo}px;
    width: ${Qo}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${ei}ms ease;
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
`;function jc(){if(typeof document>"u"||document.getElementById(zn))return;const e=document.createElement("style");e.id=zn,e.textContent=Kc,document.head.appendChild(e)}function qc(){if(typeof document>"u")return;const e=document.getElementById(zn);e&&e.remove()}function Zc(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Jc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=Wc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function c(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const d=document.createElement("div");d.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",d.appendChild(f);const w=document.createElement("span");w.textContent="Project Story",d.appendChild(w),r.appendChild(d);const v=document.createElement("div");v.style.display="flex",v.style.alignItems="center",v.style.gap="4px";const g=document.createElement("button");g.className="ng-narrative-refresh",g.innerHTML="↻",g.title="Regenerate",g.addEventListener("click",()=>{l(),h()}),v.appendChild(g);const y=document.createElement("button");y.className="ng-narrative-close",y.innerHTML="×",y.addEventListener("click",c),v.appendChild(y),r.appendChild(v),a.appendChild(r);const b=document.createElement("div");if(b.className="ng-narrative-summary",b.textContent=t.summary,a.appendChild(b),t.chapters.length===0){const S=document.createElement("div");S.className="ng-narrative-empty",S.textContent="No weekly chapters to display.",a.appendChild(S)}else for(const S of t.chapters){const k=document.createElement("div");k.className="ng-narrative-chapter";const D=Zc(S),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const C=document.createElement("div");C.className="ng-narrative-week-label",C.textContent=S.weekLabel,E.appendChild(C);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=S.headline,E.appendChild(M),k.appendChild(E);const A=document.createElement("div");if(A.className="ng-narrative-metrics",S.metrics.started>0&&A.appendChild(p("started",`${S.metrics.started} started`)),S.metrics.completed>0&&A.appendChild(p("completed",`${S.metrics.completed} done`)),S.metrics.delayed>0&&A.appendChild(p("delayed",`${S.metrics.delayed} delayed`)),S.metrics.onTrack>0&&A.appendChild(p("ontrack",`${S.metrics.onTrack} on track`)),A.children.length>0&&k.appendChild(A),S.body){const R=document.createElement("div");R.className="ng-narrative-body",R.textContent=S.body,k.appendChild(R)}a.appendChild(k)}if(t.insights.length>0){const S=document.createElement("div");S.className="ng-narrative-insights";const k=document.createElement("div");k.className="ng-narrative-insights-title",k.innerHTML="<span>💡</span> Key Insights",S.appendChild(k);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const C=document.createElement("span");C.className="ng-narrative-insight-icon",C.textContent="•",E.appendChild(C);const M=document.createElement("span");M.textContent=D,E.appendChild(M),S.appendChild(E)}a.appendChild(S)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const T=new Date(t.generatedAt);m.textContent=`Generated ${T.toLocaleString()}`,a.appendChild(m)}function p(r,d){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=d,f}return{name:"NarrativePlugin",install(r){e=r,jc(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>c()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,d){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?c():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",c),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),qc(),e=null,t=null,n=!1}}}const Qc=864e5,ed=10,Vn="nimbus-gantt-whatif-styles",oi=.25,td=.6,rn=6,ii="#38A169",ai="#E53E3E",ri="#A0AEC0",Kn=36,nd="#F6AD55",li="#1a202c",sd=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Kn}px;
    background: ${nd};
    color: ${li};
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
    color: ${li};
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
    top: ${Kn}px;
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
    top: ${Kn+8}px;
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
    color: ${ii};
  }
  .ng-whatif-summary-value--worsened {
    color: ${ai};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${ri};
  }
`;function Ge(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ci(e){const t=Ge(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function ln(e,t){return Math.round((t.getTime()-e.getTime())/Qc)}function di(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function od(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function id(e){return{...e}}function ad(){if(typeof document>"u"||document.getElementById(Vn))return;const e=document.createElement("style");e.id=Vn,e.textContent=sd,document.head.appendChild(e)}function rd(){if(typeof document>"u")return;const e=document.getElementById(Vn);e&&e.remove()}function ld(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,od(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,id(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function ui(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function cd(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,c=null,h=null,p=null,r=null,d=null,f=null;function w(){t||!e||(o=ld(e.getState()),i=[],t=!0,n=!1,D())}function v(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),M(),R())}function g(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),M())}function y(I){if(!t||!e||!o)return;a.length>=ed&&a.shift();const N=e.getState(),L=ui(N.tasks),H=Ge(o.projectFinish),U=Ge(L),ee=ln(H,U);let Z=0;for(const[ge,Te]of o.tasks){const Y=N.tasks.get(ge);if(!Y){Z++;continue}(Y.startDate!==Te.startDate||Y.endDate!==Te.endDate||Y.assignee!==Te.assignee)&&Z++}for(const ge of N.tasks.keys())o.tasks.has(ge)||Z++;const re={id:di(),name:I,createdAt:Date.now(),changes:[...i],result:{projectFinish:L,criticalPathDelta:ee,tasksAffected:Z}};a.push(re),x()}function b(I){if(!e||!o)return;const N=a.find(L=>L.id===I);if(N){t||w(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const L of N.changes)T(L);i=[...N.changes],E()}}function m(I){a=a.filter(N=>N.id!==I),x()}function T(I){if(e)switch(I.type){case"move":case"resize":I.taskId&&I.after&&I.after.startDate&&I.after.endDate&&e.dispatch({type:I.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:I.taskId,startDate:I.after.startDate,endDate:I.after.endDate});break;case"add":I.after&&e.dispatch({type:"ADD_TASK",task:I.after});break;case"remove":I.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:I.taskId});break;case"reassign":I.taskId&&I.after&&e.dispatch({type:"UPDATE_TASK",taskId:I.taskId,changes:I.after});break;case"add-dependency":I.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:I.dependencyId||di(),source:I.dependency.source,target:I.dependency.target,type:I.dependency.type||"FS"}});break;case"remove-dependency":I.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:I.dependencyId});break}}function S(){t&&(n=!n,n?C():M())}function k(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const I=e.getState(),N=ui(I.tasks),L=Ge(o.projectFinish),H=Ge(N),U=ln(L,H);let ee=0;for(const[Z,re]of o.tasks){const ge=I.tasks.get(Z);if(!ge){ee++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&ee++}for(const Z of I.tasks.keys())o.tasks.has(Z)||ee++;return{baselineFinish:o.projectFinish,sandboxFinish:N,deltaDays:U,tasksAffected:ee}}function D(){u&&u.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function C(){if(!h)return;const I=k();let N="ng-whatif-summary-value--unchanged",L="No change";I.deltaDays<0?(N="ng-whatif-summary-value--improved",L=`${Math.abs(I.deltaDays)} day${Math.abs(I.deltaDays)!==1?"s":""} earlier`):I.deltaDays>0&&(N="ng-whatif-summary-value--worsened",L=`${I.deltaDays} day${I.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${ci(I.baselineFinish)} &rarr; ${ci(I.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${N}">${L}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${I.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function A(){s=!s,c&&c.classList.toggle("ng-open",s),s&&x()}function R(){s=!1,c&&c.classList.remove("ng-open")}function O(){r&&(r.classList.add("ng-active"),d==null||d.focus())}function $(){r&&r.classList.remove("ng-active"),d&&(d.value="")}function P(){if(!d)return;const I=d.value.trim();I&&(y(I),$())}function x(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(I=>{var U;const N=new Date(I.createdAt).toLocaleDateString(),L=((U=I.result)==null?void 0:U.criticalPathDelta)??0;let H="No impact";return L<0?H=`${Math.abs(L)}d earlier`:L>0&&(H=`${L}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${I.id}">
            <div class="ng-whatif-scenario-name">${W(I.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${N}</span>
              <span>${I.changes.length} changes</span>
              <span>${H}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${I.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${I.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${I.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(I){const N=document.createElement("div");return N.textContent=I,N.innerHTML}function K(I){const N=I.target,L=N.getAttribute("data-action"),H=N.getAttribute("data-id");if(!(!L||!H))switch(L){case"load":b(H),R();break;case"compare":b(H),n=!0,C(),R();break;case"delete":m(H);break}}function q(I,N){switch(I.type){case"TASK_MOVE":{const L=N.tasks.get(I.taskId);L&&i.push({type:"move",taskId:I.taskId,before:{startDate:L.startDate,endDate:L.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"TASK_RESIZE":{const L=N.tasks.get(I.taskId);L&&i.push({type:"resize",taskId:I.taskId,before:{startDate:L.startDate,endDate:L.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:I.task.id,after:{...I.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:I.taskId,before:N.tasks.get(I.taskId)?{...N.tasks.get(I.taskId)}:void 0});break;case"UPDATE_TASK":{const L=N.tasks.get(I.taskId);L&&i.push({type:"reassign",taskId:I.taskId,before:{...L},after:I.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:I.dependency.id,dependency:{source:I.dependency.source,target:I.dependency.target,type:I.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:I.dependencyId});break}E()}function F(I,N,L,H,U,ee){const Z=Math.min(ee,H/2,U/2);I.beginPath(),I.moveTo(N+Z,L),I.lineTo(N+H-Z,L),I.arcTo(N+H,L,N+H,L+Z,Z),I.lineTo(N+H,L+U-Z),I.arcTo(N+H,L+U,N+H-Z,L+U,Z),I.lineTo(N+Z,L+U),I.arcTo(N,L+U,N,L+U-Z,Z),I.lineTo(N,L+Z),I.arcTo(N,L,N+Z,L,Z),I.closePath()}return{name:"WhatIfPlugin",install(I){e=I,ad(),l.push(I.on("whatif:enter",()=>w())),l.push(I.on("whatif:exit",()=>v())),l.push(I.on("whatif:compare",()=>S())),l.push(I.on("whatif:discard",()=>g())),l.push(I.on("whatif:save",(...N)=>{const L=typeof N[0]=="string"?N[0]:void 0;L?y(L):O()})),l.push(I.on("whatif:load",(...N)=>{const L=typeof N[0]=="string"?N[0]:void 0;L?b(L):A()})),l.push(I.on("whatif:list-scenarios",(...N)=>{const L=typeof N[0]=="function"?N[0]:void 0;L?L([...a]):A()})),l.push(I.on("whatif:delete-scenario",(...N)=>{const L=typeof N[0]=="string"?N[0]:void 0;L&&m(L)}))},middleware(I,N){if(!t){N(I);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(I.type)&&e){const H=e.getState();q(I,H)}N(I)},renderCanvas(I,N,L){if(!t||!e)return;const{theme:H,headerHeight:U,barHeight:ee}=N.config,Z=N.scrollX,re=N.scrollY,ge=U,Te=e.getTimeScale(),Y=H.barBorderRadius;if(I.save(),I.beginPath(),I.rect(0,ge,I.canvas.width,I.canvas.height-ge),I.clip(),I.translate(-Z,0),o){const te=new Set;for(const j of L){const Q=o.tasks.get(j.taskId),se=N.tasks.get(j.taskId);(!Q&&se||Q&&se&&(Q.startDate!==se.startDate||Q.endDate!==se.endDate||Q.assignee!==se.assignee))&&te.add(j.taskId)}for(const j of L){if(!te.has(j.taskId))continue;const Q=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>I.canvas.height||(I.save(),I.setLineDash([4,3]),I.strokeStyle="#F6AD55",I.lineWidth=2,F(I,Q,se,de,ie,Y),I.stroke(),I.restore())}}if(n&&o){const te=ee*td;for(const j of L){if(j.isMilestone)continue;const Q=o.tasks.get(j.taskId);if(!Q)continue;const se=N.tasks.get(j.taskId);if(!se)continue;const de=Ge(Q.startDate),ie=Ge(Q.endDate),fe=Ge(se.startDate),ce=Ge(se.endDate),be=ln(de,fe),ve=ln(ie,ce);if(be===0&&ve===0)continue;let X=ri;ve<0?X=ii:ve>0&&(X=ai);const _=Te.dateToX(de),B=Te.dateToX(ie),z=Math.max(B-_,2),G=j.barY-re,V=G+ee+2;I.save(),I.globalAlpha=oi,I.fillStyle=X,F(I,_,V,z,te,Y),I.fill(),I.globalAlpha=oi*2,I.strokeStyle=X,I.lineWidth=1,I.stroke(),I.restore();const ne=_+z/2,oe=V+te/2,ae=j.x+j.width/2,le=G+ee/2;I.save(),I.globalAlpha=.6,I.strokeStyle=X,I.lineWidth=1.5,I.setLineDash([3,2]),I.beginPath(),I.moveTo(ne,oe),I.lineTo(ae,le),I.stroke();const me=Math.atan2(le-oe,ae-ne),we=ae,Me=le;I.setLineDash([]),I.beginPath(),I.moveTo(we,Me),I.lineTo(we-rn*Math.cos(me-Math.PI/6),Me-rn*Math.sin(me-Math.PI/6)),I.lineTo(we-rn*Math.cos(me+Math.PI/6),Me-rn*Math.sin(me+Math.PI/6)),I.closePath(),I.fillStyle=X,I.fill(),I.restore()}}I.restore()},renderDOM(I,N){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const L=document.createElement("div");L.className="ng-whatif-banner-left";const H=document.createElement("span");H.className="ng-whatif-badge",H.textContent="What-If Mode",L.appendChild(H);const U=document.createElement("span");U.textContent="Changes are hypothetical",U.style.fontSize="12px",U.style.opacity="0.7",L.appendChild(U);const ee=document.createElement("span");ee.textContent="·",ee.style.opacity="0.4",L.appendChild(ee),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",L.appendChild(p),u.appendChild(L);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",d=document.createElement("input"),d.type="text",d.placeholder="Scenario name...",d.addEventListener("keydown",se=>{se.key==="Enter"&&P(),se.key==="Escape"&&$()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",P);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>$()),r.appendChild(d),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const Te=document.createElement("button");Te.className="ng-whatif-btn",Te.textContent="Scenarios",Te.addEventListener("click",()=>A()),Z.appendChild(Te);const Y=document.createElement("button");Y.className="ng-whatif-btn ng-whatif-btn--primary",Y.textContent="Compare with Baseline",Y.addEventListener("click",()=>S()),Z.appendChild(Y);const te=document.createElement("button");te.className="ng-whatif-btn",te.textContent="Save Scenario",te.addEventListener("click",()=>O()),Z.appendChild(te);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>g()),Z.appendChild(j);const Q=document.createElement("button");Q.className="ng-whatif-btn ng-whatif-btn--danger",Q.textContent="Exit",Q.addEventListener("click",()=>v()),Z.appendChild(Q),u.appendChild(Z),I.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",I.appendChild(h)),!c){c=document.createElement("div"),c.className="ng-whatif-panel";const L=document.createElement("div");L.className="ng-whatif-panel-title";const H=document.createElement("span");H.textContent="Saved Scenarios",L.appendChild(H);const U=document.createElement("button");U.className="ng-whatif-panel-close",U.textContent="×",U.addEventListener("click",()=>R()),L.appendChild(U),c.appendChild(L),f=document.createElement("div"),f.addEventListener("click",K),c.appendChild(f),I.appendChild(c),x()}D(),n&&C()},destroy(){for(const I of l)I();l.length=0,u&&(u.remove(),u=null),c&&(c.remove(),c=null),h&&(h.remove(),h=null),p=null,r=null,d=null,f=null,rd(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const jn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},dd=261.63;function ud(e){return dd*Math.pow(2,e/12)}function gd(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return ud(n?a+12:a)}const qn="nimbus-gantt-sonification-styles",Zn=64,cn=64,gi=.05,hd=.1,fd=.7,hi=.2,Jn="#F6AD55",pd=2,md="rgba(246, 173, 85, 0.35)",fi=12,yd=`
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
    height: ${Zn}px;
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
`;function Qn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Td(){if(typeof document>"u"||document.getElementById(qn))return;const e=document.createElement("style");e.id=qn,e.textContent=yd,document.head.appendChild(e)}function bd(){if(typeof document>"u")return;const e=document.getElementById(qn);e&&e.remove()}function vd(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,c=null,h=null;const p=new Map;let r="stopped",d=0,f=0,w=0,v=0,g=0,y=0,b=0,m=null,T=null,S=null,k=null,D=null,E=null;const C=[];let M=[],A=[];function R(){if(l)return;const Y=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;Y&&(l=new Y,u=l.createGain(),u.gain.value=i,c=l.createAnalyser(),c.fftSize=256,h=new Uint8Array(c.frequencyBinCount),u.connect(c),c.connect(l.destination))}function O(){l&&l.state==="suspended"&&l.resume()}function $(){if(!a)return;const Y=a.getState(),te=Date.now();let j=1/0,Q=-1/0;const se=[],de=new Set,ie=Y.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,be]of Y.tasks){const ve=Qn(be.startDate).getTime(),X=Qn(be.endDate).getTime();ve<j&&(j=ve),X>Q&&(Q=X);const _=be.groupId||"__default__";de.add(_);const B=fe.get(ce)??0,z=!be.isCompleted&&X<te&&(be.progress??0)<1;se.push({id:ce,startMs:ve,endMs:X,rowIndex:B,progress:be.progress??0,groupId:_,isCritical:!1,isOverdue:z})}M=se,A=Array.from(de),g=j===1/0?0:j,y=Q===-1/0?0:Q,b=Math.max(y-g,1)}function P(Y){if(!l||!u||p.has(Y.id))return;const te=jn[n]||jn.major,j=gd(Y.rowIndex,te,Y.isCritical),Q=l.createOscillator();Q.type=s,Q.frequency.value=j,Y.isOverdue&&(Q.detune.value=25);const se=.3+Y.progress*.7,de=Y.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+gi),fe.gain.linearRampToValueAtTime(ie*fd,l.currentTime+gi+hd);const ce=l.createStereoPanner();if(A.length<=1)ce.pan.value=0;else{const be=A.indexOf(Y.groupId);ce.pan.value=A.length>1?be/(A.length-1)*2-1:0}Q.connect(fe),fe.connect(ce),ce.connect(u),Q.start(),p.set(Y.id,{taskId:Y.id,oscillator:Q,gainNode:fe,panNode:ce})}function x(Y){const te=p.get(Y);if(!te||!l)return;const j=l.currentTime;te.gainNode.gain.cancelScheduledValues(j),te.gainNode.gain.setValueAtTime(te.gainNode.gain.value,j),te.gainNode.gain.linearRampToValueAtTime(0,j+hi),te.oscillator.stop(j+hi+.05),p.delete(Y)}function W(){for(const Y of Array.from(p.keys()))x(Y)}function K(){if(r!=="playing"||!l)return;const Y=l.currentTime-d;if(f=Math.min(Y/o,1),f>=1){I();return}const te=g+f*b;for(const j of M){const Q=te>=j.startMs&&te<j.endMs,se=p.has(j.id);Q&&!se?P(j):!Q&&se&&x(j.id)}Z(),v=requestAnimationFrame(K)}function q(){R(),O(),l&&($(),r==="paused"?d=l.currentTime-w*o:(d=l.currentTime,f=0),r="playing",H(),U(),v=requestAnimationFrame(K))}function F(){r==="playing"&&(r="paused",w=f,W(),cancelAnimationFrame(v),H())}function I(){r="stopped",f=0,w=0,W(),cancelAnimationFrame(v),H(),ee()}function N(){r==="playing"?F():q()}function L(Y){const te=Qn(Y).getTime(),j=Math.max(0,Math.min((te-g)/b,1));r==="playing"&&l?d=l.currentTime-j*o:(w=j,f=j)}function H(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=re(),D.classList.remove("ng-son-btn--active")))}function U(){T&&T.classList.remove("ng-hidden")}function ee(){T&&T.classList.add("ng-hidden")}function Z(){if(!c||!h||!k||!S)return;c.getByteFrequencyData(h);const Y=S.width,te=S.height;k.clearRect(0,0,Y,te);const j=k.createLinearGradient(0,0,0,te);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),k.fillStyle=j,k.fillRect(0,0,Y,te);const Q=Y/cn*.8,se=Y/cn*.2,de=Math.floor(h.length/cn);for(let ie=0;ie<cn;ie++){let fe=0;for(let z=0;z<de;z++)fe+=h[ie*de+z]??0;const ce=fe/de,be=ce/255*te*.85,ve=ie*(Q+se),X=te-be,_=30+ce/255*15,B=55+ce/255*15;k.fillStyle=`hsl(${_}, 90%, ${B}%)`,k.fillRect(ve,X,Q,be)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function Te(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(Y){a=Y,Td(),C.push(Y.on("sonification:play",()=>q())),C.push(Y.on("sonification:pause",()=>F())),C.push(Y.on("sonification:stop",()=>I())),C.push(Y.on("sonification:scrub",(...te)=>{const j=typeof te[0]=="string"?te[0]:void 0;j&&L(j)})),C.push(Y.on("sonification:configure",(...te)=>{const j=te[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(Y,te,j){if(r==="stopped"||!a)return;const{headerHeight:Q}=te.config,se=te.scrollX,de=te.scrollY,ie=Q,fe=a.getTimeScale(),ce=g+f*b,be=new Date(ce),ve=fe.dateToX(be);Y.save(),Y.beginPath(),Y.rect(0,ie,Y.canvas.width,Y.canvas.height-ie),Y.clip(),Y.translate(-se,0),Y.save(),Y.shadowColor=Jn,Y.shadowBlur=fi,Y.strokeStyle=Jn,Y.lineWidth=pd,Y.beginPath(),Y.moveTo(ve,ie),Y.lineTo(ve,Y.canvas.height+de),Y.stroke(),Y.restore();const X=new Map;for(const _ of j)X.set(_.taskId,_);for(const _ of p.values()){const B=X.get(_.taskId);if(!B)continue;const z=B.x,G=B.barY-de,V=B.width,ne=B.barHeight;if(G+ne<ie||G>Y.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);Y.save(),Y.globalAlpha=ae,Y.shadowColor=md,Y.shadowBlur=fi,Y.fillStyle=Jn;const le=Math.min(te.config.theme.barBorderRadius,V/2,ne/2);Y.beginPath(),Y.moveTo(z+le,G),Y.lineTo(z+V-le,G),Y.arcTo(z+V,G,z+V,G+le,le),Y.lineTo(z+V,G+ne-le),Y.arcTo(z+V,G+ne,z+V-le,G+ne,le),Y.lineTo(z+le,G+ne),Y.arcTo(z,G+ne,z,G+ne-le,le),Y.lineTo(z,G+le),Y.arcTo(z,G,z+le,G,le),Y.closePath(),Y.fill(),Y.restore()}Y.restore()},renderDOM(Y,te){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=re(),D.title="Play / Pause",D.addEventListener("click",()=>N()),m.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=Te(),E.title="Stop",E.addEventListener("click",()=>I()),m.appendChild(E);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const Q=document.createElement("div");Q.style.display="flex",Q.style.flexDirection="column",Q.style.alignItems="center",Q.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",Q.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),Q.appendChild(de),m.appendChild(Q);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const B of Object.keys(jn)){const z=document.createElement("option");z.value=B,z.textContent=B.charAt(0).toUpperCase()+B.slice(1),B===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const be=document.createElement("div");be.className="ng-son-sep",m.appendChild(be);const ve=document.createElement("div");ve.style.display="flex",ve.style.flexDirection="column",ve.style.alignItems="center",ve.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",ve.appendChild(X);const _=document.createElement("input");_.type="range",_.className="ng-son-slider",_.min="0",_.max="100",_.value=String(Math.round(i*100)),_.addEventListener("input",()=>{i=Number(_.value)/100,u&&(u.gain.value=i)}),ve.appendChild(_),m.appendChild(ve),Y.appendChild(m)}if(!T){T=document.createElement("div"),T.className="ng-sonification-waveform ng-hidden",S=document.createElement("canvas"),k=S.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,Q=Y.getBoundingClientRect();S.width=Q.width*j,S.height=Zn*j,S.style.width="100%",S.style.height=Zn+"px",k&&k.scale(j,j),T.appendChild(S),Y.appendChild(T)}},destroy(){for(const Y of C)Y();C.length=0,I(),W(),l&&(l.close(),l=null),u=null,c=null,h=null,m&&(m.remove(),m=null),T&&(T.remove(),T=null),S=null,k=null,D=null,E=null,bd(),a=null,M=[],A=[]}}}const wd=.55,Sd=[4,3],kd=1,Dd=4,Ed=600;function Cd(e={}){let t=null;const n=pi(e.futureFadeStrength??wd,0,1),s=e.futureDashedBorder!==!1,o=e.futureDashPattern??Sd,i=e.futureDashWidth??kd,a=e.pastShowCheckmark!==!1,l=e.todayProvider??(()=>new Date);return{name:"TemporalAsymmetryPlugin",install(u){t=u},renderCanvas(u,c,h){if(!t||h.length===0)return;const{config:p,scrollX:r,scrollY:d,tasks:f}=c,{theme:w}=p,v=p.headerHeight,g=w.barBorderRadius,y=l();let b;try{b=t.getTimeScale().dateToX(y)}catch{return}const m=e.futureFadeColor??w.timelineBg??"#ffffff",T=typeof window<"u"&&window.devicePixelRatio||1,S=u.canvas.width/T,k=u.canvas.height/T;u.save();const D=v,E=k-D;u.beginPath(),u.rect(0,D,S,E),u.clip(),u.translate(-r,0);for(const C of h){if(C.isMilestone)continue;const M=f.get(C.taskId);if(!M||M.status==="group-header")continue;const A=C.x,R=C.barY-d,O=C.width,$=C.barHeight;if(R+$<0||R>E)continue;const P=A+O,x=A>=b,W=P<=b,K=!x&&!W;if(x||K){const q=x?A:b,F=x?O:P-b;F>.5&&(u.save(),u.beginPath(),mi(u,A,R,O,$,g),u.clip(),u.globalAlpha=n,u.fillStyle=m,u.fillRect(q,R,F,$),u.restore())}if(s&&(x||K)){const q=e.futureDashColor??Md(C.color,.4);if(u.save(),u.lineWidth=i,u.strokeStyle=q,u.setLineDash(o),x)Id(u,A,R,O,$,g);else{const F=R+.5,I=R+$-.5;u.beginPath(),u.moveTo(b,F),u.lineTo(P-g,F),u.moveTo(b,I),u.lineTo(P-g,I),u.moveTo(b,R),u.lineTo(b,R+$),u.stroke()}u.setLineDash([]),u.restore()}if(a&&W&&(M.progress??0)>=1){const q=A+Dd+5,F=R+$/2,I=e.pastCheckmarkColor??Ad(C.color);u.save(),u.font=`${Ed} ${Math.max(10,w.fontSize-1)}px ${w.fontFamily}`,u.textBaseline="middle",u.textAlign="left",u.fillStyle=I,u.fillText("✓",q-5,F),u.restore()}}u.restore()},destroy(){t=null}}}function pi(e,t,n){return Math.max(t,Math.min(n,e))}function mi(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.quadraticCurveTo(t+s,n,t+s,n+a),e.lineTo(t+s,n+o-a),e.quadraticCurveTo(t+s,n+o,t+s-a,n+o),e.lineTo(t+a,n+o),e.quadraticCurveTo(t,n+o,t,n+o-a),e.lineTo(t,n+a),e.quadraticCurveTo(t,n,t+a,n)}function Id(e,t,n,s,o,i){e.beginPath(),mi(e,t,n,s,o,i),e.stroke()}function Md(e,t){const n=yi(e);if(!n)return e;const s=Math.round((n.r+n.g+n.b)/3),o=i=>Math.round(i*(1-t)+s*t);return Ld(o(n.r),o(n.g),o(n.b))}function Ad(e){const t=yi(e);return t?.299*t.r+.587*t.g+.114*t.b>140?"#1f2937":"#ffffff":"#1f2937"}function yi(e){const t=e.replace("#","");return t.length===3?{r:parseInt(t[0]+t[0],16),g:parseInt(t[1]+t[1],16),b:parseInt(t[2]+t[2],16)}:t.length===6?{r:parseInt(t.substring(0,2),16),g:parseInt(t.substring(2,4),16),b:parseInt(t.substring(4,6),16)}:null}function Ld(e,t,n){const s=o=>pi(o,0,255).toString(16).padStart(2,"0");return`#${s(e)}${s(t)}${s(n)}`}const Rd=5e3,Pd=3e4,_d=500,$d=new Set(["SET_DATA","UPDATE_TASK","ADD_TASK","REMOVE_TASK","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function st(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}})}function Od(e={}){const t=Math.max(100,e.capacity??Rd),n=e.compactAfterIdleMs??Pd,s=Math.min(t,Math.max(50,e.compactKeep??_d)),o=[],i=[];let a=null,l=null,u=null,c=null;function h(){c&&clearTimeout(c),c=setTimeout(p,n)}function p(){if(o.length<=s)return;const y=o.length-s;o.splice(0,y),st("history:compaction",{dropped:y,kept:o.length})}function r(y){var b;if(o.push(y),st("history:entry-recorded",{actionType:y.action.type,ts:y.wallTs,source:y.source}),o.length>t){const m=o.splice(0,1);st("history:overflow-drop",{ts:(b=m[0])==null?void 0:b.wallTs})}if(h(),e.onEntry)try{const m=e.onEntry(y);m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}e.hydrate&&o.push(...e.hydrate),e.hydrateAnnotations&&i.push(...e.hydrateAnnotations);function d(y,b){switch(b.type){case"SET_DATA":{const m=Array.from(y.tasks.values()),T=Array.from(y.dependencies.values());return{type:"SET_DATA",tasks:m,dependencies:T}}case"UPDATE_TASK":{const m=y.tasks.get(b.taskId);if(!m)return null;const T={};for(const S of Object.keys(b.changes))T[S]=m[S];return{type:"UPDATE_TASK",taskId:b.taskId,changes:T}}case"ADD_TASK":return{type:"REMOVE_TASK",taskId:b.task.id};case"REMOVE_TASK":{const m=y.tasks.get(b.taskId);return m?{type:"ADD_TASK",task:m}:null}case"TASK_MOVE":case"TASK_RESIZE":{const m=y.tasks.get(b.taskId);return m?{type:b.type,taskId:b.taskId,startDate:m.startDate,endDate:m.endDate}:null}case"ADD_DEPENDENCY":return{type:"REMOVE_DEPENDENCY",dependencyId:b.dependency.id};case"REMOVE_DEPENDENCY":{const m=y.dependencies.get(b.dependencyId);return m?{type:"ADD_DEPENDENCY",dependency:m}:null}default:return null}}function f(y,b){if(!$d.has(y.type)){b(y);return}const m=a?a():null;if(!m){b(y);return}const T=d(m,y);b(y);const S=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),k=Date.now();r({ts:S,wallTs:k,action:y,inverse:T,actor:e.defaultActor,source:e.defaultSource??"local"})}function w(y){if(!a)return null;const b=y.getTime(),m=a();if(o.length===0)return m;const T=o[0].wallTs;if(b<T)return st("history:snapshot-miss",{target:b,baselineTs:T}),null;const S=new dn(m);for(let k=o.length-1;k>=0;k--){const D=o[k];if(D.wallTs<=b)break;D.inverse&&S.dispatch(D.inverse)}return S.getState()}function v(y){const b=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),m=Date.now(),T={ts:b,wallTs:m,...y};if(i.push(T),st("history:annotation-added",{kind:T.kind,taskId:T.taskId}),e.onAnnotation)try{const S=e.onAnnotation(T);S&&typeof S.catch=="function"&&S.catch(()=>{})}catch{}}const g={entries:()=>o,annotations:()=>i,snapshotAt:w,appendAnnotation:v,lastWallTs:()=>o.length>0?o[o.length-1].wallTs:null,scrubTo:y=>{l==null||l.setTimeCursor(y),st("history:scrub",{cursorWallTs:y?y.getTime():null})},scrubToNow:()=>{l==null||l.setTimeCursor(null),st("history:scrub",{cursorWallTs:null})}};return{name:"HistoryPlugin",install(y){a=y.getState,l=y.__gantt??null,l&&(l.history=g,typeof l.registerReplayProvider=="function"&&(u=l.registerReplayProvider({snapshotAt:b=>w(b)}))),st("history:hydrate",{entryCount:o.length})},middleware:f,destroy(){c&&(clearTimeout(c),c=null),u&&(u(),u=null),l&&l.history===g&&(l.history=null),l=null}}}const Nd="#3b82f6",Hd=2,xd="#10b981",Bd=864e5;function Fd(e={}){let t=null,n=null,s=null;const o=e.cursorColor??Nd,i=e.cursorWidth??Hd,a=e.showNowBracket!==!1,l=e.nowBracketColor??xd,u=e.enableKeyboardShortcuts!==!1,c=e.stepMs??Bd;function h(d){if(!n)return;const w=n.getTimeCursor()??new Date,v=new Date(w.getTime()+d);n.setTimeCursor(v)}function p(){if(!(n!=null&&n.history))return;const d=n.history.entries();d.length!==0&&n.setTimeCursor(new Date(d[0].wallTs))}function r(d){const f=document.activeElement;if(!(f&&(f.tagName==="INPUT"||f.tagName==="TEXTAREA"||f.isContentEditable))){if(d.key==="Home"){d.preventDefault(),p();return}if(d.key==="End"){d.preventDefault(),n==null||n.setTimeCursor(null);return}if(d.key==="ArrowLeft"&&(d.altKey||d.metaKey)){d.preventDefault(),h(-c);return}if(d.key==="ArrowRight"&&(d.altKey||d.metaKey)){d.preventDefault(),h(c);return}}}return{name:"TimeCursorPlugin",install(d){t=d,n=d.__gantt??null,u&&typeof document<"u"&&(s=r,document.addEventListener("keydown",s))},renderCanvas(d,f,w){if(!t)return;const{config:v,scrollX:g}=f,y=v.headerHeight,b=typeof window<"u"&&window.devicePixelRatio||1,m=d.canvas.width/b,T=d.canvas.height/b,S=y,k=T-S;let D;try{D=t.getTimeScale()}catch{return}if(d.save(),d.beginPath(),d.rect(0,S,m,k),d.clip(),d.translate(-g,0),a){const C=D.dateToX(new Date);d.save(),d.strokeStyle=l,d.lineWidth=3,d.beginPath(),d.moveTo(C-6,S+1),d.lineTo(C+6,S+1),d.moveTo(C-6,S+k-1),d.lineTo(C+6,S+k-1),d.stroke(),d.restore()}const E=f.timeCursorDate;if(E){const C=D.dateToX(E);d.save(),d.strokeStyle=o,d.lineWidth=i,d.beginPath(),d.moveTo(C,S),d.lineTo(C,S+k),d.stroke(),d.fillStyle=o,d.beginPath(),d.moveTo(C-6,S),d.lineTo(C+6,S),d.lineTo(C,S+8),d.closePath(),d.fill(),d.restore()}d.restore()},destroy(){s&&typeof document<"u"&&document.removeEventListener("keydown",s),s=null,t=null,n=null}}}const Ud=14,Yd=4,Wd=6,Xd="#6b7280",zd={comment:"#3b82f6",decision:"#8b5cf6","agent-note":"#10b981",view:"#a3a3a3"};function Gd(e={}){let t=null,n=null;const s=e.height??Ud,o=e.position??"above-body",i=e.markerRadius??Yd,a=e.clusterDistancePx??Wd,l=e.fallbackColor??Xd,u={...zd,...e.colorByKind??{}};return{name:"HistoryStripPlugin",install(c){t=c,n=c.__gantt??null},renderCanvas(c,h,p){if(!t||!(n!=null&&n.history))return;const r=n.history.annotations();if(r.length===0)return;const{config:d,scrollX:f}=h,w=d.headerHeight,v=typeof window<"u"&&window.devicePixelRatio||1,g=c.canvas.width/v;let y;try{y=t.getTimeScale()}catch{return}const b=o==="above-body"?w-s:w+2;c.save(),c.beginPath(),c.rect(0,b,g,s),c.clip(),c.translate(-f,0);const m=[];for(const k of r){const D=y.dateToX(new Date(k.wallTs));m.push({x:D,ann:k})}m.sort((k,D)=>k.x-D.x);const T=[];for(const k of m){const D=T[T.length-1];D&&Math.abs(k.x-D.x)<=a?(D.entries.push(k),D.x=D.entries.reduce((E,C)=>E+C.x,0)/D.entries.length):T.push({x:k.x,entries:[k]})}const S=[];for(const k of T){const D=b+s/2,E=k.entries.length>1,C=k.entries[0].ann.kind,M=u[C]??l;c.fillStyle=M,c.beginPath(),c.arc(k.x,D,E?i+1:i,0,Math.PI*2),c.fill(),E&&(c.fillStyle="#ffffff",c.font="600 9px sans-serif",c.textBaseline="middle",c.textAlign="center",c.fillText(String(k.entries.length),k.x,D+.5)),S.push({cx:k.x,cy:D,r:E?i+1:i,annotations:k.entries.map(A=>A.ann)})}c.restore()},destroy(){t=null,n=null}}}const Ti="nimbus-gantt-ctxmenu-styles",pe="ng-ctxmenu",bi={maxCalls:1,windowMs:2e3};function Vd(e){if(e===!1)return()=>!0;const t=e??bi,n=[];return function(){const o=Date.now(),i=o-t.windowMs;for(;n.length>0&&n[0]<i;)n.shift();return n.length>=t.maxCalls?!1:(n.push(o),!0)}}function vi(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:Date.now(),kind:e,...t??{}})}function Kd(e={}){let t=null,n=null,s=null,o=null,i=null,a=null;const l=Vd(e.agentRateLimit===void 0?bi:e.agentRateLimit);async function u(g,y){if(e.onConfirmDestructive)try{return!!await e.onConfirmDestructive(g,y)}catch{return!1}if(typeof window<"u"&&typeof window.confirm=="function"){const b=g==="task"?`Delete task "${y}"?`:`Delete dependency "${y}"?`;try{return window.confirm(b)}catch{return!1}}return!0}function c(){if(typeof document>"u"||document.getElementById(Ti))return;const g=document.createElement("style");g.id=Ti,g.textContent=`
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
    `,document.head.appendChild(g)}function h(){if(s){try{s.remove()}catch{}s=null}a&&typeof document<"u"&&(document.removeEventListener("pointerdown",a,!0),document.removeEventListener("keydown",a,!0),a=null)}function p(g,y,b){if(typeof document>"u"||g.length===0)return;h(),c();const m=document.createElement("div");m.className=pe,m.setAttribute("role","menu"),m.style.left=`${y.x}px`,m.style.top=`${y.y}px`,m.addEventListener("pointerdown",T=>{T.stopPropagation()});for(const T of g){if(T.divider){const E=document.createElement("div");E.className=`${pe}-divider`,m.appendChild(E);continue}const S=document.createElement("div");S.className=`${pe}-item`,T.disabled&&S.setAttribute("aria-disabled","true");const k=document.createElement("span");k.className=`${pe}-icon`,T.agentSuggested&&k.classList.add(`${pe}-agent-glyph`),k.textContent=T.icon??(T.agentSuggested?"✦":""),S.appendChild(k);const D=document.createElement("span");if(D.className=`${pe}-label`,D.textContent=T.label,S.appendChild(D),T.shortcut){const E=document.createElement("span");E.className=`${pe}-shortcut`,E.textContent=T.shortcut,S.appendChild(E)}if(T.children&&T.children.length>0){const E=document.createElement("span");E.className=`${pe}-arrow`,E.textContent="▸",S.appendChild(E);let C=null;S.addEventListener("mouseenter",()=>{if(C)return;const M=S.getBoundingClientRect();C=document.createElement("div"),C.className=pe,C.style.left=`${M.right+2}px`,C.style.top=`${M.top}px`;for(const A of T.children){const R=r(A,b);C.appendChild(R)}document.body.appendChild(C)}),S.addEventListener("mouseleave",()=>{if(C){try{C.remove()}catch{}C=null}})}else T.disabled||S.addEventListener("click",E=>{E.stopPropagation(),d(T,b,y)});m.appendChild(S)}document.body.appendChild(m),s=m,a=T=>{T instanceof KeyboardEvent&&T.key!=="Escape"||T.type==="pointerdown"&&T.target instanceof Element&&T.target.closest(`.${pe}`)||h()},document.addEventListener("pointerdown",a,!0),document.addEventListener("keydown",a,!0),requestAnimationFrame(()=>{if(!s)return;const T=s.getBoundingClientRect(),S=window.innerWidth,k=window.innerHeight;let D=T.left,E=T.top;T.right>S&&(D=Math.max(4,S-T.width-4)),T.bottom>k&&(E=Math.max(4,k-T.height-4)),s.style.left=`${D}px`,s.style.top=`${E}px`})}function r(g,y){if(g.divider){const S=document.createElement("div");return S.className=`${pe}-divider`,S}const b=document.createElement("div");b.className=`${pe}-item`,g.disabled&&b.setAttribute("aria-disabled","true");const m=document.createElement("span");m.className=`${pe}-icon`,g.agentSuggested&&m.classList.add(`${pe}-agent-glyph`),m.textContent=g.icon??(g.agentSuggested?"✦":""),b.appendChild(m);const T=document.createElement("span");return T.className=`${pe}-label`,T.textContent=g.label,b.appendChild(T),g.disabled||b.addEventListener("click",S=>{S.stopPropagation(),d(g,y,{x:0,y:0})}),b}function d(g,y,b){if(h(),g.agentSuggested&&g.prompt&&e.onAgentRequest&&(t!=null&&t.agent)){if(!l()){vi("ctxmenu:agent-rate-limited",{itemId:g.id});return}const m={hit:y,pos:b,prompt:g.prompt,snapshot:t.agent.getSnapshot()};try{const T=e.onAgentRequest(m);T&&typeof T.catch=="function"&&T.catch(()=>{})}catch{}return}if(g.onClick)try{const m=g.onClick();m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}function f(g,y,b){return async()=>{await u(g,y)?b():vi("ctxmenu:destructive-cancelled",{kind:g,label:y})}}function w(g,y){const b=[],m=!!e.onAgentRequest&&!e.hideAgentSubmenu;switch(g.zone){case"bar":return b.push({id:"edit",label:"Edit task…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",g.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",g.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",g.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",g.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",g.task,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-why",label:"Ask Claude: why is this scheduled here?",agentSuggested:!0,prompt:`Explain why task "${g.task.name}" (id ${g.task.id}) is scheduled from ${g.task.startDate} to ${g.task.endDate} given current dependencies, parent context, and bucket assignment.`},{id:"agent-blocks",label:"Ask Claude: what blocks this?",agentSuggested:!0,prompt:`What dependencies, capacity constraints, or upstream blockers are gating task "${g.task.name}" (id ${g.task.id})? Walk the dependency graph and list the critical path.`},{id:"agent-resched",label:"Ask Claude: reschedule with critical-path optimization",agentSuggested:!0,prompt:`Suggest a new schedule for task "${g.task.name}" (id ${g.task.id}) that optimizes the critical path. Stage hypotheses via gantt.agent if possible.`}),b;case"row-label":return b.push({id:"edit",label:"Edit name…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",g.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",g.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",g.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",g.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",g.task,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-summarize",label:"Ask Claude: summarize this task",agentSuggested:!0,prompt:`Summarize task "${g.task.name}" (id ${g.task.id}) including its current status, parent, dependencies, and recent history if available.`}),b;case"date-header":{const T=g.date.toISOString().slice(0,10);return b.push({id:"scroll-here",label:`Scroll to ${T}`,icon:"↔",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"scroll-here",g.date,y)}},{id:"zoom-to",label:"Zoom to this range",icon:"⊕",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"zoom-to",g.date,y)}},{id:"add-milestone",label:`Add milestone on ${T}`,icon:"◆",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"add-milestone",g.date,y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-summary",label:`Ask Claude: what's happening around ${T}?`,agentSuggested:!0,prompt:`Summarize tasks, milestones, and dependencies that intersect ${T}. Note any clusters, conflicts, or capacity hotspots.`}),b}case"canvas-empty":{const T=g.date.toISOString().slice(0,10),S=T,k=(()=>{const D=new Date(g.date);return D.setUTCDate(D.getUTCDate()+5),D.toISOString().slice(0,10)})();return b.push({id:"create-task",label:`Create work item starting ${T}`,icon:"＋",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:S,endDate:k,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},y)}},{id:"create-milestone",label:`Insert milestone on ${T}`,icon:"◆",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:T,endDate:T,parentId:((D=g.nearestTask)==null?void 0:D.parentId)??null,bucket:g.bucketId},y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-suggest",label:"Ask Claude: suggest a task here",agentSuggested:!0,prompt:`Given the project context and the dates around ${T}${g.bucketId?` in bucket "${g.bucketId}"`:""}, suggest a sensible work item to insert. Consider open dependencies, capacity, and priority.`}),b}case"bucket-header":{const T=g.bucketTask.name||g.bucketId||"(bucket)";return b.push({id:"add-to-bucket",label:`Add task to ${T}`,icon:"＋",onClick:()=>{var S;return(S=e.onCreateTask)==null?void 0:S.call(e,{startDate:new Date().toISOString().slice(0,10),endDate:new Date(Date.now()+432e6).toISOString().slice(0,10),parentId:g.bucketTask.id,bucket:g.bucketId},y)}},{id:"collapse",label:`Collapse all in ${T}`,icon:"⊟",onClick:()=>{var S;return(S=e.onTaskAction)==null?void 0:S.call(e,"collapse",g.bucketTask,y)}},{id:"expand",label:`Expand all in ${T}`,icon:"⊞",onClick:()=>{var S;return(S=e.onTaskAction)==null?void 0:S.call(e,"expand",g.bucketTask,y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-rebalance",label:`Ask Claude: rebalance ${T}`,agentSuggested:!0,prompt:`Review the tasks in bucket "${T}" for capacity, sequencing, and priority alignment. Suggest moves to/from adjacent buckets and reordering within.`}),b}case"below-rows":{const T=g.date.toISOString().slice(0,10);return b.push({id:"create-end",label:`Add new task at end (starts ${T})`,icon:"＋",onClick:()=>{var S;return(S=e.onCreateTask)==null?void 0:S.call(e,{startDate:T,endDate:new Date(g.date.getTime()+432e6).toISOString().slice(0,10),parentId:null,bucket:null},y)}}),b}case"dependency":return b.push({id:"change-fs",label:"Change type → Finish-to-Start (FS)",icon:"→",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-fs",g.depId,y)}},{id:"change-ss",label:"Change type → Start-to-Start (SS)",icon:"↦",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ss",g.depId,y)}},{id:"change-ff",label:"Change type → Finish-to-Finish (FF)",icon:"↤",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ff",g.depId,y)}},{id:"change-sf",label:"Change type → Start-to-Finish (SF)",icon:"↔",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-sf",g.depId,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete dependency",icon:"×",onClick:f("dependency",g.depId,()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"delete",g.depId,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-explain-dep",label:"Ask Claude: is this dependency necessary?",agentSuggested:!0,prompt:`Evaluate dependency ${g.depId}. Is it logically required, or could the predecessor and successor run in parallel? Consider data flow, resource contention, and external constraints.`}),b;case"outside":default:return[]}}function v(g){if(!t||!n||g.button!==void 0&&g.button!==2)return;const y=t.hitTestAt(g.clientX,g.clientY);if(y.zone==="outside")return;g.preventDefault(),g.stopPropagation();const b={x:g.clientX,y:g.clientY};let m=null;if(e.onContextMenu)try{m=e.onContextMenu(y,b)}catch{m=null}const T=m&&Array.isArray(m)&&m.length>0?m:w(y,b);T.length>0&&p(T,b,y)}return{name:"ContextMenuPlugin",install(g){t=g.__gantt??null,n=(t&&t.rootEl)??null;const y=n??(typeof document<"u"?document:null);y&&(o=b=>v(b),y.addEventListener("contextmenu",o),e.disablePointerDownFallback||(i=b=>{b.button===2&&v(b)},y.addEventListener("pointerdown",i)))},destroy(){h();const g=n??(typeof document<"u"?document:null);g&&(o&&g.removeEventListener("contextmenu",o),i&&g.removeEventListener("pointerdown",i)),o=null,i=null,t=null,n=null}}}return J.AutoSchedulePlugin=Nr,J.BaselinePlugin=xa,J.CLOUD_NIMBUS_PRIORITY_BUCKETS=wa,J.ConfigPanelPlugin=Pl,J.ContextMenuPlugin=Kd,J.CriticalPathPlugin=Ma,J.DARK_THEME=ys,J.DarkThemePlugin=Qa,J.DependencyRenderer=fs,J.EventBus=ns,J.ExportPlugin=Ga,J.GroupingPlugin=ya,J.HeatmapViewPlugin=Wl,J.HistoryPlugin=Od,J.HistoryStripPlugin=Gd,J.HitTest=us,J.KeyboardPlugin=Qi,J.LIGHT_THEME=fn,J.LayoutEngine=rs,J.MSProjectPlugin=mr,J.MilestonePlugin=aa,J.MiniMapPlugin=tc,J.MonteCarloPlugin=Yc,J.MotionControlPlugin=dr,J.NarrativePlugin=Jc,J.NetworkGraphPlugin=Cl,J.NimbusGantt=Gi,J.PriorityGroupingPlugin=va,J.ResourceLevelingPlugin=Or,J.RiskAnalysisPlugin=ll,J.SonificationPlugin=vd,J.SplitTaskPlugin=Cr,J.TelemetryPlugin=rr,J.TemporalAsymmetryPlugin=Cd,J.TimeCursorPlugin=Fd,J.TimeScale=is,J.TimeTravelPlugin=Ac,J.TimelineNotesPlugin=Tc,J.TooltipManager=ms,J.UndoRedoPlugin=Zi,J.VirtualScrollPlugin=Ya,J.WhatIfPlugin=cd,J.WorkCalendarPlugin=or,J.buildDependencyGraph=lo,J.computeCPM=Tn,J.computeSchedule=co,J.exportMSProjectXML=In,J.getAllParentIds=vs,J.getDescendantIds=ws,J.hoursWeightedProgress=Sa,J.importMSProjectXML=Cn,J.parseDate=yt,J.resolveConfig=Ts,J.rollupHoursDeduped=ji,Object.defineProperty(J,Symbol.toStringTag,{value:"Module"}),J})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
