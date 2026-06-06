var NimbusGantt=(function(J){"use strict";function Ue(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(u);d||(d=[],n.set(u,d)),d.push(l)}const s=[];function o(l,u){const d=l.sortOrder??Number.MAX_SAFE_INTEGER,g=u.sortOrder??Number.MAX_SAFE_INTEGER;return d!==g?d-g:l.name.localeCompare(u.name)}function i(l,u,d){const g=n.get(l);return g?(g.sort(o),g.map(p=>{const c=n.has(p.id)&&t.has(p.id),f=d,S={task:p,children:[],depth:u,expanded:c,visible:f,rowIndex:-1};return f&&(S.rowIndex=s.length,s.push(p.id)),S.children=i(p.id,u+1,f&&c),S})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function yt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class un{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=Ci(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function Ci(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Ue(n,e.expandedIds),a=yt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Ue(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Ue(n,e.expandedIds),i=yt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Ue(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=yt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};case"SET_TIME_CURSOR":return{...e,timeCursorDate:t.date};default:return e}}function ss(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class os{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const gn=864e5,Ii=gn*7,Mi={day:40,week:120,month:180,quarter:200},is=["January","February","March","April","May","June","July","August","September","October","November","December"],as=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class rs{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=Mi[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/gn)}countWeeks(){return Math.ceil(this.totalMs/Ii)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=ls(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=hn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${is[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=ls(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${as[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=hn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),d=this.dateToX(l);t.push({label:`${is[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:d-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:as[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=hn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),g=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:g-d,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=Ai(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,d=this.dateToX(l),g=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:d,width:g-d,date:new Date(l)}),i=a}return[t,n]}}function ls(e,t){return new Date(e.getTime()+t*gn)}function Ai(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function hn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class cs{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const d=bt(u.startDate),g=bt(u.endDate),p=s.dateToX(d),r=s.dateToX(g)-p,c=Math.max(r,o.minBarWidth),f=a*o.rowHeight,S=f+(o.rowHeight-o.barHeight)/2,v=c*(u.progress||0),h=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:f,width:c,barY:S,barHeight:o.barHeight,progressWidth:v,color:h,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function bt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Pt=864e5,ds=1,Li=2,Ri=.5,Pi=2,us=8,$i=6,fn=2;class _i{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:d}=u,g=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=u.headerHeight,f=a-c;this.fillRect(0,0,i,a,d.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,f),o.clip(),o.translate(-g,0),u.showWeekends&&this.renderWeekendShading(t,s,c,f,d),this.renderGridLines(s,c,f,d,g),this.renderAltRows(t,n,c,d,g,p);const S=this.getTodayX(t,u,s);u.showToday&&S!==null&&this.renderTodayBackground(S,s,c,f,d),this.renderGroupRowBgs(t,n,u,g,p,c,f),this.renderTaskBars(t,n,u,d,g,p,c,f),this.renderDragSnapGuide(t,n,s,c,f,d),u.showToday&&S!==null&&this.renderTodayLine(S,c,f,d),o.restore(),this.renderHeader(s,u,d,g)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const d=l.getTime();for(;u.getTime()<=d;){const g=u.getUTCDay();if(g===0||g===6){const p=n.dateToX(u),r=new Date(u.getTime()+Pt),f=n.dateToX(r)-p;this.fillRect(p,s,f,o,i.timelineWeekendBg)}u.setTime(u.getTime()+Pt)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=Ri;for(const u of l){const d=this.snapToPixel(u);a.moveTo(d,n),a.lineTo(d,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,d=t.config.rowHeight,g=t.flatVisibleIds.length;for(let p=0;p<g;p++)if(p%2===1){const r=s+p*d-a;if(r+d<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,d,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+Pt),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:u,displayWidth:d}=this,g=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const c=p.y-i+a;c+g<a||c>a+l||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,c,d,g),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,c,d,2)),u.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const l=t.dragState;if(!l||l.type!=="move"&&l.type!=="resize-left"&&l.type!=="resize-right")return;const u=n.find(v=>v.taskId===l.taskId);if(!u)return;const d=new Date;d.setHours(0,0,0,0);const g=new Date(d.getTime()+Pt),p=s.dateToX(g)-s.dateToX(d);if(p<=0)return;const r=l.currentX-l.startX;let c;l.type==="move"||l.type==="resize-left"?c=u.x+r:c=u.x+u.width+r;const f=Math.round(c/p)*p,{ctx:S}=this;S.save(),S.strokeStyle=a.barSelectedBorder||"#3b82f6",S.lineWidth=1,S.setLineDash([4,3]),S.globalAlpha=.85,S.beginPath(),S.moveTo(f+.5,o),S.lineTo(f+.5,o+i),S.stroke(),S.restore()}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:d}=this,g=o.barBorderRadius,p=t.dragState,r=p?p.currentX-p.startX:0,c=4;for(const f of n){let S=f.x;const v=f.barY-a+l;let h=f.width;const y=f.barHeight;if(v+y<l||v>l+u)continue;const b=p&&p.taskId===f.taskId;if(b){if(p.type==="move")S+=r;else if(p.type==="resize-left"){const k=S+r,D=h-r;D>=c&&(S=k,h=D)}else if(p.type==="resize-right"){const k=h+r;k>=c&&(h=k)}}if(f.isMilestone){this.renderMilestone(S,v,y,f.color,o,t.selectedIds.has(f.taskId));continue}const m=t.tasks.get(f.taskId),T=m&&m.status!=="group-header"&&m.style?m.style:null,w=T?this.resolveFillOpacity(T):1;if(w<1?(d.save(),d.globalAlpha=w,this.fillRoundedRect(S,v,h,y,g,f.color),d.restore()):this.fillRoundedRect(S,v,h,y,g,f.color),s.showProgress&&f.progressWidth>0){const k=this.darkenColor(f.color,.2);d.save(),d.beginPath(),this.roundedRectPath(S,v,h,y,g),d.clip(),d.fillStyle=k,d.fillRect(S,v,f.progressWidth,y),d.restore()}t.selectedIds.has(f.taskId)&&this.strokeRoundedRect(S,v,h,y,g,o.barSelectedBorder,fn),b&&this.strokeRoundedRect(S,v,h,y,g,o.barSelectedBorder,fn),T&&T.borderStyle&&T.borderStyle!=="none"&&this.renderDecoratorBorder(T,S,v,h,y,g,f.color),this.renderBarLabel(f,S,v,h,y,o),T&&T.badge&&T.badge.text&&this.renderDecoratorBadge(T.badge,S,v,h,y,f.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,l){const{ctx:u}=this,d=t.borderWidth??2,g=t.borderColor??this.darkenColor(l,.3),p=t.borderStyle??"solid";let r;switch(p){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(u.save(),u.setLineDash(r),u.strokeStyle=g,u.lineWidth=d,this.roundedRectPath(n,s,o,i,a),u.stroke(),p==="double"){const c=d+1,f=Math.max(0,a-c);u.lineWidth=d,this.roundedRectPath(n+c,s+c,Math.max(0,o-c*2),Math.max(0,i-c*2),f),u.stroke()}u.restore()}renderDecoratorBadge(t,n,s,o,i,a,l){const{ctx:u}=this,d=t.text,g=t.placement??"end",p=Math.max(14,i*.65),r=6;u.save();const c=`${Math.round(l.fontSize*.85)}px ${l.fontFamily}`;u.font=c,u.textBaseline="middle";const S=u.measureText(d).width+r*2,v=s+(i-p)/2,h=g==="start"?n+2:n+o-S-2;u.shadowColor="rgba(0,0,0,0.25)",u.shadowBlur=3,u.shadowOffsetY=1;const y=t.color??"#ffffff";u.fillStyle=y,this.roundedRectPath(h,v,S,p,p/2),u.fill(),u.shadowColor="transparent",u.shadowBlur=0,u.shadowOffsetY=0,u.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),u.textAlign="center",u.fillText(d,h+S/2,v+p/2),u.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-Pi*2)/2,d=n+s/2;l.save(),l.beginPath(),l.moveTo(t,d-u),l.lineTo(t+u,d),l.lineTo(t,d+u),l.lineTo(t-u,d),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=fn,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const d=l.measureText(t.label).width,g=s+i/2;d+us*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+us,g)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+$i,g)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=Li,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const d=u.length||2,g=l/d,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<u.length;c++){const f=u[c],S=c*g;for(const v of f){const h=v.x-o,y=v.width;if(h+y<0||h>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=ds;const b=this.snapToPixelRaw(h+y);i.moveTo(b,S),i.lineTo(b,S+g),i.stroke(),i.save(),i.beginPath(),i.rect(h,S,y,g),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(v.label,h+y/2,S+g/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=ds,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const gs="ng-tree-grid-styles";function Ni(e,t){const n=e.querySelector(`#${gs}`);n&&n.remove();const s=document.createElement("style");s.id=gs,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function Oi(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function $t(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class Hi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;Ni(this.rootEl,a),this.columns=o,this.columnWidths=o.map(d=>d.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=Oi(n),u=l.map(d=>d.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=a.header,u.appendChild(d);const g=document.createElement("span");g.className="ng-resize-handle",u.appendChild(g),this.attachResizeListener(g,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=d=>{const g=d.clientX-o,p=Math.max(a,i+g);this.columnWidths[n]=p;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),c[n]&&(c[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const d of t)l.set(d.task.id,d);for(const[d,g]of this.rows)a.has(d)||(g.remove(),this.rows.delete(d));let u=null;for(let d=0;d<t.length;d++){const g=t[d],p=g.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,g,d,s):(r=this.createRow(g,d,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const d=this.createCell(t,u,s);l.appendChild(d)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const d=document.createElement("span");d.className="ng-expand-icon",t.expanded&&d.classList.add("ng-expanded"),d.innerHTML="&#9654;",d.setAttribute("data-expand",t.task.id),o.appendChild(d)}else{const d=document.createElement("span");d.className="ng-expand-spacer",o.appendChild(d)}if(t.children.length===0&&!t.task.groupBg){const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",o.appendChild(d)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const d=document.createElement("span");d.className="ng-status-dot",d.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(d)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=$t(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=$t(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let d=0;d<a.length;d++){const g=a[d],p=l[d];if(!p){const r=this.createCell(n,g,o);t.appendChild(r);continue}if(g.tree){const c=`${n.depth*20+8}px`;p.style.paddingLeft!==c&&(p.style.paddingLeft=c);const f=p.querySelector(".ng-expand-icon"),S=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(f)n.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{S&&S.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(f){f.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const v=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!v){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const T=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");T?p.insertBefore(m,T):p.appendChild(m)}}else v&&v.remove();const h=p.querySelector(".ng-status-dot"),y=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(y&&n.children.length===0)if(h)h.style.background=y;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${y};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const T=p.querySelector(".ng-grid-cell-text");T?p.insertBefore(m,T):p.appendChild(m)}else h&&h.remove();const b=p.querySelector(".ng-grid-cell-text");if(b){const m=$t(n.task,g);b.textContent!==m&&(b.textContent=m)}}else if(g.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",p.appendChild(c)}}else r&&(p.textContent="")}else{const r=$t(n.task,g);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class xi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class hs{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const d=i+s.progressWidth;if(Math.abs(t-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const fs=864e5;function _t(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/fs)}function Tt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Oe(e,t){const n=Tt(e),s=new Date(n.getTime()+t*fs),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function ps(e,t,n){return Math.max(t,Math.min(n,e))}const Bi=3,Fi=300;class Ui{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new hs,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.panning){t.preventDefault();const l=t.clientX-this.panStartClientX,u=t.clientY-this.panStartClientY,d=this.options.scrollManager;if(d){const g=Math.max(0,this.panOrigScrollX-l),p=Math.max(0,this.panOrigScrollY-u);d.setScrollPosition(g,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const u=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=u.x,this.panOrigScrollY=u.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l){this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const u=Yi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=_t(i,o);let l="";if(this.dragHit.type==="bar"){const c=Oe(this.dragOriginalStartDate,a),f=Oe(this.dragOriginalEndDate,a);l=`${c} → ${f}`}else if(this.dragHit.type==="bar-left-edge")l=`Start → ${Oe(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")l=`End → ${Oe(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const c=this.dragHit.layout,{canvasX:f}=this.toCanvasCoords(t),S=f-c.x;l=`${Math.round(ps(S/c.width,0,1)*100)}%`}if(!l)return;if(!this.gestureLabelEl){const c=document.createElement("div");c.setAttribute("data-nga-gesture-label","1"),c.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(c),this.gestureLabelEl=c,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=l;const u=12,d=window.innerWidth||document.documentElement.clientWidth,g=this.gestureLabelEl.offsetWidth,p=Math.min(t.clientX+u,d-g-4),r=t.clientY+u;this.gestureLabelEl.style.left=`${p}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<Bi?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Fi){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var u,d,g,p,r,c,f,S,v,h;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,l=t.clientX-this.dragStartX;switch(a){case"bar":{const y=t.clientY-this.dragStartY,b=Math.abs(l),m=Math.abs(y),T=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),w=m>b*1.5&&m>12;if(T&&w){const C=this.options.getLayouts(),M=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),A=C.find(P=>P.rowIndex===M),R=A?A.taskId:null;let N=null;const _=C.slice().sort((P,x)=>P.rowIndex-x.rowIndex);for(const P of _){if(P.rowIndex>M)break;const x=P.taskId;typeof x=="string"&&x.indexOf("__bucket_header__")===0&&(N=x.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",M,"target=",R,"bucket=",N)}catch{}(d=(u=this.options).onBarReorderDrag)==null||d.call(u,s,R,M,N);break}const k=_t(l,o),D=Oe(this.dragOriginalStartDate,k),E=Oe(this.dragOriginalEndDate,k);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:D,endDate:E});try{console.log("[NG engine] drag commit move",s.id,D,E,"hasCb=",!!this.options.onTaskMove)}catch{}(p=(g=this.options).onTaskMove)==null||p.call(g,s,D,E);break}case"bar-left-edge":{const y=_t(l,o),b=Oe(this.dragOriginalStartDate,y),m=Tt(this.dragOriginalEndDate),w=Tt(b).getTime()>=m.getTime()?Oe(this.dragOriginalEndDate,-1):b;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:w,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,w,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(c=(r=this.options).onTaskResize)==null||c.call(r,s,w,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=_t(l,o),b=Oe(this.dragOriginalEndDate,y),m=Tt(this.dragOriginalStartDate),w=Tt(b).getTime()<=m.getTime()?Oe(this.dragOriginalStartDate,1):b;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:w});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,w,"hasCb=",!!this.options.onTaskResize)}catch{}(S=(f=this.options).onTaskResize)==null||S.call(f,s,this.dragOriginalStartDate,w);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:b}=this.toCanvasCoords(t),m=b-y.x,T=ps(m/y.width,0,1),w=Math.round(T*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:w}}),(h=(v=this.options).onTaskProgressChange)==null||h.call(v,s,w);break}}this.options.dispatch({type:"DRAG_END"})}}function Yi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const He=12,vt=6,Nt=4,Wi=3;class ms{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const d=new Map;for(const r of s)d.set(r.taskId,r);const g=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,g,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const c=d.get(r.source),f=d.get(r.target);if(!c||!f)continue;const S=r.type||"FS",{sourceX:v,sourceY:h,targetX:y,targetY:b}=this.getConnectionPoints(S,c,f,a,l);this.drawRoutedPath(t,S,v,h,y,b,o),this.drawArrowhead(t,S,y,b,o),this.drawConnectionDot(t,v,h,o),this.drawConnectionDot(t,y,b,o)}t.restore()}hitTest(t,n,s,o,i,a,l=8){const{dependencies:u}=s;if(u.size===0||n<a)return null;const d=new Map;for(const p of o)d.set(p.taskId,p);let g=null;for(const p of u.values()){const r=d.get(p.source),c=d.get(p.target);if(!r||!c)continue;const f=p.type||"FS",{sourceX:S,sourceY:v,targetX:h,targetY:y}=this.getConnectionPoints(f,r,c,i,a),b=t-h,m=n-y,T=Math.sqrt(b*b+m*m);if(T<=l+vt){(!g||T<g.dist)&&(g={depId:p.id,dist:T});continue}const w=f==="FS"||f==="SS"?h-He:h+He,k=Math.min(w,h),D=Math.max(w,h);if(t>=k-l&&t<=D+l&&Math.abs(n-y)<=l){const A=Math.abs(n-y);(!g||A<g.dist)&&(g={depId:p.id,dist:A})}const E=f==="FS"||f==="FF"?S+He:S-He,C=Math.min(S,E),M=Math.max(S,E);if(t>=C-l&&t<=M+l&&Math.abs(n-v)<=l){const A=Math.abs(n-v);(!g||A<g.dist)&&(g={depId:p.id,dist:A})}}return(g==null?void 0:g.depId)??null}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",d=n==="FS"||n==="SS",g=u?s+He:s-He,p=d?i-He:i+He;if(u?d?p>=g:i+He>=g:d?i-He<=g:p<=g)t.lineTo(g,o),t.lineTo(g,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(g,o),t.lineTo(g,c),t.lineTo(p,c),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-vt,o-Nt),t.lineTo(s-vt,o+Nt)):(t.moveTo(s,o),t.lineTo(s+vt,o-Nt),t.lineTo(s+vt,o+Nt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Wi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Ot=12,Xi=100,zi=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Gi=`
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
`;function at(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function ys(e){const t=e.split("-");if(t.length!==3)return at(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?at(e):`${zi[n]} ${s}`}function Me(e,t,n){const s=n?` ${n}`:"";return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${at(e)}</span><span class="ng-tooltip-value${s}">${at(t)}</span></div>`}function Ht(e){return Number.isInteger(e)?String(e):e.toFixed(1)}function bs(e,...t){var s;const n=e;for(const o of t){const i=n[o];if(typeof i=="number"&&!Number.isNaN(i))return i;const a=(s=e.metadata)==null?void 0:s[o];if(typeof a=="number"&&!Number.isNaN(a))return a}}function Vi(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.max(1,Math.round((s-n)/864e5)+1)}function Ts(e,...t){var n;for(const s of t){const o=(n=e.metadata)==null?void 0:n[s];if(typeof o=="string"&&o.length>0)return o}}function vs(e,t){const n=Date.parse(e),s=Date.parse(t);return Number.isNaN(n)||Number.isNaN(s)?null:Math.round((s-n)/864e5)}function Ss(e){return e===0?"on time":e>0?`+${e}d`:`−${Math.abs(e)}d`}function Ki(e,t,n){const s=Math.round((e.progress??0)*100),o=bs(e,"estimatedHours","estimateHours","hours"),i=bs(e,"loggedHours","actualHours");let a="";e.status&&(a+=Me("Status",e.status)),e.priority&&(a+=Me("Priority",e.priority)),a+=Me("Assignee",e.assignee||"Unassigned");const l=Vi(e.startDate,e.endDate),u=`${ys(e.startDate)} → ${ys(e.endDate)}`;a+=Me("Dates",l?`${u} (${l}d)`:u),s>0&&(a+=Me("Progress",`${s}%`));let d="";if(o!=null&&(d+=Me("Estimate",`${Ht(o)}h`)),i!=null&&(d+=Me("Logged",`${Ht(i)}h`)),o!=null&&i!=null&&o>0){const b=Math.round(i/o*100),m=i>o,T=o-i,w=m?`${b}% (${Ht(i-o)}h over)`:`${b}% (${Ht(T)}h left)`;d+=Me("Used",w,m?"ng-tooltip-over":void 0)}const g=n==null?void 0:n.depSummary;g&&(g.blocks>0||g.blockedBy>0)&&(g.blockedBy>0&&(a+=Me("Blocked by",`${g.blockedBy} task${g.blockedBy===1?"":"s"}`)),g.blocks>0&&(a+=Me("Blocks",`${g.blocks} task${g.blocks===1?"":"s"}`)));let p="";const r=Ts(e,"baselineStart","baselineStartDate"),c=Ts(e,"baselineEnd","baselineEndDate");if(r){const b=vs(r,e.startDate);b!=null&&(p+=Me("Start vs plan",Ss(b),b>0?"ng-tooltip-over":void 0))}if(c){const b=vs(c,e.endDate);b!=null&&(p+=Me("Finish vs plan",Ss(b),b>0?"ng-tooltip-over":void 0))}let f="";if(Array.isArray(e.tooltipRows))for(const b of e.tooltipRows)!b||typeof b.label!="string"||typeof b.value!="string"||(f+=Me(b.label,b.value,b.emphasis?"ng-tooltip-over":void 0));const S=`<div class="ng-tooltip-id" title="Work item ID">${at(e.id)}</div>`,v=e.title||e.name,h=`<div class="ng-tooltip-header" style="border-left: 3px solid ${at(t)}"><span class="ng-tooltip-name">${at(v)}</span>${S}</div>`,y=b=>b?`<div class="ng-tooltip-divider"></div><div class="ng-tooltip-body">${b}</div>`:"";return`${h}<div class="ng-tooltip-body">${a}</div>${y(d)}${y(p)}${y(f)}`}class ws{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Gi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o,i){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const g=this.customRenderer(t);typeof g=="string"?this.tooltipEl.innerHTML=g:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(g))}else this.tooltipEl.innerHTML=Ki(t,o,i);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const a=this.tooltipEl.getBoundingClientRect(),l=this.container.getBoundingClientRect();let u=n+Ot,d=s+Ot;u+a.width>l.width&&(u=n-Ot-a.width),d+a.height>l.height&&(d=s-Ot-a.height),u=Math.max(0,u),d=Math.max(0,d),this.tooltipEl.style.left=`${u}px`,this.tooltipEl.style.top=`${d}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Xi))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const pn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},ks={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},ji=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function Ds(e){const t=qi(e.theme);return{columns:e.columns??ji,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function qi(e){return!e||e==="light"?{...pn}:e==="dark"?{...ks}:{...pn,...e}}function ut(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const Es="nimbus-gantt-root-styles";function Zi(){if(typeof document>"u"||document.getElementById(Es))return;const e=document.createElement("style");e.id=Es,e.textContent=`
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
  `,document.head.appendChild(e)}class Ji{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.replayProvider=null,this.agent={getSnapshot:()=>{const g=this.getDisplayState();return{cursorDate:g.timeCursorDate?g.timeCursorDate.toISOString():null,zoomLevel:g.zoomLevel,tasks:Array.from(g.tasks.values()),dependencies:Array.from(g.dependencies.values()),selectedIds:Array.from(g.selectedIds),expandedIds:Array.from(g.expandedIds),flatVisibleIds:g.flatVisibleIds.slice()}},updateTask:(g,p)=>{this.store.dispatch({type:"UPDATE_TASK",taskId:g,changes:p})},addTask:g=>{this.store.dispatch({type:"ADD_TASK",task:g})},removeTask:g=>{this.store.dispatch({type:"REMOVE_TASK",taskId:g})},moveTask:(g,p,r)=>{this.store.dispatch({type:"TASK_MOVE",taskId:g,startDate:p,endDate:r})},addDependency:g=>{this.store.dispatch({type:"ADD_DEPENDENCY",dependency:g})},removeDependency:g=>{this.store.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:g})},setSelection:g=>{this.store.dispatch({type:"DESELECT_ALL"});for(const p of g)this.store.dispatch({type:"SELECT_TASK",taskId:p,multi:!0})},setZoom:g=>{this.store.dispatch({type:"SET_ZOOM",level:g})},scrubTo:g=>{this.store.dispatch({type:"SET_TIME_CURSOR",date:g?new Date(g):null})},history:()=>{const g=this.history;return g?{entries:g.entries().map(p=>({ts:p.ts,wallTs:p.wallTs,actionType:p.action.type,source:p.source,actor:p.actor})),annotations:g.annotations().slice(),lastWallTs:g.lastWallTs()}:null},appendAnnotation:(g,p,r)=>{const c=this.history;return c?(c.appendAnnotation({kind:g,taskId:p,payload:r}),!0):!1}},this.container=t,this.config=Ds(n),Zi(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const g of n.tasks)s.set(g.id,g);const o=new Map;if(n.dependencies)for(const g of n.dependencies)o.set(g.id,g);const i=new Set,{tree:a,flatIds:l}=Ue(s,i),u=yt(s),d={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new os,this.store=new un(d),this.layoutEngine=new cs,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new _i(this.timelinePanel),this.treeGrid=new Hi(this.gridPanel),this.scrollManager=new xi(this.timelinePanel,(g,p)=>{this.store.dispatch({type:"SET_SCROLL",x:g,y:p})}),this.dependencyRenderer=new ms,this.tooltipManager=new ws(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const g=this.timelinePanel.querySelector("canvas");g&&(this.dragManager=new Ui(g,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,c,f)=>{var S;p?this.tooltipManager.show(p,r,c,f,{depSummary:this.computeDepSummary(p.id)}):this.tooltipManager.hide();try{(S=n.onHover)==null||S.call(n,p,r,c,f)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((g,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:g,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(g))}),this.treeGrid.onRowDblClick(g=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(g))}),this.treeGrid.onExpandToggle(g=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:g})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const g=()=>{this.destroyed||this.resize()};window.addEventListener("resize",g),this._fallbackResizeHandler=g}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){ut("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){ut("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(ut("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const u=ss(this.store.getState(),t);for(const d of u)this.store.dispatch(d);ut("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=ss(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,l=0;for(const u of n){let d=null;if(u.type==="UPDATE_TASK"?d=u.taskId:u.type==="ADD_TASK"?d=u.task.id:u.type==="REMOVE_TASK"&&(d=u.taskId),d&&typeof s=="number"){const g=this.lastAppliedTs.get(d);if(g!==void 0&&s<g){l++;continue}}this.store.dispatch(u),d&&typeof s=="number"&&this.lastAppliedTs.set(d,s),u.type==="UPDATE_TASK"?o++:u.type==="ADD_TASK"?i++:u.type==="REMOVE_TASK"&&a++}l>0&&ut("remote:dropped-stale",{kind:t.kind,count:l}),o+i+a>0&&ut("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getDisplayState(){const t=this.store.getState(),n=t.timeCursorDate;return!n||!this.replayProvider?t:this.replayProvider.snapshotAt(n)??t}registerReplayProvider(t){return this.replayProvider=t,()=>{this.replayProvider===t&&(this.replayProvider=null)}}setTimeCursor(t){this.store.dispatch({type:"SET_TIME_CURSOR",date:t})}getTimeCursor(){return this.store.getState().timeCursorDate??null}getState(){return this.store.getState()}computeDepSummary(t){let n=0,s=0;return this.store.getState().dependencies.forEach(i=>{i.source===t?n++:i.target===t&&s++}),{blocks:n,blockedBy:s}}hitTestAt(t,n){const s=this.rootEl.getBoundingClientRect();if(!(t>=s.left&&t<=s.right&&n>=s.top&&n<=s.bottom))return{zone:"outside"};const i=this.getDisplayState(),{config:a,scrollX:l,scrollY:u,flatVisibleIds:d,tasks:g}=i,{headerHeight:p,rowHeight:r}=a,c=this.gridPanel.getBoundingClientRect(),f=this.timelinePanel.getBoundingClientRect(),S=t>=c.left&&t<=c.right&&n>=c.top&&n<=c.bottom&&c.width>0,v=t>=f.left&&t<=f.right&&n>=f.top&&n<=f.bottom;if(v&&n-f.top<p){const w=t-f.left+l;let k;try{k=this.timeScale.xToDate(w)}catch{k=new Date}const D=n-f.top,E=(()=>{try{return this.timeScale.getHeaderRows()}catch{return[]}})(),C=Math.max(1,E.length),M=p/C,A=Math.min(C-1,Math.max(0,Math.floor(D/M))),R=Qi(i.zoomLevel,C,A);return{zone:"date-header",date:k,level:R}}const h=p,y=(v?n-f.top:n-c.top)-h;if(y<0)return{zone:"outside"};const b=Math.floor((y+u)/r),T=(w=>w<0||w>=d.length?null:g.get(d[w])??null)(b);if(v&&T){if(T.status==="group-header")return{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:b};const w=this.layouts.find(k=>k.taskId===T.id)??null;if(w){const k=t-f.left+l,D=6;if(w.isMilestone){const E=w.barHeight/2;if(Math.abs(k-w.x)<=E)return{zone:"bar",task:T,rowIndex:b,barType:"body"}}else if(k>=w.x-D&&k<=w.x+w.width+D){const M=k<=w.x+6?"left-edge":k>=w.x+w.width-6?"right-edge":"body";return{zone:"bar",task:T,rowIndex:b,barType:M}}}}if(S&&T)return T.status==="group-header"?{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:b}:{zone:"row-label",task:T,rowIndex:b};if(v){const w=t-f.left+l,k=n-f.top;try{const D=this.dependencyRenderer.hitTest(w,k,i,this.layouts,u,p);if(D)return{zone:"dependency",depId:D}}catch{}}if(b>=d.length){let w;try{w=this.timeScale.xToDate(t-f.left+l)}catch{w=new Date}return{zone:"below-rows",date:w}}if(v){let w;try{w=this.timeScale.xToDate(t-f.left+l)}catch{w=new Date}const k=ea(i,b);return{zone:"canvas-empty",date:w,rowIndex:b,nearestTask:T,bucketId:k}}return{zone:"outside"}}capabilities(){const t=this;return{version:"0.198.0",pushRemoteEvent:typeof this.pushRemoteEvent=="function",timeCursor:!0,history:!!t.history,replayProvider:!!this.replayProvider,pluginsInstalled:this.plugins.map(n=>n.name).join(",")}}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}emit(t,...n){this.eventBus.emit(t,...n)}on(t,n){return this.eventBus.on(t,n)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.getDisplayState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const d=u.getContext("2d");d&&l.renderCanvas(d,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new rs(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){const t=this,n={getState:()=>this.store.getState(),dispatch:s=>this.store.dispatch(s),on:(s,o)=>this.eventBus.on(s,o),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:s=>this.timeScale.dateToX(s),xToDate:s=>this.timeScale.xToDate(s),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const s=this.store.getState(),{tree:o,flatIds:i}=Ue(s.tasks,s.expandedIds);s.tree=o,s.flatVisibleIds.length=0;for(const a of i)s.flatVisibleIds.push(a)}};return n.__gantt=t,n}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new un(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function Qi(e,t,n){if(t===2){if(e==="day")return n===0?"month":"day";if(e==="week")return n===0?"month":"week";if(e==="month")return n===0?"year":"month";if(e==="quarter")return n===0?"year":"quarter"}return e}function ea(e,t){if(t<0||t>=e.flatVisibleIds.length)return null;let n=e.tasks.get(e.flatVisibleIds[t]);for(;n;){if(n.status==="group-header")return n.groupId??n.id;if(!n.parentId)break;n=e.tasks.get(n.parentId)}const s=e.tasks.get(e.flatVisibleIds[t]);return(s==null?void 0:s.groupId)??null}function Cs(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function Is(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of Cs(a)){let u=s.get(l);u||(u=[],s.set(l,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const u of l)o.has(u)||(o.add(u),i.push(u))}return o}function ta(e,t){const n=Is(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const na=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function mn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function sa(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function d(c){s.push(c),s.length>t&&s.shift()}function g(){if(!n||s.length===0)return;const c=mn(n.getState()),f=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const c=mn(n.getState()),f=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),p()):(c.preventDefault(),g()))}return{name:"UndoRedoPlugin",install(c){n=c,u=c.on("render",()=>{if(l)return;const f=document.querySelector(".nimbus-gantt");f&&(l=f.parentElement??f,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,f){if(i){f(c);return}if(na.has(c.type)&&n){const S=mn(n.getState());d(S),o=[]}f(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const St=["day","week","month","quarter"];function oa(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function yn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function ia(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=oa(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d>0&&e.dispatch({type:"SELECT_TASK",taskId:l[d-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const d=l.indexOf(u);d<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[d+1]})}break}case"ArrowRight":{if(u)if(yn(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+d})}break}case"ArrowLeft":{if(u)if(yn(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}else{const d=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-d)})}break}case"Enter":{if(!u)return;i.preventDefault();const d=a.tasks.get(u);if(d&&n){const g=new CustomEvent("nimbus-gantt:taskDblClick",{detail:d,bubbles:!0});n.dispatchEvent(g)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA")return;i.preventDefault();const g=a.tasks.get(u);if(g&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:g,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const d=l[l.length-1],g=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,g-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:d})}break}case"+":case"=":{i.preventDefault();const d=St.indexOf(a.zoomLevel);d>0&&e.dispatch({type:"SET_ZOOM",level:St[d-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const d=St.indexOf(a.zoomLevel);d<St.length-1&&e.dispatch({type:"SET_ZOOM",level:St[d+1]});break}case" ":{if(!u)return;const d=i.target;if(d.tagName==="INPUT"||d.tagName==="TEXTAREA"||d.tagName==="BUTTON")return;yn(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const Ms="#D4A017",aa="rgba(212, 160, 23, 0.25)",ra=[6,4],la=1,ca=2,da=4,As=8,Ls=10,Rs=16,ua=6;function ga(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,d=s.filter(r=>r.isMilestone);if(d.length===0)return;t.save();const g=u,p=t.canvas.height/(window.devicePixelRatio||1)-g;t.beginPath(),t.rect(0,g,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of d){const c=r.x,f=r.barY-a,S=r.barHeight,v=f+S/2,h=r.color===l.barDefaultColor?Ms:r.color||Ms;t.save(),t.beginPath(),t.strokeStyle=aa,t.lineWidth=la,t.setLineDash(ra),t.moveTo(c,g),t.lineTo(c,g+p),t.stroke(),t.setLineDash([]),t.restore();const y=(S-ca*2)/2;t.save(),t.beginPath(),t.moveTo(c,v-y),t.lineTo(c+y,v),t.lineTo(c,v+y),t.lineTo(c-y,v),t.closePath(),t.fillStyle=h,t.fill(),t.strokeStyle=Ps(h,.25),t.lineWidth=1,t.stroke(),t.restore();const b=c+y+da,m=v-Rs/2;if(t.save(),t.beginPath(),t.strokeStyle=Ps(h,.15),t.lineWidth=1.5,t.moveTo(b,m),t.lineTo(b,m+Rs),t.stroke(),t.beginPath(),t.moveTo(b,m),t.lineTo(b+As,m+Ls/2),t.lineTo(b,m+Ls),t.closePath(),t.fillStyle=h,t.fill(),t.restore(),r.label){const T=b+As+ua,w=v;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,T,w),t.restore()}}t.restore()},destroy(){e=null}}}function Ps(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const ha="rgba(100, 116, 139, 0.12)",fa="rgba(100, 116, 139, 0.25)",$s="#334155",pa="rgba(100, 116, 139, 0.2)",ma="#475569",ya=8,ba=6,Ta=2,je=5,va=12,Sa=28,wa=8;function ka(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(g){const p=new Map,r=[];for(const c of g.flatVisibleIds){const f=g.tasks.get(c);if(f)if(f.groupId){let S=p.get(f.groupId);S||(S={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},p.set(f.groupId,S)),S.taskIds.push(c)}else r.push(c)}n=Array.from(p.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const f=o.length,S=`__group_header__${c.groupId}`;if(o.push(S),s.set(f,c),!c.collapsed)for(const v of c.taskIds)o.push(v)}}function d(g){if(t.has(g)?t.delete(g):t.add(g),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(g){e=g,l=g.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const c=e.getState(),f=p.querySelector(".ng-timeline-panel");if(!f)return;const S=f.getBoundingClientRect(),v=r.clientY-S.top,h=c.config.headerHeight;if(v<h)return;const y=v-h+c.scrollY,b=Math.floor(y/c.config.rowHeight),m=s.get(b);m&&(r.preventDefault(),r.stopPropagation(),d(m.groupId))},a.addEventListener("click",i))})},middleware(g,p){if(p(g),!e)return;const r=e.getState();let c=!1;for(const f of r.tasks.values())if(f.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const f=new Set;for(const S of n)if(S.collapsed)for(const v of S.taskIds)f.add(v);if(f.size>0){const S=r.flatVisibleIds.filter(v=>!f.has(v));if(S.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const v of S)r.flatVisibleIds.push(v)}}}},renderCanvas(g,p,r){if(!e||n.length===0)return;const{config:c,scrollX:f,scrollY:S}=p,{theme:v}=c,h=c.headerHeight,y=c.rowHeight,b=g.canvas.width/(window.devicePixelRatio||1),m=g.canvas.height/(window.devicePixelRatio||1)-h;g.save(),g.beginPath(),g.rect(0,h,b,m),g.clip();let T=0;const w=[];for(const k of p.flatVisibleIds){const D=p.tasks.get(k);D&&!D.groupId&&w.push(k)}T=w.length;for(const k of n){const D=h+T*y-S;if(D+y>=h&&D<h+m){g.fillStyle=ha,g.fillRect(0,D,b,y),g.beginPath(),g.strokeStyle=fa,g.lineWidth=1,g.moveTo(0,Math.round(D+y)+.5),g.lineTo(b,Math.round(D+y)+.5),g.stroke();const E=va,C=D+y/2;g.save(),g.beginPath(),g.fillStyle=$s,k.collapsed?(g.moveTo(E,C-je),g.lineTo(E+je,C),g.lineTo(E,C+je)):(g.moveTo(E-je/2,C-je/2),g.lineTo(E+je/2,C-je/2),g.lineTo(E,C+je/2)),g.closePath(),g.fill(),g.restore(),g.save(),g.font=`600 ${v.fontSize}px ${v.fontFamily}`,g.textBaseline="middle",g.textAlign="left",g.fillStyle=$s;const M=Sa,A=D+y/2;g.fillText(k.groupName,M,A);const R=g.measureText(k.groupName).width;g.restore();const N=`${k.taskIds.length}`;g.save(),g.font=`${v.fontSize-1}px ${v.fontFamily}`;const P=g.measureText(N).width+ba*2,x=v.fontSize+Ta*2,W=M+R+wa,K=A-x/2;g.beginPath();const q=ya;g.moveTo(W+q,K),g.lineTo(W+P-q,K),g.arcTo(W+P,K,W+P,K+q,q),g.lineTo(W+P,K+x-q),g.arcTo(W+P,K+x,W+P-q,K+x,q),g.lineTo(W+q,K+x),g.arcTo(W,K+x,W,K+x-q,q),g.lineTo(W,K+q),g.arcTo(W,K,W+q,K,q),g.closePath(),g.fillStyle=pa,g.fill(),g.fillStyle=ma,g.textBaseline="middle",g.textAlign="center",g.fillText(N,W+P/2,A),g.restore()}T+=1,k.collapsed||(T+=k.taskIds.length)}g.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const gt="__bucket_header__";function _s(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Da(e){return e.groupId??null}function Ea(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function Ca(e){const t=[...e.buckets].sort((r,c)=>r.order-c.order),n=new Map;t.forEach((r,c)=>n.set(r.id,c));const s=e.getBucket??Da,o=e.getBucketProgress??Ea,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function d(r,c){l=t.map(f=>({config:f,taskIds:[],allTaskIds:[],collapsed:i.has(f.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const f of c){const S=r.tasks.get(f);if(!S)continue;const v=s(S);if(!v)continue;const h=n.get(v);h!==void 0&&l[h].taskIds.push(f)}for(const[f,S]of r.tasks){if(f.startsWith(gt))continue;const v=s(S);if(!v)continue;const h=n.get(v);h!==void 0&&l[h].allTaskIds.push(f)}for(const f of l){if(f.allTaskIds.length===0){f.progress=0,f.startDate=null,f.endDate=null,f.totalHours=0,f.totalLogged=0;continue}const S=[];let v=1/0,h=-1/0,y=0,b=0;for(const m of f.allTaskIds){const T=r.tasks.get(m);if(!T)continue;if(S.push(T),T.startDate){const k=bt(T.startDate).getTime();!isNaN(k)&&k<v&&(v=k)}if(T.endDate){const k=bt(T.endDate).getTime();!isNaN(k)&&k>h&&(h=k)}const w=T.metadata;typeof(w==null?void 0:w.hoursHigh)=="number"&&(y+=w.hoursHigh),typeof(w==null?void 0:w.hoursLogged)=="number"&&(b+=w.hoursLogged)}f.startDate=isFinite(v)?new Date(v):null,f.endDate=isFinite(h)?new Date(h):null,f.totalHours=y,f.totalLogged=b,f.progress=Math.max(0,Math.min(1,o(S)))}}function g(r){if(!r.startDate||!r.endDate)return null;const c=r.totalHours>0&&r.totalLogged>=r.totalHours,f=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),S=r.totalHours>0?`${r.totalHours}h (${f}% budget)`:`${r.allTaskIds.length} items`;return{id:`${gt}${r.config.id}`,name:S,startDate:_s(r.startDate),endDate:_s(r.endDate),progress:r.progress,color:c?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const c=a.getState();a.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...c)=>{const f=c[0];let S=null;typeof f=="string"?S=f:f&&typeof f=="object"&&"id"in f&&(S=String(f.id)),S&&S.startsWith(gt)&&p(S.substring(gt.length))}))},middleware(r,c){if(c(r),!a)return;const f=a.getState(),S=[];for(const y of f.tasks.keys())y.startsWith(gt)&&S.push(y);for(const y of S)f.tasks.delete(y);const v=f.flatVisibleIds.filter(y=>!y.startsWith(gt));let h=!1;for(const y of f.tasks.values())if(s(y)!=null){h=!0;break}if(!h){if(l=[],v.length!==f.flatVisibleIds.length){f.flatVisibleIds.length=0;for(const y of v)f.flatVisibleIds.push(y)}return}d(f,v);for(const y of l){if(y.allTaskIds.length===0)continue;const b=g(y);if(b){f.tasks.set(b.id,b);for(const m of y.allTaskIds){const T=f.tasks.get(m);T&&(T.parentId=b.id)}y.collapsed?f.expandedIds.delete(b.id):f.expandedIds.add(b.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const Ia=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function Ma(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Ns=864e5,Aa=6,La=2,Ra=2,Pa=.18,$a=.4;function Os(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function bn(e,t){return Math.round((t.getTime()-e.getTime())/Ns)}function ht(e,t){return new Date(e.getTime()+t*Ns)}function Tn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const M=E.lag||0;s.get(E.source).push({target:E.target,lag:M,depId:E.id}),o.get(E.target).push({source:E.source,lag:M,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[E,C]of e){const M=Os(C.startDate),A=Os(C.endDate);l.set(E,M),u.set(E,A),a.set(E,Math.max(bn(M,A),0))}const d=new Map,g=new Map,p=[],r=[],c=new Map(i);for(const E of n)c.get(E)===0&&(r.push(E),d.set(E,l.get(E)),g.set(E,u.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),d.get(E);const C=g.get(E);for(const M of s.get(E)){const{target:A,lag:R}=M,N=ht(C,R),_=d.get(A);(!_||N.getTime()>_.getTime())&&(d.set(A,N),g.set(A,ht(N,a.get(A))));const P=c.get(A)-1;c.set(A,P),P===0&&r.push(A)}}for(const E of n)d.has(E)||(d.set(E,l.get(E)),g.set(E,u.get(E)),p.push(E));let f=-1/0;for(const E of g.values())E.getTime()>f&&(f=E.getTime());const S=new Date(f);let v=1/0;for(const E of d.values())E.getTime()<v&&(v=E.getTime());const h=new Date(v),y=bn(h,S),b=new Map,m=new Map;for(const E of n)s.get(E).length===0&&(m.set(E,S),b.set(E,ht(S,-a.get(E))));for(let E=p.length-1;E>=0;E--){const C=p[E];if(!m.has(C)){let M=1/0;for(const A of s.get(C)){const R=b.get(A.target);if(R){const N=ht(R,-A.lag);N.getTime()<M&&(M=N.getTime())}}M===1/0?m.set(C,S):m.set(C,new Date(M)),b.set(C,ht(m.get(C),-a.get(C)))}}for(const E of n)m.has(E)||(m.set(E,S),b.set(E,ht(S,-a.get(E))));const T=.5,w=new Set,k=new Map;for(const E of n){const C=d.get(E),M=g.get(E),A=b.get(E),R=m.get(E),N=bn(C,A),_=Math.abs(N)<T;_&&w.add(E),k.set(E,{earlyStart:C,earlyFinish:M,lateStart:A,lateFinish:R,totalFloat:N,isCritical:_})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&w.has(E.source)&&w.has(E.target)&&D.add(E.id);return{criticalTaskIds:w,criticalDependencyIds:D,taskAnalysis:k,projectDuration:y}}function _a(){let e,t=null,n=[];function s(){const o=e.getState();t=Tn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:d,barHeight:g}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,f=u,S=e.getTimeScale(),v=new Map;for(const m of a)v.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const m of a){const T=t.taskAnalysis.get(m.taskId);if(!T||T.isCritical||T.totalFloat<=0)continue;const w=m.barY-c,k=g*$a,D=m.x+m.width,C=S.dateToX(T.lateFinish)-D;C>1&&(o.fillStyle=m.color,o.globalAlpha=Pa,o.fillRect(D,w+g-k,C,k),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const T=m.x,w=m.barY-c,k=m.width,D=m.barHeight;if(!(w+D<f||w>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=Aa;for(let E=0;E<La;E++){o.strokeStyle=p,o.lineWidth=Ra,o.beginPath();const C=l.barBorderRadius,M=Math.min(C,k/2,D/2);o.moveTo(T+M,w),o.lineTo(T+k-M,w),o.arcTo(T+k,w,T+k,w+M,M),o.lineTo(T+k,w+D-M),o.arcTo(T+k,w+D,T+k-M,w+D,M),o.lineTo(T+M,w+D),o.arcTo(T,w+D,T,w+D-M,M),o.lineTo(T,w+M),o.arcTo(T,w,T+M,w,M),o.closePath(),o.stroke()}o.restore()}}const h=6,y=4,b=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const T=v.get(m.source),w=v.get(m.target);if(!T||!w)continue;const k=T.x+T.width,D=T.barY+T.barHeight/2-c,E=w.x,C=w.barY+w.barHeight/2-c;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=k+b,A=E-b;if(o.moveTo(k,D),A>=M)o.lineTo(M,D),o.lineTo(M,C),o.lineTo(E,C);else{const R=(D+C)/2;o.lineTo(M,D),o.lineTo(M,R),o.lineTo(A,R),o.lineTo(A,C),o.lineTo(E,C)}o.stroke(),o.beginPath(),o.moveTo(E,C),o.lineTo(E-h,C-y),o.lineTo(E-h,C+y),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const Na=864e5,Oa=.6,Hs=.25,Ha="#38A169",xa="#E53E3E",Ba="#A0AEC0",Fa=10,Ua=4,qe=16,Ya=3;function xt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Wa(e,t){return Math.round((t.getTime()-e.getTime())/Na)}function Xa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:xt(s.startDate),end:xt(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var S,v;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,d=o.scrollX,g=o.scrollY,p=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-d,0);const f=u*Oa;for(const h of i){if(h.isMilestone)continue;const y=t.get(h.taskId);if(!y)continue;const b=h.barY-g;if(b+u+f<p||b>s.canvas.height)continue;const m=r.dateToX(y.start),T=r.dateToX(y.end),w=Math.max(T-m,2),k=b+u+1;xt(((S=o.tasks.get(h.taskId))==null?void 0:S.startDate)||"");const D=xt(((v=o.tasks.get(h.taskId))==null?void 0:v.endDate)||""),E=Wa(y.end,D);let C;E<0?C=Ha:E>0?C=xa:C=Ba,s.save(),s.globalAlpha=Hs,s.fillStyle=C;const M=Math.min(c,w/2,f/2);if(s.beginPath(),s.moveTo(m+M,k),s.lineTo(m+w-M,k),s.arcTo(m+w,k,m+w,k+M,M),s.lineTo(m+w,k+f-M),s.arcTo(m+w,k+f,m+w-M,k+f,M),s.lineTo(m+M,k+f),s.arcTo(m,k+f,m,k+f-M,M),s.lineTo(m,k+M),s.arcTo(m,k,m+M,k,M),s.closePath(),s.fill(),s.globalAlpha=Hs*2,s.strokeStyle=C,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const A=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${Fa}px ${a.fontFamily}`;const _=s.measureText(A).width+Ua*2,P=h.x+h.width+4,x=k+(f-qe)/2;s.globalAlpha=.85,s.fillStyle=C;const W=Ya;s.beginPath(),s.moveTo(P+W,x),s.lineTo(P+_-W,x),s.arcTo(P+_,x,P+_,x+W,W),s.lineTo(P+_,x+qe-W),s.arcTo(P+_,x+qe,P+_-W,x+qe,W),s.lineTo(P+W,x+qe),s.arcTo(P,x+qe,P,x+qe-W,W),s.lineTo(P,x+W),s.arcTo(P,x,P+W,x,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(A,P+_/2,x+qe/2),s.restore()}}s.restore()},destroy(){}}}const xs=5,za=5,Ga=.3,Va=15;function Ka(){let e,t=null,n=0,s=0;const o=[];function i(d){const{rowHeight:g,headerHeight:p}=d.config,r=d.scrollY,c=d.flatVisibleIds.length,f=a(d),S=Math.floor(r/g),v=Math.ceil((r+f)/g);let h=Math.max(0,S-xs),y=Math.min(c,v+xs);if(Math.abs(s)>0){const m=Math.min(Va,Math.ceil(Math.abs(s*Ga)/g));s>0?y=Math.min(c,y+m):h=Math.max(0,h-m)}const b=new Set;for(let m=h;m<y&&m<d.flatVisibleIds.length;m++)b.add(d.flatVisibleIds[m]);return{startRow:h,endRow:y,totalRows:c,visibleTaskIds:b}}function a(d){const p=d.flatVisibleIds.length*d.config.rowHeight-d.scrollY;return Math.min(800,Math.max(p,200))}function l(d){const g=performance.now();for(o.push({y:d,time:g});o.length>za;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],c=(r.time-p.time)/1e3;c>0&&(s=(r.y-p.y)/c)}n=d}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const d=e.getState();return(!t||d.scrollY!==n)&&(l(d.scrollY),t=i(d)),t},filterLayouts(d){const g=u.getVisibleRange();return g.totalRows===0?[]:d.filter(p=>g.visibleTaskIds.has(p.taskId))},isVisible(d){return u.getVisibleRange().visibleTaskIds.has(d)},getContentHeight(){if(!e)return 0;const d=e.getState();return d.flatVisibleIds.length*d.config.rowHeight+d.config.headerHeight}};return{name:"VirtualScrollPlugin",install(d){e=d},middleware(d,g){if(g(d),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(d.type)&&(t=null,d.type==="SET_SCROLL"||d.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const Ye=864e5,vn=1,Bs=2,Fs=.5,Us=2,Bt=8,Ys=6,Ws=2,Ft=1e4;function Sn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Xs(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function rt(e){return Math.round(e)+.5}function zs(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Gs(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let d=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(d,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const c=p.align==="right"?d+r-8:p.align==="center"?d+r/2:d+8;e.fillText(p.header,c,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(d+r,0),e.lineTo(d+r,s),e.stroke(),d+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const g=t.flatVisibleIds;for(let p=0;p<g.length;p++){const r=t.tasks.get(g[p]);if(!r)continue;const c=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const S of a){const v=S.width??120,h=zs(r,S.field);e.save(),e.beginPath(),e.rect(f,c,v,l),e.clip(),e.textBaseline="middle";const y=S.tree?8:0;e.textAlign=S.align==="right"?"right":S.align==="center"?"center":"left";const b=S.align==="right"?f+v-8:S.align==="center"?f+v/2:f+8+y;e.fillText(h,b,c+l/2),e.restore(),f+=v}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Vs(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,d=s.getTotalWidth(),g=t.flatVisibleIds.length*u,p=l+g;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,d,p),i.showWeekends){const{start:f,end:S}=t.dateRange,v=new Date(f);v.setUTCHours(0,0,0,0);const h=S.getTime();for(;v.getTime()<=h;){const y=v.getUTCDay();if(y===0||y===6){const b=o+s.dateToX(v),m=new Date(v.getTime()+Ye),T=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(b,l,T-b,g)}v.setTime(v.getTime()+Ye)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Fs;for(const f of r){const S=rt(o+f);e.moveTo(S,l),e.lineTo(S,p)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+f*u,d,u));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:S,end:v}=t.dateRange;if(f.getTime()>=S.getTime()&&f.getTime()<=v.getTime()){const h=o+s.dateToX(f),y=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(h,l,y,g),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Bs,e.moveTo(rt(h),l),e.lineTo(rt(h),p),e.stroke()}}const c=a.barBorderRadius;for(const f of n){const S=o+f.x,v=f.barY,h=f.width,y=f.barHeight;if(f.isMilestone){const b=(y-Us*2)/2,m=v+y/2;e.beginPath(),e.moveTo(S,m-b),e.lineTo(S+b,m),e.lineTo(S,m+b),e.lineTo(S-b,m),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(wn(e,S,v,h,y,c),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const b=Xs(f.color,.2);e.save(),e.beginPath(),wn(e,S,v,h,y,c),e.clip(),e.fillStyle=b,e.fillRect(S,v,f.progressWidth,y),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),wn(e,S,v,h,y,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Ws,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const b=e.measureText(f.label).width,m=v+y/2;b+Bt*2<=h?(e.beginPath(),e.rect(S,v,h,y),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,S+Bt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,S+h+Ys,m)),e.restore()}}ja(e,t,n,a,o),qa(e,s,i,a,o)}function ja(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const d of n)i.set(d.taskId,d);const a=12,l=6,u=4;e.save();for(const d of t.dependencies.values()){const g=i.get(d.source),p=i.get(d.target);if(!g||!p)continue;const r=d.type||"FS",c=g.barY+g.barHeight/2,f=p.barY+p.barHeight/2;let S,v;const h=r==="FS"||r==="FF",y=r==="FS"||r==="SS";switch(r){case"FS":S=o+g.x+g.width,v=o+p.x;break;case"SS":S=o+g.x,v=o+p.x;break;case"FF":S=o+g.x+g.width,v=o+p.x+p.width;break;case"SF":S=o+g.x,v=o+p.x+p.width;break}const b=h?S+a:S-a,m=y?v-a:v+a,T=h?y?m>=b:v+a>=b:y?v-a<=b:m<=b;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(S,c),T)e.lineTo(b,c),e.lineTo(b,f),e.lineTo(v,f);else{const w=(c+f)/2;e.lineTo(b,c),e.lineTo(b,w),e.lineTo(m,w),e.lineTo(m,f),e.lineTo(v,f)}e.stroke(),e.beginPath(),y?(e.moveTo(v,f),e.lineTo(v-l,f-u),e.lineTo(v-l,f+u)):(e.moveTo(v,f),e.lineTo(v+l,f-u),e.lineTo(v+l,f+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function qa(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let d=0;d<a.length;d++){const g=a[d],p=d*u;for(const r of g){const c=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=vn,e.moveTo(rt(c+f),p),e.lineTo(rt(c+f),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(c,p,f,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+f/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=vn,e.moveTo(o,rt(i)),e.lineTo(o+t.getTotalWidth(),rt(i)),e.stroke()}function wn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function wt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Za(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),d=s+u,g=e.flatVisibleIds.length*l,p=a+g,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${p}" viewBox="0 0 ${d} ${p}">`),c.push(`<style>text { font-family: ${wt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const m of o.columns){const T=m.width??120;c.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${wt(m.header)}</text>`),c.push(`<line x1="${f+T}" y1="0" x2="${f+T}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=T}for(let m=0;m<e.flatVisibleIds.length;m++){const T=e.tasks.get(e.flatVisibleIds[m]);if(!T)continue;const w=a+m*l;m%2===1&&c.push(`<rect x="0" y="${w}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let k=0;for(const D of o.columns){const E=D.width??120,C=zs(T,D.field),M=D.tree?8:0;c.push(`<text x="${k+8+M}" y="${w+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${C}]]></text>`),k+=E}c.push(`<line x1="0" y1="${w+l}" x2="${s}" y2="${w+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${d}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const S=n.getHeaderRows(),v=S.length||2,h=a/v;for(let m=0;m<S.length;m++){const T=S[m],w=m*h;for(const k of T){const D=s+k.x+k.width/2,E=w+h/2,C=m===0?' font-weight="600"':"";c.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${C} fill="${i.timelineHeaderText}">${wt(k.label)}</text>`),c.push(`<line x1="${s+k.x+k.width}" y1="${w}" x2="${s+k.x+k.width}" y2="${w+h}" stroke="${i.timelineGridColor}" stroke-width="${vn}" />`)}}const y=n.getGridLines();for(const m of y)c.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${Fs}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&c.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:T}=e.dateRange,w=new Date(m);for(w.setUTCHours(0,0,0,0);w.getTime()<=T.getTime();){if(w.getUTCDay()===0||w.getUTCDay()===6){const k=s+n.dateToX(w),D=new Date(w.getTime()+Ye),E=s+n.dateToX(D);c.push(`<rect x="${k}" y="${a}" width="${E-k}" height="${g}" fill="${i.timelineWeekendBg}" />`)}w.setTime(w.getTime()+Ye)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:T,end:w}=e.dateRange;if(m.getTime()>=T.getTime()&&m.getTime()<=w.getTime()){const k=s+n.dateToX(m),D=n.getColumnWidth();c.push(`<rect x="${k}" y="${a}" width="${D}" height="${g}" fill="${i.todayBg}" />`),c.push(`<line x1="${k}" y1="${a}" x2="${k}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${Bs}" />`)}}for(const m of t){const T=s+m.x,w=m.barY,k=m.width,D=m.barHeight;if(m.isMilestone){const E=(D-Us*2)/2,C=w+D/2;c.push(`<polygon points="${T},${C-E} ${T+E},${C} ${T},${C+E} ${T-E},${C}" fill="${m.color}" />`);continue}if(c.push(`<rect x="${T}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const E=Xs(m.color,.2);c.push(`<clipPath id="clip-${m.taskId}"><rect x="${T}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${T}" y="${w}" width="${m.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&c.push(`<rect x="${T}" y="${w}" width="${k}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Ws}" />`),m.label){const E=w+D/2;i.fontSize*.6*m.label.length+Bt*2<=k?c.push(`<text x="${T+Bt}" y="${E}" dominant-baseline="central" fill="${m.textColor}">${wt(m.label)}</text>`):c.push(`<text x="${T+k+Ys}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${wt(m.label)}</text>`)}}const b=new Map;for(const m of t)b.set(m.taskId,m);for(const m of e.dependencies.values()){const T=b.get(m.source),w=b.get(m.target);if(!T||!w)continue;const k=m.type||"FS",D=T.barY+T.barHeight/2,E=w.barY+w.barHeight/2;let C,M;const A=k==="FS"||k==="FF",R=k==="FS"||k==="SS";switch(k){case"FS":C=s+T.x+T.width,M=s+w.x;break;case"SS":C=s+T.x,M=s+w.x;break;case"FF":C=s+T.x+T.width,M=s+w.x+w.width;break;case"SF":C=s+T.x,M=s+w.x+w.width;break}const N=12,_=6,P=4,x=A?C+N:C-N,W=R?M-N:M+N,K=A?R?W>=x:M+N>=x:R?M-N<=x:W<=x;let q;if(K)q=`M${C},${D} L${x},${D} L${x},${E} L${M},${E}`;else{const F=(D+E)/2;q=`M${C},${D} L${x},${D} L${x},${F} L${W},${F} L${W},${E} L${M},${E}`}c.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),R?c.push(`<polygon points="${M},${E} ${M-_},${E-P} ${M-_},${E+P}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${M},${E} ${M+_},${E-P} ${M+_},${E+P}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function Ja(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:d,end:g}=l.dateRange,p=g.getTime()-d.getTime(),r=u.getColumnWidth(),c=l.zoomLevel;let f;switch(c){case"day":f=Math.round(p/Ye);break;case"week":f=Math.ceil(p/(Ye*7));break;case"month":{const v=d.getUTCFullYear(),h=d.getUTCMonth(),y=g.getUTCFullYear(),b=g.getUTCMonth();f=(y-v)*12+(b-h);break}case"quarter":{const v=d.getUTCFullYear(),h=Math.floor(d.getUTCMonth()/3),y=g.getUTCFullYear(),b=Math.floor(g.getUTCMonth()/3);f=(y-v)*4+(b-h);break}}const S=f*r;return{dateToX(v){return(v.getTime()-d.getTime())/p*S},getColumnWidth(){return r},getTotalWidth(){return S},getHeaderRows(){return tr(c,d,g,r,S)},getGridLines(){return this.getHeaderRows()[1].map(h=>h.x).filter(h=>h>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),g=n(),p=u.getTotalWidth(),r=g+p,c=l.flatVisibleIds.length*l.config.rowHeight,f=l.config.headerHeight+c,S=a??"gantt-export.png";if(r>Ft||f>Ft){o(l,d,u,g,r,f,S);return}const v=document.createElement("canvas");v.width=r,v.height=f;const h=v.getContext("2d");h&&(g>0&&Gs(h,l,g,f),Vs(h,l,d,u,g),v.toBlob(y=>{y&&Sn(y,S)},"image/png"))}function o(a,l,u,d,g,p,r){const c=Math.min(1,Ft/g,Ft/p),f=Math.ceil(g*c),S=Math.ceil(p*c),v=document.createElement("canvas");v.width=f,v.height=S;const h=v.getContext("2d");h&&(h.scale(c,c),d>0&&Gs(h,a,d,p),Vs(h,a,l,u,d),v.toBlob(y=>{y&&Sn(y,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),d=e.getLayouts(),g=n(),p=Za(l,d,u,g),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});Sn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const Ks=["January","February","March","April","May","June","July","August","September","October","November","December"],js=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function qs(e,t){return new Date(e.getTime()+t*Ye)}function kn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Qa(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function er(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function tr(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>er(l,t,i,o);switch(e){case"day":{const l=[],u=[],d=Math.round(i/Ye);let g=new Date(t);for(let r=0;r<d;r++)u.push({label:String(g.getUTCDate()),x:r*s,width:s,date:new Date(g)}),g=qs(g,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=kn(p),c=a(p),f=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${Ks[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:c,width:f-c,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],d=Math.ceil(i/(Ye*7));for(let p=0;p<d;p++){const r=qs(t,p*7);u.push({label:`${js[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let g=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;g.getTime()<n.getTime();){const p=kn(g),r=g.getTime()<t.getTime()?t:g,c=p.getTime()>n.getTime()?n:p;l.push({label:`${Ks[g.getUTCMonth()]} ${g.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),g=p}return[l,u]}case"month":{const l=[],u=[],d=t.getUTCFullYear(),g=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),c=(p-d)*12+(r-g);let f=new Date(Date.UTC(d,g,1));for(let v=0;v<c;v++)u.push({label:js[f.getUTCMonth()],x:v*s,width:s,date:new Date(f)}),f=kn(f);let S=new Date(Date.UTC(d,0,1));for(;S.getTime()<n.getTime();){const v=new Date(Date.UTC(S.getUTCFullYear()+1,0,1)),h=S.getTime()<t.getTime()?t:S,y=v.getTime()>n.getTime()?n:v;l.push({label:String(S.getUTCFullYear()),x:a(h),width:a(y)-a(h),date:new Date(h)}),S=v}return[l,u]}case"quarter":{const l=[],u=[],d=t.getUTCFullYear(),g=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(p-d)*4+(r-g);let f=new Date(Date.UTC(d,g*3,1));for(let v=0;v<c;v++){const h=Math.floor(f.getUTCMonth()/3)+1;u.push({label:`Q${h}`,x:v*s,width:s,date:new Date(f)}),f=Qa(f,3)}let S=new Date(Date.UTC(d,0,1));for(;S.getTime()<n.getTime();){const v=new Date(Date.UTC(S.getUTCFullYear()+1,0,1)),h=S.getTime()<t.getTime()?t:S,y=v.getTime()>n.getTime()?n:v;l.push({label:String(S.getUTCFullYear()),x:a(h),width:a(y)-a(h),date:new Date(h)}),S=v}return[l,u]}default:return[[],[]]}}const nr={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},Dn="nimbus-gantt-dark-theme-transition";function sr(){if(typeof document>"u"||document.getElementById(Dn))return;const e=document.createElement("style");e.id=Dn,e.textContent=`
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
  `,document.head.appendChild(e)}function or(){if(typeof document>"u")return;const e=document.getElementById(Dn);e&&e.remove()}function ir(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const f={...c.config.theme,...nr};Object.assign(c.config.theme,f),s=!0,p()}function d(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,p()}function g(){s?d():u()}function p(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?u():d()}return{name:"DarkThemePlugin",install(c){n=c,sr(),c.on("theme:toggle",()=>{g()}),c.on("theme:dark",()=>{u()}),c.on("theme:light",()=>{d()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}or(),n=null,o=null,i=null,a=null,s=!1}}}const Pe=864e5,ar=[1,2,3,4,5],rr="rgba(128, 128, 128, 0.06)",lr="rgba(128, 128, 128, 0.04)",cr="#f87171",kt=4;function Dt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function xe(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function dr(e){const t=new Set((e==null?void 0:e.workDays)??ar),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=xe(r);return t.has(c.getUTCDay())}function i(r){const c=Dt(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=xe(r);for(c=new Date(c.getTime()+Pe);!i(c);)c=new Date(c.getTime()+Pe);return Dt(c)}function l(r,c){if(c===0)return r;let f=xe(r);const S=c>0?1:-1;let v=Math.abs(c);if(!i(f))for(f=new Date(f.getTime()+S*Pe);!i(f);)f=new Date(f.getTime()+S*Pe);for(;v>0;)f=new Date(f.getTime()+S*Pe),i(f)&&v--;return Dt(f)}function u(r,c){const f=xe(r),S=xe(c);if(f.getTime()>S.getTime())return-u(c,r);let v=0,h=new Date(f.getTime());for(;h.getTime()<S.getTime();)i(h)&&v++,h=new Date(h.getTime()+Pe);return v}function d(r,c="forward"){if(o(r))return r;let f=xe(r);const S=c==="forward"?Pe:-Pe;for(let v=0;v<30;v++)if(f=new Date(f.getTime()+S),i(f))return Dt(f);return r}function g(r,c){if(r.type==="TASK_MOVE"){const f=d(r.startDate,"forward"),S=d(r.endDate,"backward"),v=xe(S).getTime()<xe(f).getTime()?f:S;c({...r,startDate:f,endDate:v});return}if(r.type==="TASK_RESIZE"){const f=d(r.startDate,"forward"),S=d(r.endDate,"backward"),v=xe(S).getTime()<xe(f).getTime()?f:S;c({...r,startDate:f,endDate:v});return}c(r)}function p(r,c,f){const{config:S}=c,v=S.headerHeight,h=c.flatVisibleIds.length*S.rowHeight,y=s==null?void 0:s.getTimeScale();if(!y||h===0)return;const{start:b,end:m}=c.dateRange,T=c.scrollX,w=c.scrollY;r.save();const k=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(k,0,0,k,0,0),r.beginPath(),r.rect(0,v,r.canvas.width/k,h),r.clip(),r.translate(-T,0);const D=new Date(b);D.setUTCHours(0,0,0,0);const E=m.getTime();for(y.getColumnWidth();D.getTime()<=E;){const C=Dt(D),M=n.has(C),A=!t.has(D.getUTCDay());if(M||A){const R=y.dateToX(D),N=new Date(D.getTime()+Pe),P=y.dateToX(N)-R;if(r.fillStyle=rr,r.fillRect(R,v-w,P,h+w),A&&!M){r.save(),r.beginPath(),r.rect(R,v,P,h),r.clip(),r.strokeStyle=lr,r.lineWidth=1;const x=8,W=h;for(let K=-W;K<P+W;K+=x)r.beginPath(),r.moveTo(R+K,v),r.lineTo(R+K+W,v+W),r.stroke();r.restore()}}if(M){const R=y.dateToX(D),N=new Date(D.getTime()+Pe),_=y.dateToX(N),P=(R+_)/2;r.save(),r.setTransform(k,0,0,k,0,0),r.translate(-T,0);const x=v-kt-3;r.beginPath(),r.moveTo(P,x-kt),r.lineTo(P+kt,x),r.lineTo(P,x+kt),r.lineTo(P-kt,x),r.closePath(),r.fillStyle=cr,r.fill(),r.restore()}D.setTime(D.getTime()+Pe)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const f=c[0],S=c[1],v=c[2],h=l(f,S);v&&v(h)}),r.on("calendar:workDaysBetween",(...c)=>{const f=c[0],S=c[1],v=c[2],h=u(f,S);v&&v(h)}),r.on("calendar:isWorkDay",(...c)=>{const f=c[0],S=c[1],v=o(f);S&&S(v)}),r.on("calendar:nextWorkDay",(...c)=>{const f=c[0],S=c[1],v=a(f);S&&S(v)})},middleware:g,renderCanvas:p,destroy(){s=null}}}function ur(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function gr(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function hr(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=ur(),a=[],l=Date.now();let u=null,d=null,g=!1,p=[];const r=[];function c(m,T){if(g)return;const w={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:T};a.push(w),o&&o(w)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function S(){d===null&&(d=setInterval(()=>{f()},s))}function v(){d!==null&&(clearInterval(d),d=null)}const h=gr(()=>{if(!u)return;const m=u.getState();c("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let y=0;function b(m,T){switch(m.type){case"SET_ZOOM":{const w=u?u.getState().zoomLevel:"unknown";T(m),c("gantt.zoom",{oldLevel:w,newLevel:m.level});return}case"TASK_MOVE":{const w=y>0?Date.now()-y:0;T(m),c("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:w}),y=0;return}case"TASK_RESIZE":{T(m),c("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{y=Date.now(),T(m);return}case"SELECT_TASK":{T(m),c("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{T(m),h();return}case"TOGGLE_EXPAND":{const w=u?u.getState().expandedIds.has(m.taskId):!1;T(m),c(w?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{T(m),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{T(m),c("gantt.collapse",{all:!0});return}default:T(m);return}}return{name:"TelemetryPlugin",install(m){u=m,S();const T=m.getState();c("gantt.init",{taskCount:T.tasks.size,dependencyCount:T.dependencies.size,zoomLevel:T.zoomLevel}),setTimeout(()=>{g||c("gantt.feature.used",{plugins:p})},0);const w=m.on("taskClick",(...k)=>{const D=k[0];D&&c("gantt.task.click",{taskId:D.id})});r.push(w)},middleware:b,destroy(){g=!0;const m=Date.now()-l;c("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),f(),v();for(const T of r)T();r.length=0,u=null}}}const Zs=5,En=.15,Cn=.85,fr=2,Js=30,We=["day","week","month","quarter"];function Qs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function pr(e,t,n){return Math.max(t,Math.min(n,e))}function mr(e){const t=pr((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,d=0,g=0,p=0,r=null,c=null,f=null,S=null,v=null,h=null,y=0,b=0,m=0,T=!1;function w(_,P,x){m=_,y=P,b=x,T=!0,r===null&&(r=_)}function k(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(S=_=>{u||_.alpha==null||_.beta==null||_.gamma==null||w(_.alpha,_.beta,_.gamma)},window.addEventListener("deviceorientation",S),!0)}function D(){S&&(window.removeEventListener("deviceorientation",S),S=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function C(_){try{const P=JSON.parse(_);P.type==="orientation"?w(P.alpha,P.beta,P.gamma):P.type==="gesture"&&M(P.gesture)}catch{}}function M(_){if(!l)return;const P=l.getState();switch(_){case"tap":{P.selectedIds.size===0&&P.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:P.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const x=We.indexOf(P.zoomLevel);x<We.length-1&&l.dispatch({type:"SET_ZOOM",level:We[x+1]});break}case"swipe-right":{const x=We.indexOf(P.zoomLevel);x>0&&l.dispatch({type:"SET_ZOOM",level:We[x-1]});break}}}function A(){if(u||typeof WebSocket>"u")return;const _=E();try{v=new WebSocket(_),v.onmessage=P=>{typeof P.data=="string"&&C(P.data)},v.onclose=()=>{v=null,u||(h=setTimeout(A,3e3))},v.onerror=()=>{v&&v.close()}}catch{u||(h=setTimeout(A,3e3))}}function R(){h!==null&&(clearTimeout(h),h=null),v&&(v.onmessage=null,v.onclose=null,v.onerror=null,v.close(),v=null)}function N(){if(!(u||!l)){if(T){d=d*Cn+y*En,g=g*Cn+b*En,p=p*Cn+m*En;const _=l.getState(),P=fr*a;if(n){const x=Qs(g,Zs);if(x!==0){const W=x*P,K=Math.max(0,_.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const x=Qs(d,Zs);if(x!==0){const W=x*P,K=Math.max(0,_.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=We.indexOf(_.zoomLevel);if(W>Js&&K>0){const q=We[K-1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}else if(W<-Js&&K<We.length-1){const q=We[K+1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}}}f=requestAnimationFrame(N)}}return{name:"MotionControlPlugin",install(_){l=_,c=_.getState().zoomLevel,(!k()||i)&&A(),f=requestAnimationFrame(N)},destroy(){u=!0,f!==null&&(cancelAnimationFrame(f),f=null),D(),R(),l=null}}}const Et="http://schemas.microsoft.com/project",yr=8,eo=4800,br={0:"FF",1:"FS",2:"SF",3:"SS"},Tr={FF:0,FS:1,SF:2,SS:3};function to(e){return e?e.substring(0,10):""}function no(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(Et,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function vr(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function Sr(e){return`PT${e*yr}H0M0S`}function Ct(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function In(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(Et,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let h=0;h<l.length;h++){const y=l[h],b=Ee(y,"UID"),m=Ee(y,"Name");b&&m&&i.set(b,m)}const u=new Map,d=o.getElementsByTagNameNS(Et,"Assignment"),g=d.length>0?d:o.getElementsByTagName("Assignment");for(let h=0;h<g.length;h++){const y=g[h],b=Ee(y,"TaskUID"),m=Ee(y,"ResourceUID");if(b&&m){const T=i.get(m);T&&u.set(b,T)}}const p=[],r=[],c=o.getElementsByTagNameNS(Et,"Task"),f=c.length>0?c:o.getElementsByTagName("Task"),S=[];let v=1;for(let h=0;h<f.length;h++){const y=f[h],b=Ee(y,"UID"),m=Ee(y,"Name"),T=Ee(y,"Start"),w=Ee(y,"Finish"),k=Ee(y,"PercentComplete"),D=Ee(y,"Summary")==="1",E=Ee(y,"Milestone")==="1",C=parseInt(Ee(y,"OutlineLevel")||"0",10);if(b==="0"&&!m)continue;const M=`msp-${b}`,A=to(T),R=to(w);if(!A&&!E)continue;let N;C>0&&S[C-1]&&(N=S[C-1]),S[C]=M,S.length=C+1;const _={id:M,name:m||`Task ${b}`,startDate:A||R,endDate:R||A,progress:k?parseInt(k,10)/100:0,isMilestone:E,parentId:N,sortOrder:h},P=u.get(b);P&&(_.assignee=P),D&&(_.metadata={..._.metadata,isSummary:!0}),p.push(_);const x=y.getElementsByTagNameNS(Et,"PredecessorLink"),W=x.length>0?x:y.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],F=Ee(q,"PredecessorUID"),I=parseInt(Ee(q,"Type")||"1",10),O=Ee(q,"LinkLag"),L=O?parseInt(O,10):0;if(!F||F==="0")continue;const H={id:`msp-dep-${v++}`,source:`msp-${F}`,target:M,type:br[I]??"FS",lag:L!==0?L/eo:void 0};r.push(H)}}return{tasks:p,dependencies:r}}function Mn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(b){let m=1,T=b;for(;T!=null&&T.parentId;)m++,T=e.tasks.get(T.parentId);return m}const d=new Map,g=new Map;for(const b of a){const m=b.parentId??"__root__",T=(d.get(m)??0)+1;if(d.set(m,T),!b.parentId)g.set(b.id,String(T));else{const w=g.get(b.parentId)??"0";g.set(b.id,`${w}.${T}`)}}const p=new Set;for(const b of a)b.parentId&&p.add(b.parentId);const r=new Map;a.forEach((b,m)=>{r.set(b.id,m+1)});const c=new Map;for(const b of l){const m=c.get(b.target)??[];m.push(b),c.set(b.target,m)}const f=new Set;for(const b of a)b.assignee&&f.add(b.assignee);const S=Array.from(f),v=new Map;S.forEach((b,m)=>{v.set(b,m+1)});const h=[];h.push('<?xml version="1.0" encoding="UTF-8"?>'),h.push('<Project xmlns="http://schemas.microsoft.com/project">'),h.push(`  <Name>${Ct(n)}</Name>`),h.push(`  <Author>${Ct(s)}</Author>`),h.push(`  <CreationDate>${o}</CreationDate>`),h.push("  <CalendarUID>1</CalendarUID>"),h.push("  <Calendars>"),h.push("    <Calendar>"),h.push("      <UID>1</UID>"),h.push(`      <Name>${Ct(i)}</Name>`),h.push("      <IsBaseCalendar>1</IsBaseCalendar>"),h.push("    </Calendar>"),h.push("  </Calendars>"),h.push("  <Tasks>");for(const b of a){const m=r.get(b.id)??0,T=u(b),w=g.get(b.id)??"1",k=p.has(b.id),D=b.isMilestone??!1,E=no(b.startDate),C=no(b.endDate),M=vr(E,C),A=Sr(M),R=Math.round((b.progress??0)*100);h.push("    <Task>"),h.push(`      <UID>${m}</UID>`),h.push(`      <ID>${m}</ID>`),h.push(`      <Name>${Ct(b.name)}</Name>`),h.push(`      <Start>${b.startDate}T08:00:00</Start>`),h.push(`      <Finish>${b.endDate}T17:00:00</Finish>`),h.push(`      <Duration>${A}</Duration>`),h.push(`      <PercentComplete>${R}</PercentComplete>`),h.push(`      <Summary>${k?"1":"0"}</Summary>`),h.push(`      <Milestone>${D?"1":"0"}</Milestone>`),h.push(`      <OutlineLevel>${T}</OutlineLevel>`),h.push(`      <OutlineNumber>${w}</OutlineNumber>`);const N=c.get(b.id);if(N)for(const _ of N){const P=r.get(_.source)??0;if(P===0)continue;const x=Tr[_.type??"FS"]??1,W=Math.round((_.lag??0)*eo);h.push("      <PredecessorLink>"),h.push(`        <PredecessorUID>${P}</PredecessorUID>`),h.push(`        <Type>${x}</Type>`),h.push(`        <LinkLag>${W}</LinkLag>`),h.push("      </PredecessorLink>")}h.push("    </Task>")}h.push("  </Tasks>"),h.push("  <Resources>");for(const b of S){const m=v.get(b)??0;h.push("    <Resource>"),h.push(`      <UID>${m}</UID>`),h.push(`      <Name>${Ct(b)}</Name>`),h.push("    </Resource>")}h.push("  </Resources>"),h.push("  <Assignments>");let y=1;for(const b of a){if(!b.assignee)continue;const m=r.get(b.id)??0,T=v.get(b.assignee)??0;m===0||T===0||(h.push("    <Assignment>"),h.push(`      <UID>${y++}</UID>`),h.push(`      <TaskUID>${m}</TaskUID>`),h.push(`      <ResourceUID>${T}</ResourceUID>`),h.push("    </Assignment>"))}return h.push("  </Assignments>"),h.push("</Project>"),h.join(`
`)}function wr(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var d;const u=(d=l.target)==null?void 0:d.result;if(!(!u||!e))try{const g=In(u);e.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies})}catch(g){console.error("[MSProjectPlugin] Import failed:",g)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=In(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),d=Mn(u,a);l&&l(d)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),d=Mn(u,a),g=new Blob([d],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(g),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const kr=[4,3],Dr=1.5,Er=.5,Cr=.06,Ir=4,Mr=8,Ar=.35,Lr=1,so=.2,It=6,oo=864e5;function Be(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function io(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function An(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Ln(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Rr(e){let t=0;for(const n of e){const s=Be(n.startDate).getTime(),o=Be(n.endDate).getTime();t+=Math.max(o-s,oo)}return t}function Pr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=Be(l.startDate).getTime(),g=Be(s.startDate).getTime()-u,p=i.segments.map(r=>{const c=new Date(Be(r.startDate).getTime()+g),f=new Date(Be(r.endDate).getTime()+g);return{startDate:io(c),endDate:io(f)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,d=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==d){const g=i.segments.length-1;i.segments[g]={...i.segments[g],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:d,headerHeight:g,barHeight:p}=a,r=n.getTimeScale(),c=d.barBorderRadius,f=g;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-l,0);for(const S of i){if(S.isMilestone)continue;const v=t.get(S.taskId);if(!v||v.segments.length===0)continue;const h=S.barY-u,y=S.barHeight,b=h+y/2;if(h+y<f||h>s.canvas.height)continue;const m=[];for(const C of v.segments){const M=r.dateToX(Be(C.startDate)),A=r.dateToX(Be(C.endDate)),R=Math.max(A-M,4);m.push({startX:M,endX:M+R,width:R})}s.save(),s.fillStyle=d.timelineBg,s.fillRect(S.x-1,h-1,S.width+2,y+2),s.restore();for(let C=0;C<m.length-1;C++){const M=m[C].endX,A=m[C+1].startX,R=A-M;if(!(R<=0)){s.save(),s.globalAlpha=Cr,s.strokeStyle=S.color,s.lineWidth=Ir,s.beginPath(),s.rect(M,h,R,y),s.clip();for(let N=M-y;N<A+y;N+=Mr)s.beginPath(),s.moveTo(N,h+y),s.lineTo(N+y,h),s.stroke();s.restore()}}for(let C=0;C<m.length-1;C++){const M=m[C].endX,A=m[C+1].startX;s.save(),s.globalAlpha=Er,s.strokeStyle=An(S.color,so),s.lineWidth=Dr,s.setLineDash(kr),s.beginPath(),s.moveTo(M,b),s.lineTo(A,b),s.stroke(),s.setLineDash([]),s.restore()}const T=o.tasks.get(S.taskId),w=(T==null?void 0:T.progress)??0,k=Rr(v.segments);let E=w*k;for(let C=0;C<m.length;C++){const M=m[C],A=Math.max(Be(v.segments[C].endDate).getTime()-Be(v.segments[C].startDate).getTime(),oo);if(s.save(),Ln(s,M.startX,h,M.width,y,c),s.fillStyle=S.color,s.fill(),s.strokeStyle=An(S.color,so),s.lineWidth=Lr,s.stroke(),s.restore(),E>0&&a.showProgress){const R=Math.min(E,A),N=R/A,_=M.width*N;s.save(),Ln(s,M.startX,h,M.width,y,c),s.clip(),s.globalAlpha=Ar,s.fillStyle=An(S.color,.3),s.fillRect(M.startX,h,_,y),s.restore(),E-=R}}if(S.label){const C=m[0],M=m[m.length-1],A=M.endX-C.startX;s.save(),s.font=`${d.fontSize}px ${d.fontFamily}`;const N=s.measureText(S.label).width;s.textBaseline="middle",s.textAlign="left",N+It*2<=C.width?(s.fillStyle=S.textColor,Ln(s,C.startX,h,C.width,y,c),s.clip(),s.fillText(S.label,C.startX+It,b)):N+It<=A?(s.fillStyle=S.textColor,s.fillText(S.label,C.startX+It,b)):(s.fillStyle=d.gridTextColor,s.fillText(S.label,M.endX+It,b)),s.restore()}}s.restore()},destroy(){n=null}}}const Rn=864e5,ao=1e3,Ut=4,$r=.6,_r="#E53E3E",Nr="#48BB78",Or="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ft(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Yt(e,t){return Math.round((t.getTime()-e.getTime())/Rn)}function ro(e,t){return new Date(e.getTime()+t*Rn)}function Ze(e,t){return ft(ro(he(e),t))}function Xe(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ft(n)),o;for(;i.getTime()<s.getTime();)o.push(ft(i)),i.setTime(i.getTime()+Rn);return o}class Pn{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const d of s){const p=(i.get(d)??0)-o;p<=0?i.delete(d):i.set(d,p),(l=a.get(d))==null||l.delete(n),((u=a.get(d))==null?void 0:u.size)===0&&a.delete(d)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const d of s){let g=(a==null?void 0:a.get(d))??0;if((u=l==null?void 0:l.get(d))!=null&&u.has(n)&&(g-=o),g+o>i)return!1}return!0}}function Wt(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Hr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const d=parseInt(l,10);isNaN(d)||(u=d)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function lo(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function xr(e,t,n,s,o){const i=new Map;for(const h of s)e.has(h.taskId)&&n.has(h.resourceId)&&(i.has(h.taskId)||i.set(h.taskId,[]),i.get(h.taskId).push({resourceId:h.resourceId,units:h.units||1}));const a=new Map,l=new Map;for(const h of e.keys())a.set(h,[]),l.set(h,[]);for(const h of t.values()){if((h.type||"FS")!=="FS"||!e.has(h.source)||!e.has(h.target))continue;const b=h.lag||0;a.get(h.source).push({target:h.target,lag:b}),l.get(h.target).push({source:h.source,lag:b})}const u=new Map;for(const[h,y]of e){const b=he(y.startDate),m=he(y.endDate);u.set(h,{taskId:h,startDate:y.startDate,endDate:y.endDate,duration:Math.max(Yt(b,m),0)})}const d=new Pn;function g(){d.clear();for(const[h,y]of u){const b=i.get(h);if(!b)continue;const m=Xe(y.startDate,y.endDate);for(const T of b)d.allocate(T.resourceId,h,m,T.units)}}function p(h,y){const b=u.get(h);if(!b)return new Set;const m=new Set,T=b.startDate;if(y===T||he(y).getTime()<he(T).getTime())return m;const w=i.get(h);if(w){const k=Xe(b.startDate,b.endDate);for(const D of w)d.deallocate(D.resourceId,h,k,D.units)}if(b.startDate=y,b.endDate=Ze(y,b.duration),m.add(h),w){const k=Xe(b.startDate,b.endDate);for(const D of w)d.allocate(D.resourceId,h,k,D.units)}return m}function r(h){const y=new Set,b=u.get(h);if(!b)return y;const m=a.get(h)??[];for(const{target:T,lag:w}of m){const k=u.get(T);if(!k)continue;const D=Ze(b.endDate,w);if(he(k.startDate).getTime()<he(D).getTime()){const E=p(T,D);for(const C of E){y.add(C);const M=r(C);for(const A of M)y.add(A)}}}return y}function c(h){const y=l.get(h)??[];let b=u.get(h).startDate;b=e.get(h).startDate;for(const{source:T,lag:w}of y){const k=u.get(T);if(!k)continue;const D=Ze(k.endDate,w);he(D).getTime()>he(b).getTime()&&(b=D)}return b}g();for(let h=0;h<ao;h++){const y=Wt(d,n);if(y.length===0)break;let b=!1;const m=y[0],T=m.taskIds.map(w=>o.get(w)).filter(w=>w!==void 0).sort(lo);if(!(T.length<2))for(let w=1;w<T.length;w++){const k=T[w],D=u.get(k.taskId);if(!D)continue;const E=u.get(T[0].taskId);if(!E)continue;const C=E.endDate,M=c(k.taskId),A=he(C).getTime()>he(M).getTime()?C:M;he(A).getTime()>he(D.startDate).getTime()&&(p(k.taskId,A),r(k.taskId),b=!0);const R=d.getLoad(m.resourceId,m.date),N=n.get(m.resourceId).maxUnits;if(R<=N)break}}const f=new Map;let S=0;for(const[h,y]of u){const b=e.get(h),m=Yt(he(b.startDate),he(y.startDate));m!==0&&(f.set(h,{startDate:y.startDate,endDate:y.endDate,delayDays:m}),S+=m)}const v=Wt(d,n);return{adjustedTasks:f,totalDelay:S,conflicts:v,resolved:v.length===0}}function Br(e,t,n,s,o){const i=new Map;for(const y of s)e.has(y.taskId)&&n.has(y.resourceId)&&(i.has(y.taskId)||i.set(y.taskId,[]),i.get(y.taskId).push({resourceId:y.resourceId,units:y.units||1}));const a=new Map;for(const y of e.keys())a.set(y,[]);for(const y of t.values())(y.type||"FS")==="FS"&&(!e.has(y.source)||!e.has(y.target)||a.get(y.target).push({source:y.source,lag:y.lag||0}));const l=Array.from(e.keys()).map(y=>o.get(y)).filter(y=>y!==void 0).sort(lo),u=new Map,d=new Pn,g=new Set,p=new Map;for(const[y,b]of e)p.set(y,Math.max(Yt(he(b.startDate),he(b.endDate)),0));function r(y){let m=e.get(y).startDate;const T=a.get(y)??[];for(const{source:w,lag:k}of T){const D=u.get(w);if(!D)continue;const E=Ze(D.endDate,k);he(E).getTime()>he(m).getTime()&&(m=E)}return m}function c(y,b,m){const T=i.get(y);if(!T||T.length===0)return b;let w=b;const k=365*5;for(let D=0;D<k;D++){const E=Ze(w,m),C=Xe(w,E);let M=!0;for(const A of T){const R=n.get(A.resourceId);if(!R||R.maxUnits===0)continue;const N=R.calendar?new Set(R.calendar):null;if(N&&C.some(P=>N.has(P))){M=!1;break}if(!d.canFit(A.resourceId,y,C,A.units,R.maxUnits)){M=!1;break}}if(M)return w;w=Ze(w,1)}return b}const f=new Set(l.map(y=>y.taskId));for(let y=0;y<ao&&f.size>0;y++){let b=!1;for(const m of l){if(!f.has(m.taskId)||!(a.get(m.taskId)??[]).every(R=>g.has(R.source)))continue;const k=m.taskId,D=p.get(k)??0,E=r(k),C=c(k,E,D),M=Ze(C,D);u.set(k,{taskId:k,startDate:C,endDate:M,duration:D});const A=i.get(k);if(A){const R=Xe(C,M);for(const N of A)d.allocate(N.resourceId,k,R,N.units)}g.add(k),f.delete(k),b=!0}if(!b){for(const m of f){const T=e.get(m),w=p.get(m)??0;u.set(m,{taskId:m,startDate:T.startDate,endDate:T.endDate,duration:w});const k=i.get(m);if(k){const D=Xe(T.startDate,T.endDate);for(const E of k)d.allocate(E.resourceId,m,D,E.units)}g.add(m)}f.clear()}}const S=new Map;let v=0;for(const[y,b]of u){const m=e.get(y),T=Yt(he(m.startDate),he(b.startDate));T!==0&&(S.set(y,{startDate:b.startDate,endDate:b.endDate,delayDays:T}),v+=T)}const h=Wt(d,n);return{adjustedTasks:S,totalDelay:v,conflicts:h,resolved:h.length===0}}function Fr(e,t,n,s){const o=[],i=Xe(n,Ze(s,1)),a=i.length;for(const[l,u]of t){const d=new Map;let g=0,p=0;for(const f of i){const S=e.getLoad(l,f);d.set(f,S),g+=S,S>p&&(p=S)}const r=u.maxUnits===0?1:u.maxUnits,c=a>0?g/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:d,overallUtilization:Math.min(c,1),peakUtilization:p})}return o}function co(e,t,n,s){const o=new Pn,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const d=s.get(a),g=(d==null?void 0:d.startDate)??l.startDate,p=(d==null?void 0:d.endDate)??l.endDate,r=Xe(g,p);for(const c of u)o.allocate(c.resourceId,a,r,c.units)}return o}function Ur(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function d(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:f}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const S=u(),v=Hr(c,S,n);s==="parallel"?i=Br(c,f,t,e.assignments,v):i=xr(c,f,t,e.assignments,v);const h=g(c,i.adjustedTasks),y=co(c,t,e.assignments,i.adjustedTasks);return a=Fr(y,t,h.start,h.end),i}function g(r,c){let f=1/0,S=-1/0;for(const[v,h]of r){const y=c.get(v),b=he((y==null?void 0:y.startDate)??h.startDate).getTime(),m=he((y==null?void 0:y.endDate)??h.endDate).getTime();b<f&&(f=b),m>S&&(S=m)}if(f===1/0){const v=ft(new Date);return{start:v,end:v}}return{start:ft(new Date(f)),end:ft(new Date(S))}}function p(r){const c=[];for(const f of e.assignments)f.taskId===r&&c.push(f.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,d(),l.push(r.on("resourceLeveling:run",(...c)=>{const f=c[0],S=d();f&&f(S)})),l.push(r.on("resourceLeveling:result",(...c)=>{const f=c[0];f&&f(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const f=c[0];f&&f(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const f=c[0];if(!f)return;const S=r.getState(),v=co(S.tasks,t,e.assignments,new Map);f(Wt(v,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&d()},renderCanvas(r,c,f){if(!i||a.length===0)return;const{config:S}=c,{headerHeight:v,rowHeight:h}=S,y=c.scrollX,b=c.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,v,r.canvas.width,r.canvas.height-v),r.clip(),r.translate(-y,0);const T=new Map;for(const w of a)T.set(w.resourceId,w);for(const w of f){const k=p(w.taskId);if(k.length===0)continue;const D=T.get(k[0]);if(!D)continue;const E=t.get(k[0]);if(!E)continue;const C=E.maxUnits===0?1:E.maxUnits,A=w.barY+w.barHeight-b+1;if(A+Ut<v||A>r.canvas.height)continue;const R=c.tasks.get(w.taskId);if(!R)continue;const N=i.adjustedTasks.get(w.taskId),_=(N==null?void 0:N.startDate)??R.startDate,P=(N==null?void 0:N.endDate)??R.endDate,x=m.dateToX(he(_)),K=m.dateToX(he(P))-x;if(K<2)continue;r.fillStyle=Or,r.fillRect(x,A,K,Ut);const q=Xe(_,P);for(const F of q){const I=D.dailyLoad.get(F)??0;if(I===0)continue;const O=m.dateToX(he(F)),H=m.dateToX(ro(he(F),1))-O,ee=Math.min(I/C,2)/2*Ut,Z=I>C;r.globalAlpha=$r,r.fillStyle=Z?_r:Nr,r.fillRect(O,A+Ut-ee,H,ee),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const uo=864e5;function ye(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Je(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function go(e,t){return Math.round((ye(t).getTime()-ye(e).getTime())/uo)}function ho(e,t){return Je(new Date(ye(e).getTime()+t*uo))}function fo(){return{addDays:ho,daysBetween:go}}function $n(e,t,...n){try{const s=e;if(typeof s.emit=="function")return s.emit(t,...n),!0}catch{}return!1}function po(e,t){const n=new Map,s=new Map,o=new Map;for(const d of e)n.set(d,[]),s.set(d,[]),o.set(d,0);for(const d of t.values()){if(!e.has(d.source)||!e.has(d.target))continue;const g={source:d.source,target:d.target,type:d.type||"FS",lag:d.lag||0,depId:d.id};n.get(d.source).push(g),s.get(d.target).push(g),o.set(d.target,(o.get(d.target)||0)+1)}const i=new Map(o),a=[],l=[];for(const d of e)i.get(d)===0&&a.push(d);for(;a.length>0;){const d=a.shift();l.push(d);for(const g of n.get(d)){const p=i.get(g.target)-1;i.set(g.target,p),p===0&&a.push(g.target)}}const u=new Set;for(const d of e)l.includes(d)||u.add(d);return{successors:n,predecessors:s,inDegree:o,circularTaskIds:u,topoOrder:l}}function _n(e,t,n,s){const o=new Set(e.keys()),i=[],a=new Map;if(o.size===0)return{scheduledTasks:a,violations:i,projectStart:n.projectStart||Je(new Date),projectEnd:n.projectStart||Je(new Date),totalDuration:0};const l=n.constraints||new Map,u=po(o,t);for(const b of u.circularTaskIds){const m=e.get(b);i.push({taskId:b,type:"circular",message:`Task "${(m==null?void 0:m.name)||b}" is part of a circular dependency chain`})}const d=new Map;for(const[b,m]of e){const T=s.daysBetween(m.startDate,m.endDate);d.set(b,Math.max(T,0))}let g;if(n.projectStart)g=n.projectStart;else{let b=1/0;for(const m of e.values()){const T=ye(m.startDate).getTime();T<b&&(b=T)}g=Je(new Date(b))}const p=new Map,r=new Map,c=new Set;for(const[b,m]of e)p.set(b,m.startDate),r.set(b,m.endDate);for(const b of u.topoOrder){const m=e.get(b),T=d.get(b),w=l.get(b),k=u.predecessors.get(b);let D;if(k.length===0)D=g;else{let C=g;for(const M of k){const A=p.get(M.source),R=r.get(M.source);let N;switch(M.type){case"FS":N=s.addDays(R,M.lag);break;case"SS":N=s.addDays(A,M.lag);break;case"FF":{const _=s.addDays(R,M.lag);N=s.addDays(_,-T);break}case"SF":{const _=s.addDays(A,M.lag);N=s.addDays(_,-T);break}default:N=s.addDays(R,M.lag)}ye(N).getTime()>ye(C).getTime()&&(C=N)}D=C}if(w)switch(w.type){case"ASAP":break;case"ALAP":c.add(b);break;case"SNET":w.date&&ye(D).getTime()<ye(w.date).getTime()&&(D=w.date);break;case"SNLT":w.date&&ye(D).getTime()>ye(w.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" cannot start by ${w.date} (earliest possible: ${D}). SNLT constraint violated.`});break;case"MSO":w.date&&(ye(D).getTime()>ye(w.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" has MSO constraint ${w.date} but dependencies require start no earlier than ${D}.`}),D=w.date);break;case"FNET":{if(w.date){const C=s.addDays(w.date,-T);ye(D).getTime()<ye(C).getTime()&&(D=C)}break}case"FNLT":{if(w.date){const C=s.addDays(D,T);ye(C).getTime()>ye(w.date).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" cannot finish by ${w.date} (earliest finish: ${C}). FNLT constraint violated.`})}break}case"MFO":if(w.date){const C=s.addDays(w.date,-T);ye(D).getTime()>ye(C).getTime()&&i.push({taskId:b,type:"constraint",message:`Task "${m.name}" has MFO constraint ${w.date} but dependencies require start no earlier than ${D} (finish would be ${s.addDays(D,T)}).`}),D=C}break}const E=s.addDays(D,T);p.set(b,D),r.set(b,E)}if(c.size>0){let b=-1/0;for(const T of r.values()){const w=ye(T).getTime();w>b&&(b=w)}const m=Je(new Date(b));for(let T=u.topoOrder.length-1;T>=0;T--){const w=u.topoOrder[T];if(!c.has(w))continue;const k=d.get(w),D=u.successors.get(w);let E;if(D.length===0)E=s.addDays(m,-k);else{let M=1/0;for(const A of D){const R=p.get(A.target);let N;switch(A.type){case"FS":N=s.addDays(R,-A.lag);break;case"SS":N=s.addDays(s.addDays(R,-A.lag),k);break;case"FF":N=s.addDays(r.get(A.target),-A.lag);break;case"SF":N=s.addDays(s.addDays(r.get(A.target),-A.lag),k);break;default:N=s.addDays(R,-A.lag)}const _=s.addDays(N,-k),P=ye(_).getTime();P<M&&(M=P)}E=Je(new Date(M))}const C=p.get(w);ye(E).getTime()<ye(C).getTime()&&(E=C),p.set(w,E),r.set(w,s.addDays(E,k))}}for(const b of o)a.set(b,{startDate:p.get(b),endDate:r.get(b)});let f=1/0,S=-1/0;for(const{startDate:b,endDate:m}of a.values()){const T=ye(b).getTime(),w=ye(m).getTime();T<f&&(f=T),w>S&&(S=w)}const v=Je(new Date(f)),h=Je(new Date(S)),y=s.daysBetween(v,h);return{scheduledTasks:a,violations:i,projectStart:v,projectEnd:h,totalDuration:y}}function Yr(e){const t={respectWorkCalendar:!1,autoRun:!0,...e};let n,s,o=null,i=[];function a(){if(!t.respectWorkCalendar){s=fo();return}let g=null;$n(n,"calendar:addWorkDays","2026-01-05",1,p=>{g=p}),g!==null?s={addDays(p,r){let c=ho(p,r);return $n(n,"calendar:addWorkDays",p,r,f=>{c=f}),c},daysBetween(p,r){let c=go(p,r);return $n(n,"calendar:workDaysBetween",p,r,f=>{c=f}),c}}:s=fo()}function l(){const g=n.getState(),p=_n(g.tasks,g.dependencies,t,s);o=p;for(const[r,c]of p.scheduledTasks){const f=g.tasks.get(r);f&&(f.startDate!==c.startDate||f.endDate!==c.endDate)&&n.dispatch({type:"TASK_MOVE",taskId:r,startDate:c.startDate,endDate:c.endDate})}return p}function u(){const g=n.getState(),p=_n(g.tasks,g.dependencies,t,s);return o=p,p}function d(g,p){p(g),t.autoRun!==!1&&(g.type==="ADD_DEPENDENCY"||g.type==="REMOVE_DEPENDENCY")&&l()}return{name:"AutoSchedulePlugin",install(g){n=g,a(),i.push(n.on("autoSchedule:run",(...p)=>{const r=p[0],c=l();r&&r(c)})),i.push(n.on("autoSchedule:preview",(...p)=>{const r=p[0],c=u();r&&r(c)})),i.push(n.on("autoSchedule:result",(...p)=>{const r=p[0];r&&r(o)})),i.push(n.on("autoSchedule:setConstraint",(...p)=>{const r=p[0],c=p[1];t.constraints||(t.constraints=new Map),c?t.constraints.set(r,c):t.constraints.delete(r)})),i.push(n.on("autoSchedule:setConstraints",(...p)=>{const r=p[0];t.constraints=r}))},middleware:d,destroy(){for(const g of i)g();i=[],o=null}}}const Wr=864e5,Xr=75,zr=50,mo=25,Xt=.3,zt=.25,yo=.2,Nn=.15,Gt=.1,Gr=.3,bo=.5,Vr=20,To=40,Kr=3,jr=5,qr=30,vo=.25,So=4,Zr=2,Jr=5,On=5,wo=4,ko=.4,Qr=.003,Qe=260,pt=260,Do=16,ze=14,el="rgba(30, 30, 46, 0.92)",Hn="#e0e0e0",tl=10,Vt=32,nl=6,Kt="#EF4444",jt="#F97316",qt="#EAB308",Zt="#22C55E";function we(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ie(e,t){return Math.round((t.getTime()-e.getTime())/Wr)}function Ce(e,t,n){return Math.max(t,Math.min(n,e))}function sl(e){return e>=Xr?"critical":e>=zr?"high":e>=mo?"medium":"low"}function ol(e){switch(e){case"critical":return Kt;case"high":return jt;case"medium":return qt;case"low":return Zt}}function Jt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function il(e,t){const n=new Map,s=new Map;for(const h of e.keys())n.set(h,[]),s.set(h,[]);for(const h of t.values())!e.has(h.source)||!e.has(h.target)||(n.get(h.source).push(h.target),s.get(h.target).push(h.source));const o=new Map,i=new Set;function a(h){if(o.has(h))return o.get(h);if(i.has(h))return 0;i.add(h);let y=0;for(const b of n.get(h)||[])y+=1+a(b);return o.set(h,y),y}for(const h of e.keys())a(h);const l=new Map;for(const[h,y]of e){const b=we(y.startDate),m=we(y.endDate);l.set(h,Math.max(Ie(b,m),0))}const u=new Map,d=new Map,g=new Map;for(const h of e.keys())g.set(h,(s.get(h)||[]).length),u.set(h,l.get(h)||0),d.set(h,null);const p=[],r=new Map(g);for(const[h,y]of r)y===0&&p.push(h);for(;p.length>0;){const h=p.shift();for(const y of n.get(h)||[]){const b=u.get(h)+(l.get(y)||0);b>u.get(y)&&(u.set(y,b),d.set(y,h));const m=r.get(y)-1;r.set(y,m),m===0&&p.push(y)}}const c=new Set;let f=0,S=null;for(const[h,y]of u)y>f&&(f=y,S=h);let v=S;for(;v!==null;)c.add(v),v=d.get(v)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function al(e){const t=Jt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=we(o.startDate),a=we(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function rl(e,t,n){const s=[],o=Jt(),i=we(e.startDate),a=we(e.endDate),l=Math.max(Ie(i,a),1),u=Math.max(Ie(i,o),0),d=Math.max(Ie(o,a),0),g=e.progress??0;if(e.isCompleted||g>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=Ie(a,o);p=Ce(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*Xt)})}else{const D=d/l;D<.2&&g<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(g*100)}% complete`,impact:Math.round(p*Xt)})):(p=Ce(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*Xt)}))}let c=0;const f=Ce(u/l,0,1),S=f-g;S>bo?(c=Ce(Math.round(S*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(S*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(g*100)}%)`,impact:Math.round(c*zt)})):S>Gr?(c=Ce(Math.round(S*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(S*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(g*100)}%)`,impact:Math.round(c*zt)})):S>.1&&(c=Ce(Math.round(S*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(g*100)}%`,impact:Math.round(c*zt)}));let v=0;const h=t.downstreamCount.get(e.id)||0,y=t.criticalPathIds.has(e.id);if(h>0){v=Ce(Math.round(Math.log2(h+1)*20),0,70),y&&(v=Ce(Math.round(v*1.5),0,100));const D=y?" (on critical path)":"";s.push({type:"dependency-chain",description:`${h} downstream dependent${h===1?"":"s"}${D}`,impact:Math.round(v*yo)})}let b=0;l>To?(b=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(b*Nn)})):l>Vr&&(b=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(b*Nn)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*Gt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>jr?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Gt)})):D.length>Kr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Gt)}))}const T=Ce(Math.round(p*Xt+c*zt+v*yo+b*Nn+m*Gt),0,100),w=sl(T);let k;return r&&g===0?k="Task is overdue with no progress — escalate immediately":r?k="Task is past its deadline — review scope or extend timeline":S>bo?k="Task is significantly behind schedule — investigate blockers":l>To&&g<vo?k="Large task with little progress — consider splitting into smaller work items":(w==="high"||w==="critical")&&(k="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:w,riskScore:T,factors:s,suggestion:k}}function ll(e,t,n,s,o){const i=Jt();let a=0,l=0,u=0;for(const[y,b]of e){if(b.isCompleted||(b.progress??0)>=1)continue;l++;const m=we(b.startDate),T=we(b.endDate),w=Math.max(Ie(m,T),1),k=Math.max(Ie(m,i),0),D=Ce(k/w,0,1);(b.progress??0)>=D-.1&&a++;const C=t.get(y);C&&(C.riskLevel==="high"||C.riskLevel==="critical")&&u++}const d=l>0?a/l:1;let g=0;for(const y of n.criticalPathIds){const b=e.get(y);if(!b||b.isCompleted)continue;const m=we(b.endDate);i.getTime()>m.getTime()&&(g+=Ie(m,i))}const p=[],r=[];for(const[y,b]of s.activeTasks)p.push(b.length),b.length>So&&r.push(y);let c=100;if(p.length>1){const y=p.reduce((b,m)=>b+m,0)/p.length;if(y>0){const b=p.reduce((T,w)=>T+(w-y)**2,0)/p.length,m=Math.sqrt(b)/y;c=Ce(Math.round(100-m*50),0,100)}}let f=100;if(l>0){let y=0,b=0,m=0;for(const T of e.values()){if(T.isCompleted)continue;const w=we(T.startDate),k=we(T.endDate),D=Math.max(Ie(w,k),1),E=Math.max(Ie(w,i),0),C=Ce(E/D,0,2);y+=T.progress??0,b+=C,m++}if(m>0){const T=y/m,w=b/m;if(w>0){const k=T/w;f=Ce(Math.round(k*100),0,100)}}}const S=d*100,v=Ce(100-g*10,0,100);return{overallScore:Ce(Math.round(S*.25+v*.25+c*.25+f*.25),0,100),tasksAtRisk:u,criticalPathDelay:g,resourceBottlenecks:r,recommendations:o}}function cl(e,t,n,s){const o=[],i=Jt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const c=we(r.endDate),f=Ie(c,i),S=r.progress??0;f>Jr&&S===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const c=we(r.startDate),f=we(r.endDate),S=Ie(c,f),v=r.progress??0;if(S>qr&&v<vo){const h=Math.ceil(S/15);o.push({type:"split",description:`"${r.name}" spans ${S} days — split into ${h} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>So?l.push({assignee:p,taskIds:r}):r.length<Zr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const c=r.filter(f=>!t.criticalPathIds.has(f));c.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const c=we(r.endDate),f=Ie(i,c);if(f>=0&&f<=5){const S=s.get(p);S&&S.riskScore>=mo&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[p],priority:a++})}}const d=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>we(p.startDate).getTime()-we(r.startDate).getTime()),g=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const c of r)g.add(`${c}->${p}`);for(let p=0;p<d.length;p++)for(let r=p+1;r<d.length;r++){const c=d[p],f=d[r],S=we(c.endDate),v=we(f.startDate);if(S.getTime()<=v.getTime()&&!(g.has(`${c.id}->${f.id}`)||g.has(`${f.id}->${c.id}`))){const y=Ie(S,v);y>0&&o.push({type:"parallel",description:`"${c.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${y} days on the critical path`,taskIds:[c.id,f.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function dl(e,t,n,s,o,i,a){if(e.save(),i){const l=ko+(1-ko)*(.5+.5*Math.sin(a*Qr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function ul(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,d=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const g=i>=75?Zt:i>=50?qt:i>=25?jt:Kt;e.beginPath(),e.arc(t,n,s,a,d),e.strokeStyle=g,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=Hn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function gl(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Kt,label:"Critical"},{count:o.high,color:jt,label:"High"},{count:o.medium,color:qt,label:"Medium"},{count:o.low,color:Zt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const d=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+d),e.closePath(),e.fillStyle=u.color,e.fill(),l+=d}}function hl(e,t,n,s,o){const i=t-Qe-Do,a=n+Do;e.save(),e.beginPath();const l=tl;e.moveTo(i+l,a),e.lineTo(i+Qe-l,a),e.arcTo(i+Qe,a,i+Qe,a+l,l),e.lineTo(i+Qe,a+pt-l),e.arcTo(i+Qe,a+pt,i+Qe-l,a+pt,l),e.lineTo(i+l,a+pt),e.arcTo(i,a+pt,i,a+pt-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=el,e.fill(),e.fillStyle=Hn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+ze,a+ze);const u=i+ze+Vt+4,d=a+ze+20+Vt+8;ul(e,u,d,Vt,nl,s.overallScore);const g=24,p=i+Qe-ze-g-4,r=d;gl(e,p,r,g,o),e.font="9px sans-serif",e.textAlign="center";const c=r+g+8,f=[{count:o.critical,color:Kt,label:"C"},{count:o.high,color:jt,label:"H"},{count:o.medium,color:qt,label:"M"},{count:o.low,color:Zt,label:"L"}],S=28,v=p-f.length*S/2+S/2;for(let m=0;m<f.length;m++){const T=f[m],w=v+m*S;e.fillStyle=T.color,e.fillText(`${T.label}:${T.count}`,w,c)}const h=d+Vt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+ze,h);const y=h+18;e.font="10px sans-serif",e.fillStyle=Hn,e.fillText("Recommendations:",i+ze,y);const b=s.recommendations.slice(0,3);for(let m=0;m<b.length;m++){const T=b[m],w=y+14+m*16,k=T.type==="escalate"?"⚠":T.type==="split"?"✂":T.type==="reassign"?"⇄":T.type==="parallel"?"⇉":T.type==="add-buffer"?"⏱":"ℹ",D=34,E=T.description.length>D?T.description.substring(0,D-1)+"…":T.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${k} ${E}`,i+ze,w)}b.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+ze,y+14)),e.restore()}function fl(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:d,dependencies:g}=u;if(d.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=il(d,g),r=al(d),c=new Map;for(const[f,S]of d)c.set(f,rl(S,p,r));n=c,o=cl(d,p,r,n),s=ll(d,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",d=>{typeof d=="function"&&d(n)})),t.push(e.on("risk:health",d=>{typeof d=="function"&&d(s)})),t.push(e.on("risk:recommendations",d=>{typeof d=="function"&&d(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,d){d(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,d,g){if(n.size===0)return;const{headerHeight:p}=d.config,r=d.scrollX,c=d.scrollY,f=p,S=Date.now()-a;u.save(),u.beginPath(),u.rect(0,f,u.canvas.width,u.canvas.height-f),u.clip(),u.translate(-r,0);for(const v of g){const h=n.get(v.taskId);if(!h||h.riskLevel==="low")continue;const y=v.x,b=v.barY-c,m=v.width,T=v.barHeight;if(b+T<f||b>u.canvas.height||y+m<0)continue;const w=y+m-On-wo,k=b+On+wo,D=ol(h.riskLevel),E=h.riskLevel==="critical";dl(u,w,k,On,D,E,S)}if(u.restore(),i){const v={critical:0,high:0,medium:0,low:0};for(const h of n.values())v[h.riskLevel]++;u.save(),hl(u,u.canvas.width,p,s,v),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const $e=160,et=80,xn=8,pl=240,ml=160,yl=100,bl=200,Qt=8,Eo=.1,Co=3,Tl=.001,vl=500,Sl=5,wl=864e5,kl={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function Io(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Dl(e,t){return Math.round((t.getTime()-e.getTime())/wl)}function Mo(e,t,n){return e+(t-e)*n}function en(e,t,n){return Math.max(t,Math.min(n,e))}function Bn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function El(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const d of s.get(l)){const g=n.get(d),p=u+1;(g===void 0||p>g)&&n.set(d,p);const r=i.get(d)-1;i.set(d,r),r===0&&a.push(d)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function Cl(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function Il(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<Sl;a++){for(let l=1;l<e.length;l++){const u=e[l],d=new Map;for(const g of u){const p=o.get(g);if(p.size===0){d.set(g,i.get(g)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(g,r/p.size)}u.sort((g,p)=>(d.get(g)??0)-(d.get(p)??0));for(let g=0;g<u.length;g++)i.set(u[g],g)}for(let l=e.length-2;l>=0;l--){const u=e[l],d=new Map;for(const g of u){const p=s.get(g);if(p.size===0){d.set(g,i.get(g)??0);continue}let r=0;for(const c of p)r+=i.get(c)??0;d.set(g,r/p.size)}u.sort((g,p)=>(d.get(g)??0)-(d.get(p)??0));for(let g=0;g<u.length;g++)i.set(u[g],g)}}}function Ml(e,t){const n=new Map;if(t==="radial")return Al(e);const s=t==="lr",o=s?pl:ml,i=s?yl:bl;for(let a=0;a<e.length;a++){const l=e[a],g=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],c=g+p*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function Al(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function Mt(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function Ll(e,t){return e.color?e.color:e.status&&(t[e.status]||kl[e.status])||"#94A3B8"}function Rl(e){const t=Io(e.startDate),n=Io(e.endDate);return Math.max(Dl(t,n),0)}function Pl(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,d=new Map,g=[],p=null,r=0,c=0,f=1,S=!1,v=0,h=0,y=0,b=0,m=null,T=0,w=0,k=null,D=null,E=new Set,C=!1,M=0,A=0,R=0,N=0;function _(X,$){return{x:(X-r)/f,y:($-c)/f}}function P(X,$){const{x:B,y:z}=_(X,$);for(const G of d.values()){const V=G.x,ne=G.y;if(B>=V&&B<=V+$e&&z>=ne&&z<=ne+et)return G}return null}function x(){const X=e.getState(),{tasks:$,dependencies:B,config:z}=X;if($.size===0){d=new Map,g=[];return}p=Tn($,B);const G=El($,B),V=Cl(G);Il(V,B,$);const ne=Ml(V,s);let oe=1/0,ae=-1/0,le=1/0,me=-1/0;for(const{x:ue,y:De}of ne.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+$e),le=Math.min(le,De),me=Math.max(me,De+et);const Se=(oe+ae)/2,Ae=(le+me)/2,Le=d;d=new Map;for(const[ue,De]of $){const Re=ne.get(ue);if(!Re)continue;const Ke=Re.x-Se,it=Re.y-Ae,Fe=Le.get(ue);d.set(ue,{id:ue,task:De,layer:G.get(ue)??0,orderInLayer:0,x:Fe?Fe.x:Ke,y:Fe?Fe.y:it,targetX:Ke,targetY:it,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let De=0;De<ue.length;De++){const Re=d.get(ue[De]);Re&&(Re.orderInLayer=De)}g=[];for(const ue of B.values())!$.has(ue.source)||!$.has(ue.target)||g.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const $=e.getState(),B=new Set;B.add(X);const z=new Map,G=new Map;for(const oe of $.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of $.dependencies.values())!$.tasks.has(oe.source)||!$.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])B.has(ae)||(B.add(ae),V.push(ae))}const ne=[X];for(;ne.length>0;){const oe=ne.shift();for(const ae of z.get(oe)||[])B.has(ae)||(B.add(ae),ne.push(ae))}return B}function K(){C&&cancelAnimationFrame(A),C=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,$=en(X/vl,0,1),B=1-Math.pow(1-$,3);let z=!1;for(const G of d.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),ne=Math.abs(G.y-G.targetY);V>.5||ne>.5?(G.x=Mo(G.x,G.targetX,B),G.y=Mo(G.y,G.targetY,B),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(F(),z&&$<1)A=requestAnimationFrame(q);else{C=!1;for(const G of d.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);F()}}function F(){if(!i||!o)return;const X=e.getState(),{config:$}=X,B=$.theme,z=$.colorMap,G=B.timelineBg==="#1A202C"||B.gridBg==="#1A202C"||B.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(B.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,R,N),i.save(),i.translate(r,c),i.scale(f,f);for(const V of g){const ne=d.get(V.sourceId),oe=d.get(V.targetId);if(!ne||!oe)continue;const ae=E.has(V.sourceId)&&E.has(V.targetId),le=k===V.sourceId||k===V.targetId,me=k!==null&&!le||D!==null&&!ae,Se=ne.x+$e,Ae=ne.y+et/2,Le=oe.x,ue=oe.y+et/2;i.save(),me?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=B.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const De=(Se+Le)/2;i.beginPath(),i.moveTo(Se,Ae),i.quadraticCurveTo(De,Ae,(Se+Le)/2,(Ae+ue)/2),i.quadraticCurveTo(De,ue,Le,ue),i.stroke();const Re=Math.atan2(ue-(Ae+ue)/2,Le-De);i.beginPath(),i.moveTo(Le,ue),i.lineTo(Le-Qt*Math.cos(Re-Math.PI/6),ue-Qt*Math.sin(Re-Math.PI/6)),i.lineTo(Le-Qt*Math.cos(Re+Math.PI/6),ue-Qt*Math.sin(Re+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Ke=V.dep.type||"FS",it=V.dep.lag||0,Fe=it!==0?`${Ke} +${it}d`:Ke!=="FS"?Ke:"";if(Fe&&!me){const Rt=(Se+Le)/2,ns=(Ae+ue)/2-8;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Fe,Rt,ns)}i.restore()}for(const V of d.values()){const ne=k!==null&&k!==V.id&&!O(k,V.id)||D!==null&&!E.has(V.id),oe=k===V.id,ae=D===V.id,le=Ll(V.task,z),me=V.x,Se=V.y;i.save(),ne&&(i.globalAlpha=.25),V.isCritical&&!ne&&(i.save(),i.shadowColor=B.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Mt(i,me,Se,$e,et,xn),i.fillStyle="transparent",i.fill(),i.restore()),Mt(i,me,Se,$e,et,xn),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=B.selectionColor||"#3182CE",i.lineWidth=2,Mt(i,me-2,Se-2,$e+4,et+4,xn+2),i.stroke()),i.font=`600 12px ${B.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ae=Bn(i,V.task.name,$e-20);i.fillText(Ae,me+10,Se+8);const Le=Se+26;i.beginPath(),i.arc(me+16,Le+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(Bn(i,ue,$e-40),me+24,Le);const De=Rl(V.task),Re=De===1?"1 day":`${De} days`;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Re,me+10,Se+42),V.task.assignee&&(i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(Bn(i,V.task.assignee,$e/2-10),me+$e-10,Se+42));const Ke=V.task.progress??0,it=Se+et-6,Fe=$e-20,Rt=3;if(Mt(i,me+10,it,Fe,Rt,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),Ke>0){const ns=Math.max(Rt,Fe*en(Ke,0,1));Mt(i,me+10,it,ns,Rt,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),I(G,B.fontFamily)}function I(X,$){if(!i)return;const B={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${$}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${B[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,R-12,12),i.restore()}function O(X,$){for(const B of g)if(B.sourceId===X&&B.targetId===$||B.sourceId===$&&B.targetId===X)return!0;return!1}function L(X){l=X;const $=X.querySelector(".ng-timeline-panel");if(!$)return;u=$.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",$.appendChild(o);const B=o.getContext("2d");B&&(i=B,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",be),o.addEventListener("mouseup",Y),o.addEventListener("mouseleave",te),o.addEventListener("dblclick",j),o.addEventListener("wheel",Q,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function H(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(R=X.clientWidth,N=X.clientHeight,o.width=Math.round(R*a),o.height=Math.round(N*a),o.style.width=`${R}px`,o.style.height=`${N}px`)}function U(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),H(),Z(),x();for(const X of d.values())X.x=X.targetX,X.y=X.targetY;F()}}function ee(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),k=null,D=null,E=new Set)}function Z(){r=R/2,c=N/2,f=1}function re(X){if(!o)return{x:0,y:0};const $=o.getBoundingClientRect();return{x:X.clientX-$.left,y:X.clientY-$.top}}function ge(X){const{x:$,y:B}=re(X),z=P($,B);z?(m=z,z.isDragging=!0,T=_($,B).x-z.x,w=_($,B).y-z.y,D=z.id,E=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),F()):(S=!0,v=$,h=B,y=r,b=c,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),F()))}function be(X){if(!o)return;const{x:$,y:B}=re(X);if(m){const V=_($,B);m.x=V.x-T,m.y=V.y-w,m.targetX=m.x,m.targetY=m.y,F();return}if(S){const V=$-v,ne=B-h;r=y+V,c=b+ne,F();return}const z=P($,B),G=z?z.id:null;G!==k&&(k=G,o.style.cursor=k?"pointer":"default",F())}function Y(X){m&&(m.isDragging=!1,m=null),S=!1}function te(X){m&&(m.isDragging=!1,m=null),S=!1,k&&(k=null,F())}function j(X){const{x:$,y:B}=re(X),z=P($,B);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function Q(X){if(X.preventDefault(),!o)return;const{x:$,y:B}=re(X),z=_($,B),G=-X.deltaY*Tl;f=en(f+G*f,Eo,Co);const V=_($,B);r+=(V.x-z.x)*f,c+=(V.y-z.y)*f,F()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const $=X.touches[0],B=o.getBoundingClientRect(),z=$.clientX-B.left,G=$.clientY-B.top,V=P(z,G);V?(m=V,V.isDragging=!0,T=_(z,G).x-V.x,w=_(z,G).y-V.y,D=V.id,E=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(S=!0,v=z,h=G,y=r,b=c),F()}else if(X.touches.length===2){S=!1,m&&(m.isDragging=!1,m=null);const $=X.touches[0],B=X.touches[1];se=Math.hypot(B.clientX-$.clientX,B.clientY-$.clientY),de=($.clientX+B.clientX)/2,ie=($.clientY+B.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const $=o.getBoundingClientRect();if(X.touches.length===1){const B=X.touches[0],z=B.clientX-$.left,G=B.clientY-$.top;if(m){const V=_(z,G);m.x=V.x-T,m.y=V.y-w,m.targetX=m.x,m.targetY=m.y,F()}else if(S){const V=z-v,ne=G-h;r=y+V,c=b+ne,F()}}else if(X.touches.length===2){const B=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-B.clientX,z.clientY-B.clientY),V=(B.clientX+z.clientX)/2,ne=(B.clientY+z.clientY)/2,oe=V-$.left,ae=ne-$.top;if(se>0){const le=G/se,me=_(oe,ae);f=en(f*le,Eo,Co);const Se=_(oe,ae);r+=(Se.x-me.x)*f,c+=(Se.y-me.y)*f}r+=V-de,c+=ne-ie,se=G,de=V,ie=ne,F()}}function Te(X){m&&(m.isDragging=!1,m=null),S=!1,se=0}function ve(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",be),o.removeEventListener("mouseup",Y),o.removeEventListener("mouseleave",te),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",Q),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),C&&(cancelAnimationFrame(A),C=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?ee():U()})),t.push(e.on("networkGraph:layout",(...$)=>{const B=$[0];B!==s&&(s=B,n&&(x(),K()))})),t.push(e.on("stateChange",()=>{n&&(x(),K())}))},renderDOM(X,$){o||L(X),n&&(H(),F())},destroy(){for(const X of t)X();t=[],ve(),d=new Map,g=[],p=null,n=!1}}}const Ao=300,Lo="nimbus-gantt-config-panel",Fn="nimbus-gantt-config-panel-styles",Ro=300,Un=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],$l=`
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
    transition: opacity ${Ro}ms ease;
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
    transition: right ${Ro}ms ease;
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
`;function _l(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(Lo);return e?JSON.parse(e):{}}catch{return{}}}function Nl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(Lo,JSON.stringify(e))}catch{}}function Po(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function tn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ol(){if(typeof document>"u"||document.getElementById(Fn))return;const e=document.createElement("style");e.id=Fn,e.textContent=$l,document.head.appendChild(e)}function Hl(){if(typeof document>"u")return;const e=document.getElementById(Fn);e&&e.remove()}function nn(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const d=document.createElement("span");return d.className="ng-config-slider-value",d.textContent=String(s),u.addEventListener("input",()=>{const g=Number(u.value);d.textContent=String(g),i(g)}),a.appendChild(l),a.appendChild(u),a.appendChild(d),a}function At(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function sn(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=$o(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function $o(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function xl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const k=e.getState();e.dispatch({type:"SET_SCROLL",x:k.scrollX,y:k.scrollY})}function d(k){Object.assign(t,k),Nl(t)}function g(k,D,E){k[D]=E}function p(k,D){if(!e)return;const E=e.getState();g(E.config,k,D),d({[k]:D}),u()}function r(k,D){if(!e)return;const E=e.getState();g(E.config.theme,k,D),u()}function c(k){if(!e)return;const D=Un.find(C=>C.name===k);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),d({themePreset:k}),u()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function S(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function v(k,D){var X;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?S():f()}),k.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",S),k.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",k.appendChild(o)),o.innerHTML="";const C=document.createElement("div");C.className="ng-config-panel-header",C.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",S),C.appendChild(M),o.appendChild(C);const A=h("Display Settings");A.appendChild(nn("Row height",24,60,E.rowHeight,2,$=>p("rowHeight",$))),A.appendChild(nn("Bar height",16,40,E.barHeight,2,$=>p("barHeight",$))),A.appendChild(nn("Grid width",0,500,E.gridWidth,10,$=>p("gridWidth",$))),A.appendChild(nn("Font size",10,16,E.theme.fontSize,1,$=>{g(D.config.theme,"fontSize",$),d({fontSize:$}),u()})),A.appendChild(At("Today marker",E.showToday,$=>{g(D.config,"showToday",$),d({showToday:$}),u()})),A.appendChild(At("Weekends",E.showWeekends,$=>{g(D.config,"showWeekends",$),d({showWeekends:$}),u()})),A.appendChild(At("Progress bars",E.showProgress,$=>{g(D.config,"showProgress",$),d({showProgress:$}),u()})),A.appendChild(At("Dependency arrows",a,$=>{a=$,d({showDependencies:$}),u()})),A.appendChild(At("Labels on bars",t.showBarLabels!==!1,$=>{d({showBarLabels:$}),u()})),o.appendChild(A);const R=h("Color Theme"),N=document.createElement("div");N.className="ng-config-row";const _=document.createElement("span");_.className="ng-config-label",_.textContent="Preset";const P=document.createElement("select");P.className="ng-config-select";const x=document.createElement("option");x.value="",x.textContent="Custom",P.appendChild(x);for(const $ of Un){const B=document.createElement("option");B.value=$.name,B.textContent=$.name,t.themePreset===$.name&&(B.selected=!0),P.appendChild(B)}P.addEventListener("change",()=>{P.value&&c(P.value)}),N.appendChild(_),N.appendChild(P),R.appendChild(N),R.appendChild(sn("Bar default",E.theme.barDefaultColor,$=>{r("barDefaultColor",$),d({customColors:{...t.customColors,barDefault:$}})})),R.appendChild(sn("Today line",E.theme.todayLineColor,$=>{r("todayLineColor",$),d({customColors:{...t.customColors,todayLine:$}})})),R.appendChild(sn("Grid lines",E.theme.timelineGridColor,$=>{r("timelineGridColor",$),d({customColors:{...t.customColors,gridLines:$}})})),R.appendChild(sn("Background",E.theme.timelineBg,$=>{r("timelineBg",$),d({customColors:{...t.customColors,background:$}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",R.appendChild(W);const K={...E.colorMap,...t.statusColorMap},q=document.createElement("div");function F(){q.innerHTML="";const $=Object.entries(K);for(const[z,G]of $){const V=document.createElement("div");V.className="ng-config-color-map-entry";const ne=document.createElement("input");ne.className="ng-config-color-map-status",ne.value=z,ne.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=$o(G),oe.addEventListener("input",()=>{K[z]=oe.value,E.colorMap[z]=oe.value,d({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete E.colorMap[z],d({statusColorMap:{...K}}),F(),u()}),V.appendChild(ne),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const B=document.createElement("button");B.className="ng-config-color-map-add",B.textContent="+ Add status color",B.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",E.colorMap[z.trim()]="#3b82f6",d({statusColorMap:{...K}}),F(),u())}),q.appendChild(B)}F(),R.appendChild(q),o.appendChild(R);const I=h("Zoom & Time"),O=document.createElement("div");O.className="ng-config-row";const L=document.createElement("span");L.className="ng-config-label",L.textContent="Zoom";const H=document.createElement("div");H.className="ng-config-zoom-group";const U=["day","week","month","quarter"];for(const $ of U){const B=document.createElement("button");B.className="ng-config-zoom-btn"+(D.zoomLevel===$?" ng-active":""),B.textContent=$.charAt(0).toUpperCase()+$.slice(1),B.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:$}),d({zoomLevel:$}),H.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===B)))}),H.appendChild(B)}O.appendChild(L),O.appendChild(H),I.appendChild(O);const ee=document.createElement("div");ee.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=Po(D.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const $=tn(re.value),B=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:$,end:B}),d({dateRangeStart:re.value})}),ee.appendChild(Z),ee.appendChild(re),I.appendChild(ee);const ge=document.createElement("div");ge.className="ng-config-row";const be=document.createElement("span");be.className="ng-config-label",be.textContent="End date";const Y=document.createElement("input");Y.type="date",Y.className="ng-config-date-input",Y.value=Po(D.dateRange.end),Y.addEventListener("change",()=>{if(!e||!Y.value)return;const $=e.getState().dateRange.start,B=tn(Y.value);e.dispatch({type:"SET_DATE_RANGE",start:$,end:B}),d({dateRangeEnd:Y.value})}),ge.appendChild(be),ge.appendChild(Y),I.appendChild(ge);const te=document.createElement("div");te.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(g(e.getState().config,"fitToView",!0),u())}),te.appendChild(j),I.appendChild(te),o.appendChild(I);const Q=h("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),y("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>y("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&T(e.getState())}),se.appendChild(ce),Q.appendChild(se),o.appendChild(Q);const Te=h("Plugin Toggles"),ve=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const $ of ve){const B=document.createElement("div");B.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=$.label;const G=((X=t.pluginToggles)==null?void 0:X[$.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const ne=document.createElement("div");ne.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",ne.appendChild(oe);let ae=G;ne.addEventListener("click",()=>{ae=!ae,ne.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const me={...t.pluginToggles,[$.key]:ae};d({pluginToggles:me}),y($.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),B.appendChild(le),B.appendChild(ne),Te.appendChild(B)}o.appendChild(Te)}function h(k){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=k,D.appendChild(E),D}function y(k){e&&b.forEach(D=>D(k))}const b=[];function m(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],C=D.map(_=>[_.id,`"${(_.name||"").replace(/"/g,'""')}"`,_.startDate,_.endDate,String(Math.round((_.progress??0)*100))+"%",_.status||"",_.assignee||"",_.priority||"",_.groupName||""]),M=[E.join(","),...C.map(_=>_.join(","))].join(`
`),A=new Blob([M],{type:"text/csv;charset=utf-8;"}),R=URL.createObjectURL(A),N=document.createElement("a");N.href=R,N.download="gantt-tasks.csv",document.body.appendChild(N),N.click(),document.body.removeChild(N),URL.revokeObjectURL(R)}function T(k){const D=Array.from(k.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],C=D.map(R=>[R.name,R.startDate,R.endDate,Math.round((R.progress??0)*100)+"%",R.status||"",R.assignee||""]),A=[E.join("	"),...C.map(R=>R.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(A).catch(()=>{})}function w(k){const D=t;if(D.rowHeight!==void 0&&g(k.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&g(k.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&g(k.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&g(k.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&g(k.config,"showToday",D.showToday),D.showWeekends!==void 0&&g(k.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&g(k.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=Un.find(C=>C.name===D.themePreset);E&&Object.assign(k.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&g(k.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&g(k.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&g(k.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&g(k.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(k.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:tn(D.dateRangeStart),end:tn(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(k){e=k,Ol(),t=_l();const D=k.on("render",()=>{D(),w(k.getState()),u()});l.push(D);const E=k.on("config:open",()=>f()),C=k.on("config:close",()=>S()),M=k.on("config:toggle",()=>{i?S():f()});l.push(E,C,M)},renderDOM(k,D){v(k,D)},destroy(){l.forEach(k=>k()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),Hl(),e=null,i=!1}}}const _o=864e5,Yn="nimbus-gantt-heatmap-styles",ke=28,_e=2,tt=48,Ne=160,Bl=3,No="#1e1e2e",Oo="#166534",Ho="#a16207",xo="#b91c1c",Fl=`
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
`;function Bo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ul(e){return String(e.getUTCDate())}function Yl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Wl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fo(e,t){return Math.round((t.getTime()-e.getTime())/_o)}function Uo(e,t){return new Date(e.getTime()+t*_o)}function mt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Xl(e,t){return e===0?No:e===1?Oo:e===2?Ho:xo}function zl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Gl(){if(typeof document>"u"||document.getElementById(Yn))return;const e=document.createElement("style");e.id=Yn,e.textContent=Fl,document.head.appendChild(e)}function Vl(){if(typeof document>"u")return;const e=document.getElementById(Yn);e&&e.remove()}function Kl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const g of t){const p=g.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Fo(o,i)+1,l=[];for(let g=0;g<a;g++)l.push(Uo(o,g));const u=new Map;let d=0;for(const g of s)for(const p of l){const r=`${g}|${mt(p)}`;u.set(r,{assignee:g,date:p,dateKey:mt(p),tasks:[],count:0})}for(const g of t){const p=g.assignee||"Unassigned",r=Bo(g.startDate),c=Bo(g.endDate),f=Fo(r,c)+1;for(let S=0;S<f;S++){const v=Uo(r,S),h=`${p}|${mt(v)}`,y=u.get(h);y&&(y.tasks.push(g),y.count++,y.count>d&&(d=y.count))}}return{assignees:s,dates:l,cells:u,maxCount:d}}function jl(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&d(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&d(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function d(p){if(!t||!s)return;const r=Kl(p);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const f=document.createElement("canvas"),S=Ne+r.dates.length*(ke+_e),v=tt+r.assignees.length*(ke+_e),h=window.devicePixelRatio||1;f.width=S*h,f.height=v*h,f.style.width=S+"px",f.style.height=v+"px",f.style.cursor="pointer";const y=f.getContext("2d");y.scale(h,h),y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle";let b="",m=Ne;for(let T=0;T<r.dates.length;T++){const w=r.dates[T],k=Yl(w),D=Ne+T*(ke+_e);if(k!==b){if(b&&T>0){const E=(m+D)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(b,E,12)}m=D,b=k}}if(b){const T=Ne+r.dates.length*(ke+_e),w=(m+T)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(b,w,12)}y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let T=0;T<r.dates.length;T++){const w=r.dates[T],k=Ne+T*(ke+_e)+ke/2,D=w.getUTCDay()===0||w.getUTCDay()===6;y.fillStyle=D?"#475569":"#64748b",y.fillText(Ul(w),k,32)}y.beginPath(),y.strokeStyle="#1e293b",y.lineWidth=1,y.moveTo(0,tt-.5),y.lineTo(S,tt-.5),y.stroke();for(let T=0;T<r.assignees.length;T++){const w=r.assignees[T],k=tt+T*(ke+_e);y.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="left",y.textBaseline="middle",y.fillStyle="#cbd5e1",y.save(),y.beginPath(),y.rect(0,k,Ne-8,ke),y.clip(),y.fillText(w,8,k+ke/2),y.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],C=`${w}|${mt(E)}`,M=r.cells.get(C),A=(M==null?void 0:M.count)??0,R=Ne+D*(ke+_e),N=Xl(A),_=zl(A,r.maxCount);y.globalAlpha=_,y.fillStyle=N,g(y,R,k,ke,ke,Bl),y.fill(),A>=2&&(y.globalAlpha=1,y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle",y.fillStyle="#fff",y.fillText(String(A),R+ke/2,k+ke/2)),y.globalAlpha=1}}c.appendChild(f),f.addEventListener("mousemove",T=>{if(!n)return;const w=f.getBoundingClientRect(),k=T.clientX-w.left,D=T.clientY-w.top,E=Math.floor((k-Ne)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Ne||D<tt){n.classList.remove("ng-visible");return}const M=r.dates[E],A=r.assignees[C],R=`${A}|${mt(M)}`,N=r.cells.get(R);if(!N||N.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const _=document.createElement("div");_.className="ng-heatmap-tooltip-date",_.textContent=`${A} - ${Wl(M)}`,n.appendChild(_);for(const W of N.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const P=T.clientX+12,x=T.clientY+12;n.style.left=P+"px",n.style.top=x+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",T=>{if(!e)return;const w=f.getBoundingClientRect(),k=T.clientX-w.left,D=T.clientY-w.top,E=Math.floor((k-Ne)/(ke+_e)),C=Math.floor((D-tt)/(ke+_e));if(E<0||E>=r.dates.length||C<0||C>=r.assignees.length||k<Ne||D<tt)return;const M=r.dates[E],R=`${r.assignees[C]}|${mt(M)}`,N=r.cells.get(R);if(!(!N||N.count===0)){u();for(const _ of N.tasks)e.dispatch({type:"SELECT_TASK",taskId:_.id,multi:!0})}})}function g(p,r,c,f,S,v){p.beginPath(),p.moveTo(r+v,c),p.lineTo(r+f-v,c),p.quadraticCurveTo(r+f,c,r+f,c+v),p.lineTo(r+f,c+S-v),p.quadraticCurveTo(r+f,c+S,r+f-v,c+S),p.lineTo(r+v,c+S),p.quadraticCurveTo(r,c+S,r,c+S-v),p.lineTo(r,c+v),p.quadraticCurveTo(r,c,r+v,c),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,Gl();const r=p.on("heatmap:toggle",()=>a()),c=p.on("heatmap:show",()=>l()),f=p.on("heatmap:hide",()=>u());i.push(r,c,f)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",c.appendChild(f);const S=document.createElement("div");S.className="ng-heatmap-legend";const v=[{color:No,label:"None"},{color:Oo,label:"1 task"},{color:Ho,label:"2 tasks"},{color:xo,label:"3+ tasks"}];for(const y of v){const b=document.createElement("span");b.className="ng-heatmap-legend-swatch",b.style.background=y.color,S.appendChild(b);const m=document.createElement("span");m.textContent=y.label,S.appendChild(m)}c.appendChild(S);const h=document.createElement("button");h.className="ng-heatmap-close",h.textContent="Back to Gantt",h.addEventListener("click",u),c.appendChild(h),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&d(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Vl(),e=null,s=!1,o=null}}}const nt=200,st=80,Yo=12,Wo=6,ql="rgba(255, 255, 255, 0.95)",Zl="#cbd5e1",Jl="rgba(59, 130, 246, 0.3)",Ql="rgba(59, 130, 246, 0.7)",ec=1.5,tc=2,nc=1,Wn="nimbus-gantt-minimap-styles",sc=864e5,oc=`
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
`;function ic(){if(typeof document>"u"||document.getElementById(Wn))return;const e=document.createElement("style");e.id=Wn,e.textContent=oc,document.head.appendChild(e)}function ac(){if(typeof document>"u")return;const e=document.getElementById(Wn);e&&e.remove()}function rc(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,d=0,g=0,p=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function S(){o=!1,t&&t.classList.add("ng-hidden")}function v(T,w){const k=T/l-p/2,D=w/u-r/2;return{x:Math.max(0,Math.min(k,d-p)),y:Math.max(0,Math.min(D,g-r))}}function h(T){if(!e||!n)return;T.preventDefault(),i=!0;const w=n.getBoundingClientRect(),k=T.clientX-w.left,D=T.clientY-w.top,E=v(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function y(T){if(!i||!e||!n)return;T.preventDefault();const w=n.getBoundingClientRect(),k=Math.max(0,Math.min(T.clientX-w.left,nt)),D=Math.max(0,Math.min(T.clientY-w.top,st)),E=v(k,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function b(){i=!1}function m(T,w){if(!s||!n||!o)return;const k=window.devicePixelRatio||1;n.width=nt*k,n.height=st*k,n.style.width=nt+"px",n.style.height=st+"px",s.scale(k,k);const{config:D,scrollX:E,scrollY:C,dateRange:M}=T,A=e.getTimeScale(),R=Math.round((M.end.getTime()-M.start.getTime())/sc),N=A.getColumnWidth();if(d=Math.max(R*N,1),g=Math.max(T.flatVisibleIds.length*D.rowHeight,1),p=d>0?Math.min(d,1200):1200,r=g>0?Math.min(g,600):600,t&&t.parentElement){const L=t.parentElement;p=L.clientWidth-D.gridWidth,r=L.clientHeight-D.headerHeight}l=nt/Math.max(d,1),u=st/Math.max(g,1),s.fillStyle=ql,s.fillRect(0,0,nt,st);const _=new Map;for(const L of w)_.has(L.rowIndex)||_.set(L.rowIndex,[]),_.get(L.rowIndex).push(L);for(const L of w){const H=L.x*l,U=Math.max(L.width*l,1),ee=L.rowIndex*D.rowHeight*u;s.fillStyle=L.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(H,ee,U,Math.max(tc,D.rowHeight*u-nc))}s.globalAlpha=1;const P=E*l,x=C*u,W=p*l,K=r*u,q=Math.max(0,Math.min(P,nt-1)),F=Math.max(0,Math.min(x,st-1)),I=Math.min(W,nt-q),O=Math.min(K,st-F);s.fillStyle=Jl,s.fillRect(q,F,I,O),s.strokeStyle=Ql,s.lineWidth=ec,s.strokeRect(q,F,I,O)}return{name:"MiniMapPlugin",install(T){e=T,ic();const w=T.on("minimap:toggle",()=>c()),k=T.on("minimap:show",()=>f()),D=T.on("minimap:hide",()=>S());a.push(w,k,D),typeof document<"u"&&(document.addEventListener("mousemove",y),document.addEventListener("mouseup",b))},renderDOM(T,w){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",h),t.appendChild(n),T.appendChild(t));const k=(e==null?void 0:e.getLayouts())??[];m(w,k)},destroy(){a.forEach(T=>T()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",y),document.removeEventListener("mouseup",b)),t&&(t.remove(),t=null),n=null,s=null,ac(),e=null,o=!0,i=!1}}}const lc="#f59e0b",cc=[6,4],dc=1,lt=16,uc=4,gc="rgba(15, 23, 42, 0.95)",hc="#e2e8f0",fc="#334155",pc=6,ct=10,Xo=220,zo=12,Go=13;function mc(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Lt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function yc(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Lt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function bc(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const d=u%2===0?i:a,g=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(g)*d,r=n+Math.sin(g)*d;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke()}function Tc(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function vc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function Sc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Lt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Vo={flag:yc,star:bc,warning:Tc,info:vc,deadline:Sc};function wc(e,t,n,s,o){e.save();const i=`${zo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Go}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let d=0;if(t.description){const v=t.description.split(" ");let h="";for(const y of v){const b=h?h+" "+y:y;e.measureText(b).width>Xo-ct*2&&h?(u.push(h),d=Math.max(d,e.measureText(h).width),h=y):h=b}h&&(u.push(h),d=Math.max(d,e.measureText(h).width))}const g=Math.min(Xo,Math.max(l,d)+ct*2),p=zo+4,r=Go+4,c=ct*2+r+(u.length>0?4+u.length*p:0);let f=n-g/2;const S=s-c-8;if(f<4&&(f=4),f+g>o-4&&(f=o-g-4),e.beginPath(),kc(e,f,S,g,c,pc),e.fillStyle=gc,e.fill(),e.strokeStyle=fc,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=hc,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+ct,S+ct),u.length>0){e.font=i,e.fillStyle="#94a3b8";let v=S+ct+r+4;for(const h of u)e.fillText(h,f+ct,v),v+=p}e.restore()}function kc(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Dc(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,d=null;function g(h){return n.find(y=>y.id===h)}function p(h){n.push(h),S()}function r(h){n=n.filter(y=>y.id!==h),S()}function c(h,y){const b=g(h);b&&(Object.assign(b,y),S())}function f(){return[...n]}function S(){if(!t)return;const h=t.getState();t.dispatch({type:"SET_SCROLL",x:h.scrollX,y:h.scrollY})}function v(h){const y=h.canvas;d!==y&&(d&&u&&d.removeEventListener("mousemove",u),d=y,u=b=>{const m=y.getBoundingClientRect();a=b.clientX-m.left,l=b.clientY-m.top;let T=null;for(const w of o){const k=a-w.x,D=l-w.y;if(Math.sqrt(k*k+D*D)<=w.size){T=w.note.id;break}}T!==s&&(s=T,y.style.cursor=s?"pointer":"",S())},y.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(h){t=h;const y=h.on("notes:add",(...w)=>{const k=w[0];k&&k.id&&k.date&&k.label&&p(k)}),b=h.on("notes:remove",(...w)=>{const k=w[0];k&&r(k)}),m=h.on("notes:update",(...w)=>{const k=w[0];if(k&&k.id){const{id:D,...E}=k;c(D,E)}}),T=h.on("notes:list",(...w)=>{const k=w[0];typeof k=="function"&&k(f())});i.push(y,b,m,T)},renderCanvas(h,y,b){if(!t||n.length===0)return;const{config:m,scrollX:T,scrollY:w,dateRange:k}=y,{theme:D}=m,E=m.headerHeight,C=t.getTimeScale();v(h);const M=h.canvas.width/(window.devicePixelRatio||1),A=h.canvas.height/(window.devicePixelRatio||1),R=E,N=A-R;o=[],h.save();for(const _ of n){const P=mc(_.date);if(P<k.start||P>k.end)continue;const x=_.color||lc,W=_.icon||"flag",K=C.dateToX(P)-T;if(K<-lt||K>M+lt)continue;h.save(),h.beginPath(),h.setLineDash(cc),h.strokeStyle=x,h.globalAlpha=.5,h.lineWidth=dc,h.moveTo(K,R),h.lineTo(K,R+N),h.stroke(),h.setLineDash([]),h.globalAlpha=1,h.restore();const q=K,F=R+uc+lt/2,I=Vo[W]||Vo.flag;h.save(),h.beginPath(),h.arc(q,F,lt/2+3,0,Math.PI*2),h.fillStyle="rgba(0, 0, 0, 0.4)",h.fill(),h.restore(),h.save(),I(h,q,F,lt,x),h.restore(),o.push({note:_,x:q,y:F,size:lt/2+4}),s===_.id&&wc(h,_,q,F-lt/2-4,M)}h.restore()},destroy(){i.forEach(h=>h()),i.length=0,d&&u&&d.removeEventListener("mousemove",u),t=null,d=null,u=null,s=null,o=[]}}}const Ec=500,Cc=40,Ko=7,jo=3,qo=5,Ic=500,Xn="nimbus-gantt-timetravel-styles",Zo={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Mc=`
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
`;function Ac(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function Lc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function Rc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function Pc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function $c(){if(typeof document>"u"||document.getElementById(Xn))return;const e=document.createElement("style");e.id=Xn,e.textContent=Mc,document.head.appendChild(e)}function _c(){if(typeof document>"u")return;const e=document.getElementById(Xn);e&&e.remove()}const Jo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),on=[.5,1,2,4];function Nc(e){const t=(e==null?void 0:e.maxSnapshots)??Ec,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,d=1;const g=[];let p=null,r=null,c=null,f=null,S=null,v=null,h=null,y=!1;function b(F){if(!s||a)return;const I=s.getState(),O=Rc(I,F);i<o.length-1&&(o.length=i+1),o.push(O),o.length>t&&o.shift(),i=o.length-1}function m(F){if(!s||o.length===0)return;const I=Math.max(0,Math.min(F,o.length-1));i=I;const O=o[I];a=!0;const L=O.tasks.map(U=>({id:U.id,name:U.name,startDate:U.startDate,endDate:U.endDate,progress:U.progress,status:U.status})),H=O.dependencies.map(U=>({id:U.id,source:U.source,target:U.target}));s.dispatch({type:"SET_DATA",tasks:L,dependencies:H}),a=!1,R()}function T(){o.length>0&&m(o.length-1),k()}function w(){if(l||o.length<=1)return;l=!0;const F=on[d],I=Ic/F;u=setInterval(()=>{if(i>=o.length-1){k();return}m(i+1)},I),R()}function k(){l=!1,u!==null&&(clearInterval(u),u=null),R()}function D(){l?k():w()}function E(){d=(d+1)%on.length,l&&(k(),w()),R()}function C(){k(),i>0&&m(i-1)}function M(){k(),i<o.length-1&&m(i+1)}function A(){k(),o.length=0,i=-1,a=!1,R()}function R(){if(p){if(f){const F=o.length,I=F>0?i+1:0;f.textContent=`${I} / ${F}`}S&&(S.textContent=l?"⏸":"▶",S.classList.toggle("ng-active",l)),v&&(v.textContent=`${on[d]}x`),N(),_()}}function N(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const F=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${F}%`}function _(){if(!h||!r||(h.innerHTML="",o.length===0))return;const F=200,I=o.length>F?Math.ceil(o.length/F):1;for(let O=0;O<o.length;O+=I){const L=o[O],H=o.length<=1?50:O/(o.length-1)*100,U=Ac(L.action.split(" ")[0]==="Loaded"?"SET_DATA":P(L.action)),ee=Zo[U]||Zo.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${H}%`,Z.style.background=ee;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${L.action}
${Pc(L.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=O;Z.addEventListener("click",be=>{be.stopPropagation(),k(),m(ge)}),h.appendChild(Z)}}function P(F){return F.startsWith("Moved")?"TASK_MOVE":F.startsWith("Resized")?"TASK_RESIZE":F.startsWith("Added task")?"ADD_TASK":F.startsWith("Added dependency")?"ADD_DEPENDENCY":F.startsWith("Removed task")?"REMOVE_TASK":F.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":F.startsWith("Updated")?"UPDATE_TASK":(F.startsWith("Loaded"),"SET_DATA")}function x(F){if(!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),L=Math.round(O*(o.length-1));k(),m(L)}function W(F){F.preventDefault(),F.stopPropagation(),y=!0,c&&c.classList.add("ng-dragging"),k()}function K(F){if(!y||!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),L=Math.round(O*(o.length-1));m(L)}function q(){y&&(y=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(F){s=F,$c(),g.push(F.on("timeTravel:record",()=>{s&&(s.getState(),b("Manual snapshot"))}),F.on("timeTravel:scrub",(...I)=>{const O=I[0];k(),m(O)}),F.on("timeTravel:play",()=>w()),F.on("timeTravel:pause",()=>k()),F.on("timeTravel:present",()=>T()),F.on("timeTravel:clear",()=>A()),F.on("timeTravel:history",(...I)=>{const O=I[0];typeof O=="function"&&O([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(F,I){let O="";n&&Jo.has(F.type)&&s&&!a&&(O=Lc(F,s.getState())),I(F),n&&Jo.has(F.type)&&!a&&O&&b(O)},renderDOM(F,I){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const O=document.createElement("button");O.className="ng-timetravel-btn",O.textContent="◀",O.title="Step backward",O.addEventListener("click",()=>C()),p.appendChild(O),S=document.createElement("button"),S.className="ng-timetravel-btn",S.textContent="▶",S.title="Play / Pause",S.addEventListener("click",()=>D()),p.appendChild(S);const L=document.createElement("button");L.className="ng-timetravel-btn",L.textContent="▶",L.title="Step forward",L.addEventListener("click",()=>M()),p.appendChild(L),v=document.createElement("span"),v.className="ng-timetravel-speed ng-timetravel-btn",v.textContent=`${on[d]}x`,v.title="Click to cycle speed",v.addEventListener("click",()=>E()),p.appendChild(v),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",x);const H=document.createElement("div");H.className="ng-timetravel-rail",r.appendChild(H),h=document.createElement("div"),h.style.position="absolute",h.style.inset="0",r.appendChild(h),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",W),r.appendChild(c),p.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",p.appendChild(f);const U=document.createElement("button");U.className="ng-timetravel-btn ng-present",U.textContent="Present",U.title="Return to latest state",U.addEventListener("click",()=>T()),p.appendChild(U),F.appendChild(p)}R()},destroy(){k();for(const F of g)F();g.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,c=null,f=null,S=null,v=null,h=null,_c(),o.length=0,i=-1,a=!1,l=!1,y=!1,s=null}}}const Qo=864e5,Oc=60,Hc=2,ei=[6,4],zn="nimbus-gantt-montecarlo-styles",ti={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},xc=.08,Bc=`
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
`;function Gn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function an(e,t){return Math.round((t.getTime()-e.getTime())/Qo)}function dt(e,t){return new Date(e.getTime()+t*Qo)}function ni(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function si(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Fc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Uc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Yc(e,t){return e+Math.random()*(t-e)}function Wc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const d=new Float64Array(u),g=new Float64Array(u),p=new Int32Array(l),r=[];for(let S=0;S<u;S++)p[S]===0&&(r.push(S),d[S]=o[S],g[S]=o[S]+s[S]);let c=0;for(;c<r.length;){const S=r[c++],v=g[S],h=i[S];for(let y=0;y<h.length;y++){const b=h[y];v>d[b]&&(d[b]=v,g[b]=v+s[b]),p[b]--,p[b]===0&&r.push(b)}}for(let S=0;S<u;S++)g[S]===0&&s[S]>0&&(d[S]=o[S],g[S]=o[S]+s[S]);let f=0;for(let S=0;S<u;S++)g[S]>f&&(f=g[S]);return f}function Xc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),d=new Float64Array(e),g=new Int32Array(i),p=[],r=[];for(let v=0;v<e;v++)g[v]===0&&(r.push(v),a[v]=n[v],l[v]=n[v]+t[v]);let c=0;for(;c<r.length;){const v=r[c++];p.push(v);const h=l[v];for(const y of s[v])h>a[y]&&(a[y]=h,l[y]=h+t[y]),g[y]--,g[y]===0&&r.push(y)}for(let v=0;v<e;v++)l[v]===0&&t[v]>0&&(a[v]=n[v],l[v]=n[v]+t[v],p.push(v));let f=0;for(let v=0;v<e;v++)l[v]>f&&(f=l[v]);for(let v=0;v<e;v++)s[v].length===0?(d[v]=f,u[v]=f-t[v]):(d[v]=1/0,u[v]=1/0);for(let v=p.length-1;v>=0;v--){const h=p[v];if(d[h]===1/0){let y=1/0;for(const b of s[h])u[b]<y&&(y=u[b]);y===1/0?d[h]=f:d[h]=y,u[h]=d[h]-t[h]}}const S=new Set;for(let v=0;v<e;v++){const h=u[v]-a[v];Math.abs(h)<.5&&S.add(v)}return S}function zc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const H of e.keys())u.set(H,l.length),l.push(H);const d=l.length;if(d===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const g=new Float64Array(d),p=new Float64Array(d);let r=1/0;for(const H of e.values()){const U=Gn(H.startDate).getTime();U<r&&(r=U)}const c=new Date(r);for(let H=0;H<d;H++){const U=e.get(l[H]),ee=Gn(U.startDate),Z=Gn(U.endDate);g[H]=Math.max(an(ee,Z),1),p[H]=an(c,ee)}const f=Array.from({length:d},()=>[]),S=Array.from({length:d},()=>[]),v=new Int32Array(d);for(const H of t.values()){if((H.type||"FS")!=="FS")continue;const ee=u.get(H.source),Z=u.get(H.target);ee===void 0||Z===void 0||(f[ee].push(Z),S[Z].push(ee),v[Z]++)}const h=f.map(H=>new Int32Array(H)),y=S.map(H=>new Int32Array(H)),b=new Float64Array(s),m=new Float64Array(d),T=new Float64Array(d),w=new Float64Array(d),k=new Float64Array(d),D=new Float64Array(d),E=Math.max(1,Math.floor(s/100));for(let H=0;H<s;H++){for(let U=0;U<d;U++){const ee=g[U];let Z;switch(i){case"triangular":{const re=ee*(1-o),ge=ee,be=ee*(1+o*1.5);Z=Fc(re,ge,be);break}case"normal":{Z=Uc(ee,ee*o);break}case"uniform":{Z=Yc(ee*(1-o),ee*(1+o));break}}m[U]=Math.max(.5,Z),T[U]+=m[U],w[U]+=m[U]*m[U],m[U]>g[U]&&k[U]++}if(b[H]=Wc(l,u,g,m,p,h,y,v),H%E===0){const U=Xc(d,m,p,h,y,v);for(const ee of U)D[ee]++}}const C=Array.from(b).sort((H,U)=>H-U),M=C.map(H=>dt(c,H)),A=new Map;for(const H of a){const U=Math.min(Math.floor(H*C.length),C.length-1);A.set(H,dt(c,C[U]))}let R=0;for(let H=0;H<s;H++)R+=C[H];const N=R/s,_=dt(c,N),P=Math.floor(s/2),x=dt(c,C[P]);let W=0;for(let H=0;H<s;H++){const U=C[H]-N;W+=U*U}const K=Math.sqrt(W/s),q=dt(c,C[0]),F=dt(c,C[C.length-1]),I=new Map;for(let H=0;H<d;H++){const U=T[H]/s,ee=w[H]/s-U*U;I.set(l[H],{meanDuration:U,stdDev:Math.sqrt(Math.max(0,ee)),delayProbability:k[H]/s})}const O=Math.floor(s/E),L=new Map;for(let H=0;H<d;H++)D[H]>0&&L.set(l[H],D[H]/O);return{iterations:s,finishDates:M,percentiles:A,meanFinishDate:_,medianFinishDate:x,earliestFinish:q,latestFinish:F,standardDeviation:K,taskRisk:I,criticalPathFrequency:L}}function Gc(){if(typeof document>"u"||document.getElementById(zn))return;const e=document.createElement("style");e.id=zn,e.textContent=Bc,document.head.appendChild(e)}function Vc(){if(typeof document>"u")return;const e=document.getElementById(zn);e&&e.remove()}function Kc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=zc(f.tasks,f.dependencies,c),g()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function d(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function g(){if(!a||!s)return;let r="",c=0;for(const[h,y]of s.criticalPathFrequency)y>c&&(c=y,r=h);let f=r;if(n){const h=n.getState().tasks.get(r);h&&(f=h.name)}let S=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const h of t.confidenceLevels){const y=s.percentiles.get(h);if(!y)continue;const b=Math.round(h*100),m=ti[h]||"#94A3B8";S+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${b}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${si(y)}</span>
        </div>
      `}if(S+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${si(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const h=Math.round(c*100);S+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${h}% of runs)
        </div>
      `}a.innerHTML=S;const v=a.querySelector(".ng-montecarlo-close");v&&v.addEventListener("click",()=>u())}function p(r,c){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:S}=c.config,v=c.scrollX,h=r.canvas.width/(window.devicePixelRatio||1),y=r.canvas.height/(window.devicePixelRatio||1),b=S,m=y-b,T=s.earliestFinish,w=s.latestFinish,k=Math.max(an(T,w),1),D=f.getColumnWidth(),E=Math.max(D,Hc),C=Math.max(Math.ceil(k),1),M=new Uint32Array(C);for(const P of s.finishDates){const x=an(T,P),W=Math.min(Math.max(Math.floor(x),0),C-1);M[W]++}let A=0;for(let P=0;P<C;P++)M[P]>A&&(A=M[P]);if(A===0)return;r.save(),r.beginPath(),r.rect(0,b,h,m),r.clip(),r.translate(-v,0);const R=s.finishDates[Math.floor(s.finishDates.length*.1)],N=s.finishDates[Math.floor(s.finishDates.length*.9)];if(R&&N){const P=f.dateToX(R),x=f.dateToX(N),W=r.createLinearGradient(P,0,x,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=xc*5,r.fillRect(P,b,x-P,m),r.globalAlpha=1}const _=y-8;for(let P=0;P<C;P++){if(M[P]===0)continue;const x=dt(T,P),W=f.dateToX(x),K=M[P]/A*Oc,q=C>1?P/(C-1):.5;let F,I,O;if(q<.5){const L=q*2;F=Math.round(34+200*L),I=Math.round(197+-18*L),O=Math.round(94+-86*L)}else{const L=(q-.5)*2;F=Math.round(234+5*L),I=Math.round(179+-111*L),O=Math.round(8+60*L)}r.fillStyle=`rgba(${F}, ${I}, ${O}, 0.6)`,r.fillRect(W,_-K,Math.max(E-1,1),K)}r.setLineDash(ei),r.lineWidth=1.5;for(const[P,x]of s.percentiles){const W=f.dateToX(x),K=ti[P]||"#94A3B8",q=`P${Math.round(P*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,b),r.lineTo(W,y),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const F=r.measureText(`${q}: ${ni(x)}`).width,I=`${q}: ${ni(x)}`,O=F+8,L=16,H=W-O/2,U=b+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(H+3,U),r.lineTo(H+O-3,U),r.arcTo(H+O,U,H+O,U+3,3),r.lineTo(H+O,U+L-3),r.arcTo(H+O,U+L,H+O-3,U+L,3),r.lineTo(H+3,U+L),r.arcTo(H,U+L,H,U+L-3,3),r.lineTo(H,U+3),r.arcTo(H,U,H+3,U,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(I,W,U+3),r.setLineDash(ei)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Gc(),i.push(r.on("montecarlo:run",(...c)=>{const f=c[0];l(f)}),r.on("montecarlo:result",(...c)=>{const f=c[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...c)=>{const f=c[0];f&&d(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,f){!o||!s||p(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&g()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Vc(),s=null,n=null}}}const rn=864e5,oi=400,Vn="nimbus-gantt-narrative-styles",ii=300;function Ge(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Kn(e,t){return Math.round((t.getTime()-e.getTime())/rn)}function ai(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function ri(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*rn)}function li(e,t){return new Date(e.getTime()+t*rn)}function jc(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const C=Ge(E.startDate).getTime(),M=Ge(E.endDate).getTime();C<s&&(s=C),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=Kn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const d=new Map,g=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(d.has(E.source)||d.set(E.source,[]),d.get(E.source).push(E.target),g.has(E.target)||g.set(E.target,[]),g.get(E.target).push(E.source));const p=Qc(n,t),r=ri(i),c=ri(a),f=[];let S=r;for(;S.getTime()<=c.getTime();)f.push({start:new Date(S),end:li(S,6)}),S=li(S,7);const v=[];for(let E=0;E<f.length;E++){const C=f[E],M=C.start,A=C.end,R=[],N=[],_=[],P=[],x=[],W=[],K=[];for(const L of n){const H=Ge(L.startDate),U=Ge(L.endDate);H>=M&&H<=A&&(R.push(L),L.isMilestone?(W.push(L),K.push(`Milestone: ${L.name}`)):K.push(`Started: ${L.name}`)),U>=M&&U<=A&&(L.isCompleted||L.progress!==void 0&&L.progress>=1)&&(N.push(L),K.push(`Completed: ${L.name}`)),H<=A&&U>=M&&(x.push(L),H<M&&!L.isCompleted&&(L.progress===void 0||L.progress===0)&&_.push(L),!L.isCompleted&&L.progress!==void 0&&L.progress>0&&L.progress<1&&P.push(L))}for(const L of n)if(L.isMilestone){const H=Ge(L.startDate);H>=M&&H<=A&&!W.includes(L)&&(W.push(L),K.push(`Milestone: ${L.name}`))}const q=x.filter(L=>p.has(L.id)),F=qc(R,N,_,x,q),I=Zc(R,N,_,P,x,q,W,d,e),O=`Week ${E+1} (${ai(M)}–${ai(A)})`;v.push({weekLabel:O,headline:F,body:I,metrics:{started:R.length,completed:N.length,delayed:_.length,onTrack:P.length},events:K})}const h=n.length,y=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,b=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,m=h-y-b,T=h>0?Math.round(y/h*100):0,w=T>=75?"strong":T>=50?"moderate":T>=25?"early-stage":"just getting started",k=`This project spans ${l} days across ${f.length} weeks with ${h} tasks. Progress is ${w} at ${T}% completion (${y} done, ${b} in progress, ${m} not started).`,D=Jc(n,p,d,g,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:k,chapters:v,insights:D}}function qc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Zc(e,t,n,s,o,i,a,l,u){const d=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");d.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");d.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");d.push(`${r} ${t.length===1?"was":"were"} completed.`)}else d.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&d.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");d.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(f=>f.name).join(", ");d.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else d.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const f=l.get(c.id);if(f)for(const S of f){const v=u.get(S);v&&!r.includes(v.name)&&r.push(v.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");d.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&d.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");d.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const g=new Map;for(const r of o)r.assignee&&g.set(r.assignee,(g.get(r.assignee)||0)+1);const p=Array.from(g.entries()).sort((r,c)=>c[1]-r[1]);return p.length>0&&p[0][1]>=3&&d.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),d.length===0&&d.push("No significant activity scheduled for this week."),d.join(" ")}function Jc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const v=e.filter(b=>t.has(b.id)),h=v.slice(0,4).map(b=>b.name).join(", "),y=v.length>4?` and ${v.length-4} more`:"";l.push(`The critical path runs through ${h}${y} — any delay here pushes the project finish.`)}const u=new Map;for(const v of e)v.assignee&&!v.isCompleted&&u.set(v.assignee,(u.get(v.assignee)||0)+1);const d=Array.from(u.entries()).sort((v,h)=>h[1]-v[1]);d.length>0&&d[0][1]>=2&&l.push(`${d[0][0]} is carrying the heaviest load with ${d[0][1]} concurrent tasks.`);const g=e.filter(v=>v.isCompleted?!1:Ge(v.startDate)<a&&(v.progress===void 0||v.progress===0));g.length>0&&l.push(`${g.length} task${g.length>1?"s have":" has"} zero progress despite being past ${g.length>1?"their":"its"} start date${g.length>1?"s":""}.`);const p=Kn(o,i),r=Kn(o,a);if(r>0&&p>0){const v=Math.round(r/p*100),h=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,y=Math.round(h/e.length*100),b=y-v;Math.abs(b)>=5?b>0?l.push(`Project is running ahead: ${y}% of tasks completed with ${v}% of time elapsed.`):l.push(`Project is running behind: only ${y}% of tasks completed with ${v}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${y}% complete at ${v}% of elapsed time.`)}const c=e.filter(v=>{if(v.isCompleted||v.progress!==void 0&&v.progress>0)return!1;const h=s.get(v.id);return!h||h.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,S="";for(const v of e){const h=n.get(v.id);h&&h.length>f&&(f=h.length,S=v.name)}return f>=3&&l.push(`"${S}" is a bottleneck with ${f} downstream tasks depending on it.`),l}function Qc(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const f=Ge(c.endDate).getTime();i.set(c.id,f)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),f=i.get(c);for(const S of s.get(c)){const v=n.get(S.target),h=Ge(v.endDate).getTime()-Ge(v.startDate).getTime(),y=f+S.lag*rn+h;y>i.get(S.target)&&i.set(S.target,y);const b=l.get(S.target)-1;l.set(S.target,b),b===0&&a.push(S.target)}}let u=-1/0,d="";for(const[c,f]of i)f>u&&(u=f,d=c);if(!d)return new Set;const g=new Set,p=new Map;for(const c of e)p.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||p.get(c.target).push({source:c.source,lag:c.lag||0}));let r=d;for(;r;){g.add(r);const c=p.get(r);if(!c||c.length===0)break;let f="",S=-1/0;for(const v of c){const h=i.get(v.source)||0;h>S&&(S=h,f=v.source)}if(!f||g.has(f))break;r=f}return g}const ed=`
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
`;function td(){if(typeof document>"u"||document.getElementById(Vn))return;const e=document.createElement("style");e.id=Vn,e.textContent=ed,document.head.appendChild(e)}function nd(){if(typeof document>"u")return;const e=document.getElementById(Vn);e&&e.remove()}function sd(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function od(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=jc(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),g()}function d(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function g(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",c.appendChild(f);const S=document.createElement("span");S.textContent="Project Story",c.appendChild(S),r.appendChild(c);const v=document.createElement("div");v.style.display="flex",v.style.alignItems="center",v.style.gap="4px";const h=document.createElement("button");h.className="ng-narrative-refresh",h.innerHTML="↻",h.title="Regenerate",h.addEventListener("click",()=>{l(),g()}),v.appendChild(h);const y=document.createElement("button");y.className="ng-narrative-close",y.innerHTML="×",y.addEventListener("click",d),v.appendChild(y),r.appendChild(v),a.appendChild(r);const b=document.createElement("div");if(b.className="ng-narrative-summary",b.textContent=t.summary,a.appendChild(b),t.chapters.length===0){const w=document.createElement("div");w.className="ng-narrative-empty",w.textContent="No weekly chapters to display.",a.appendChild(w)}else for(const w of t.chapters){const k=document.createElement("div");k.className="ng-narrative-chapter";const D=sd(w),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const C=document.createElement("div");C.className="ng-narrative-week-label",C.textContent=w.weekLabel,E.appendChild(C);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=w.headline,E.appendChild(M),k.appendChild(E);const A=document.createElement("div");if(A.className="ng-narrative-metrics",w.metrics.started>0&&A.appendChild(p("started",`${w.metrics.started} started`)),w.metrics.completed>0&&A.appendChild(p("completed",`${w.metrics.completed} done`)),w.metrics.delayed>0&&A.appendChild(p("delayed",`${w.metrics.delayed} delayed`)),w.metrics.onTrack>0&&A.appendChild(p("ontrack",`${w.metrics.onTrack} on track`)),A.children.length>0&&k.appendChild(A),w.body){const R=document.createElement("div");R.className="ng-narrative-body",R.textContent=w.body,k.appendChild(R)}a.appendChild(k)}if(t.insights.length>0){const w=document.createElement("div");w.className="ng-narrative-insights";const k=document.createElement("div");k.className="ng-narrative-insights-title",k.innerHTML="<span>💡</span> Key Insights",w.appendChild(k);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const C=document.createElement("span");C.className="ng-narrative-insight-icon",C.textContent="•",E.appendChild(C);const M=document.createElement("span");M.textContent=D,E.appendChild(M),w.appendChild(E)}a.appendChild(w)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const T=new Date(t.generatedAt);m.textContent=`Generated ${T.toLocaleString()}`,a.appendChild(m)}function p(r,c){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=c,f}return{name:"NarrativePlugin",install(r){e=r,td(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&g()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>d()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?d():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",d),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),g())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),nd(),e=null,t=null,n=!1}}}const id=864e5,ad=10,jn="nimbus-gantt-whatif-styles",ci=.25,rd=.6,ln=6,di="#38A169",ui="#E53E3E",gi="#A0AEC0",qn=36,ld="#F6AD55",hi="#1a202c",cd=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${qn}px;
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
    top: ${qn}px;
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
    top: ${qn+8}px;
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
`;function Ve(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function fi(e){const t=Ve(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function cn(e,t){return Math.round((t.getTime()-e.getTime())/id)}function pi(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function dd(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function ud(e){return{...e}}function gd(){if(typeof document>"u"||document.getElementById(jn))return;const e=document.createElement("style");e.id=jn,e.textContent=cd,document.head.appendChild(e)}function hd(){if(typeof document>"u")return;const e=document.getElementById(jn);e&&e.remove()}function fd(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,dd(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,ud(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function mi(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function pd(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,d=null,g=null,p=null,r=null,c=null,f=null;function S(){t||!e||(o=fd(e.getState()),i=[],t=!0,n=!1,D())}function v(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),M(),R())}function h(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),M())}function y(I){if(!t||!e||!o)return;a.length>=ad&&a.shift();const O=e.getState(),L=mi(O.tasks),H=Ve(o.projectFinish),U=Ve(L),ee=cn(H,U);let Z=0;for(const[ge,be]of o.tasks){const Y=O.tasks.get(ge);if(!Y){Z++;continue}(Y.startDate!==be.startDate||Y.endDate!==be.endDate||Y.assignee!==be.assignee)&&Z++}for(const ge of O.tasks.keys())o.tasks.has(ge)||Z++;const re={id:pi(),name:I,createdAt:Date.now(),changes:[...i],result:{projectFinish:L,criticalPathDelta:ee,tasksAffected:Z}};a.push(re),x()}function b(I){if(!e||!o)return;const O=a.find(L=>L.id===I);if(O){t||S(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const L of O.changes)T(L);i=[...O.changes],E()}}function m(I){a=a.filter(O=>O.id!==I),x()}function T(I){if(e)switch(I.type){case"move":case"resize":I.taskId&&I.after&&I.after.startDate&&I.after.endDate&&e.dispatch({type:I.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:I.taskId,startDate:I.after.startDate,endDate:I.after.endDate});break;case"add":I.after&&e.dispatch({type:"ADD_TASK",task:I.after});break;case"remove":I.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:I.taskId});break;case"reassign":I.taskId&&I.after&&e.dispatch({type:"UPDATE_TASK",taskId:I.taskId,changes:I.after});break;case"add-dependency":I.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:I.dependencyId||pi(),source:I.dependency.source,target:I.dependency.target,type:I.dependency.type||"FS"}});break;case"remove-dependency":I.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:I.dependencyId});break}}function w(){t&&(n=!n,n?C():M())}function k(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const I=e.getState(),O=mi(I.tasks),L=Ve(o.projectFinish),H=Ve(O),U=cn(L,H);let ee=0;for(const[Z,re]of o.tasks){const ge=I.tasks.get(Z);if(!ge){ee++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&ee++}for(const Z of I.tasks.keys())o.tasks.has(Z)||ee++;return{baselineFinish:o.projectFinish,sandboxFinish:O,deltaDays:U,tasksAffected:ee}}function D(){u&&u.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function C(){if(!g)return;const I=k();let O="ng-whatif-summary-value--unchanged",L="No change";I.deltaDays<0?(O="ng-whatif-summary-value--improved",L=`${Math.abs(I.deltaDays)} day${Math.abs(I.deltaDays)!==1?"s":""} earlier`):I.deltaDays>0&&(O="ng-whatif-summary-value--worsened",L=`${I.deltaDays} day${I.deltaDays!==1?"s":""} later`),g.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${fi(I.baselineFinish)} &rarr; ${fi(I.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${O}">${L}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${I.tasksAffected}</span>
      </div>
    `,g.classList.remove("ng-hidden")}function M(){g&&g.classList.add("ng-hidden")}function A(){s=!s,d&&d.classList.toggle("ng-open",s),s&&x()}function R(){s=!1,d&&d.classList.remove("ng-open")}function N(){r&&(r.classList.add("ng-active"),c==null||c.focus())}function _(){r&&r.classList.remove("ng-active"),c&&(c.value="")}function P(){if(!c)return;const I=c.value.trim();I&&(y(I),_())}function x(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(I=>{var U;const O=new Date(I.createdAt).toLocaleDateString(),L=((U=I.result)==null?void 0:U.criticalPathDelta)??0;let H="No impact";return L<0?H=`${Math.abs(L)}d earlier`:L>0&&(H=`${L}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${I.id}">
            <div class="ng-whatif-scenario-name">${W(I.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${O}</span>
              <span>${I.changes.length} changes</span>
              <span>${H}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${I.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${I.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${I.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(I){const O=document.createElement("div");return O.textContent=I,O.innerHTML}function K(I){const O=I.target,L=O.getAttribute("data-action"),H=O.getAttribute("data-id");if(!(!L||!H))switch(L){case"load":b(H),R();break;case"compare":b(H),n=!0,C(),R();break;case"delete":m(H);break}}function q(I,O){switch(I.type){case"TASK_MOVE":{const L=O.tasks.get(I.taskId);L&&i.push({type:"move",taskId:I.taskId,before:{startDate:L.startDate,endDate:L.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"TASK_RESIZE":{const L=O.tasks.get(I.taskId);L&&i.push({type:"resize",taskId:I.taskId,before:{startDate:L.startDate,endDate:L.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:I.task.id,after:{...I.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:I.taskId,before:O.tasks.get(I.taskId)?{...O.tasks.get(I.taskId)}:void 0});break;case"UPDATE_TASK":{const L=O.tasks.get(I.taskId);L&&i.push({type:"reassign",taskId:I.taskId,before:{...L},after:I.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:I.dependency.id,dependency:{source:I.dependency.source,target:I.dependency.target,type:I.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:I.dependencyId});break}E()}function F(I,O,L,H,U,ee){const Z=Math.min(ee,H/2,U/2);I.beginPath(),I.moveTo(O+Z,L),I.lineTo(O+H-Z,L),I.arcTo(O+H,L,O+H,L+Z,Z),I.lineTo(O+H,L+U-Z),I.arcTo(O+H,L+U,O+H-Z,L+U,Z),I.lineTo(O+Z,L+U),I.arcTo(O,L+U,O,L+U-Z,Z),I.lineTo(O,L+Z),I.arcTo(O,L,O+Z,L,Z),I.closePath()}return{name:"WhatIfPlugin",install(I){e=I,gd(),l.push(I.on("whatif:enter",()=>S())),l.push(I.on("whatif:exit",()=>v())),l.push(I.on("whatif:compare",()=>w())),l.push(I.on("whatif:discard",()=>h())),l.push(I.on("whatif:save",(...O)=>{const L=typeof O[0]=="string"?O[0]:void 0;L?y(L):N()})),l.push(I.on("whatif:load",(...O)=>{const L=typeof O[0]=="string"?O[0]:void 0;L?b(L):A()})),l.push(I.on("whatif:list-scenarios",(...O)=>{const L=typeof O[0]=="function"?O[0]:void 0;L?L([...a]):A()})),l.push(I.on("whatif:delete-scenario",(...O)=>{const L=typeof O[0]=="string"?O[0]:void 0;L&&m(L)}))},middleware(I,O){if(!t){O(I);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(I.type)&&e){const H=e.getState();q(I,H)}O(I)},renderCanvas(I,O,L){if(!t||!e)return;const{theme:H,headerHeight:U,barHeight:ee}=O.config,Z=O.scrollX,re=O.scrollY,ge=U,be=e.getTimeScale(),Y=H.barBorderRadius;if(I.save(),I.beginPath(),I.rect(0,ge,I.canvas.width,I.canvas.height-ge),I.clip(),I.translate(-Z,0),o){const te=new Set;for(const j of L){const Q=o.tasks.get(j.taskId),se=O.tasks.get(j.taskId);(!Q&&se||Q&&se&&(Q.startDate!==se.startDate||Q.endDate!==se.endDate||Q.assignee!==se.assignee))&&te.add(j.taskId)}for(const j of L){if(!te.has(j.taskId))continue;const Q=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>I.canvas.height||(I.save(),I.setLineDash([4,3]),I.strokeStyle="#F6AD55",I.lineWidth=2,F(I,Q,se,de,ie,Y),I.stroke(),I.restore())}}if(n&&o){const te=ee*rd;for(const j of L){if(j.isMilestone)continue;const Q=o.tasks.get(j.taskId);if(!Q)continue;const se=O.tasks.get(j.taskId);if(!se)continue;const de=Ve(Q.startDate),ie=Ve(Q.endDate),fe=Ve(se.startDate),ce=Ve(se.endDate),Te=cn(de,fe),ve=cn(ie,ce);if(Te===0&&ve===0)continue;let X=gi;ve<0?X=di:ve>0&&(X=ui);const $=be.dateToX(de),B=be.dateToX(ie),z=Math.max(B-$,2),G=j.barY-re,V=G+ee+2;I.save(),I.globalAlpha=ci,I.fillStyle=X,F(I,$,V,z,te,Y),I.fill(),I.globalAlpha=ci*2,I.strokeStyle=X,I.lineWidth=1,I.stroke(),I.restore();const ne=$+z/2,oe=V+te/2,ae=j.x+j.width/2,le=G+ee/2;I.save(),I.globalAlpha=.6,I.strokeStyle=X,I.lineWidth=1.5,I.setLineDash([3,2]),I.beginPath(),I.moveTo(ne,oe),I.lineTo(ae,le),I.stroke();const me=Math.atan2(le-oe,ae-ne),Se=ae,Ae=le;I.setLineDash([]),I.beginPath(),I.moveTo(Se,Ae),I.lineTo(Se-ln*Math.cos(me-Math.PI/6),Ae-ln*Math.sin(me-Math.PI/6)),I.lineTo(Se-ln*Math.cos(me+Math.PI/6),Ae-ln*Math.sin(me+Math.PI/6)),I.closePath(),I.fillStyle=X,I.fill(),I.restore()}}I.restore()},renderDOM(I,O){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const L=document.createElement("div");L.className="ng-whatif-banner-left";const H=document.createElement("span");H.className="ng-whatif-badge",H.textContent="What-If Mode",L.appendChild(H);const U=document.createElement("span");U.textContent="Changes are hypothetical",U.style.fontSize="12px",U.style.opacity="0.7",L.appendChild(U);const ee=document.createElement("span");ee.textContent="·",ee.style.opacity="0.4",L.appendChild(ee),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",L.appendChild(p),u.appendChild(L);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",c=document.createElement("input"),c.type="text",c.placeholder="Scenario name...",c.addEventListener("keydown",se=>{se.key==="Enter"&&P(),se.key==="Escape"&&_()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",P);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>_()),r.appendChild(c),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const be=document.createElement("button");be.className="ng-whatif-btn",be.textContent="Scenarios",be.addEventListener("click",()=>A()),Z.appendChild(be);const Y=document.createElement("button");Y.className="ng-whatif-btn ng-whatif-btn--primary",Y.textContent="Compare with Baseline",Y.addEventListener("click",()=>w()),Z.appendChild(Y);const te=document.createElement("button");te.className="ng-whatif-btn",te.textContent="Save Scenario",te.addEventListener("click",()=>N()),Z.appendChild(te);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>h()),Z.appendChild(j);const Q=document.createElement("button");Q.className="ng-whatif-btn ng-whatif-btn--danger",Q.textContent="Exit",Q.addEventListener("click",()=>v()),Z.appendChild(Q),u.appendChild(Z),I.appendChild(u)}if(g||(g=document.createElement("div"),g.className="ng-whatif-summary ng-hidden",I.appendChild(g)),!d){d=document.createElement("div"),d.className="ng-whatif-panel";const L=document.createElement("div");L.className="ng-whatif-panel-title";const H=document.createElement("span");H.textContent="Saved Scenarios",L.appendChild(H);const U=document.createElement("button");U.className="ng-whatif-panel-close",U.textContent="×",U.addEventListener("click",()=>R()),L.appendChild(U),d.appendChild(L),f=document.createElement("div"),f.addEventListener("click",K),d.appendChild(f),I.appendChild(d),x()}D(),n&&C()},destroy(){for(const I of l)I();l.length=0,u&&(u.remove(),u=null),d&&(d.remove(),d=null),g&&(g.remove(),g=null),p=null,r=null,c=null,f=null,hd(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Zn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},md=261.63;function yd(e){return md*Math.pow(2,e/12)}function bd(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return yd(n?a+12:a)}const Jn="nimbus-gantt-sonification-styles",Qn=64,dn=64,yi=.05,Td=.1,vd=.7,bi=.2,es="#F6AD55",Sd=2,wd="rgba(246, 173, 85, 0.35)",Ti=12,kd=`
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
    height: ${Qn}px;
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
`;function ts(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Dd(){if(typeof document>"u"||document.getElementById(Jn))return;const e=document.createElement("style");e.id=Jn,e.textContent=kd,document.head.appendChild(e)}function Ed(){if(typeof document>"u")return;const e=document.getElementById(Jn);e&&e.remove()}function Cd(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,d=null,g=null;const p=new Map;let r="stopped",c=0,f=0,S=0,v=0,h=0,y=0,b=0,m=null,T=null,w=null,k=null,D=null,E=null;const C=[];let M=[],A=[];function R(){if(l)return;const Y=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;Y&&(l=new Y,u=l.createGain(),u.gain.value=i,d=l.createAnalyser(),d.fftSize=256,g=new Uint8Array(d.frequencyBinCount),u.connect(d),d.connect(l.destination))}function N(){l&&l.state==="suspended"&&l.resume()}function _(){if(!a)return;const Y=a.getState(),te=Date.now();let j=1/0,Q=-1/0;const se=[],de=new Set,ie=Y.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of Y.tasks){const ve=ts(Te.startDate).getTime(),X=ts(Te.endDate).getTime();ve<j&&(j=ve),X>Q&&(Q=X);const $=Te.groupId||"__default__";de.add($);const B=fe.get(ce)??0,z=!Te.isCompleted&&X<te&&(Te.progress??0)<1;se.push({id:ce,startMs:ve,endMs:X,rowIndex:B,progress:Te.progress??0,groupId:$,isCritical:!1,isOverdue:z})}M=se,A=Array.from(de),h=j===1/0?0:j,y=Q===-1/0?0:Q,b=Math.max(y-h,1)}function P(Y){if(!l||!u||p.has(Y.id))return;const te=Zn[n]||Zn.major,j=bd(Y.rowIndex,te,Y.isCritical),Q=l.createOscillator();Q.type=s,Q.frequency.value=j,Y.isOverdue&&(Q.detune.value=25);const se=.3+Y.progress*.7,de=Y.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+yi),fe.gain.linearRampToValueAtTime(ie*vd,l.currentTime+yi+Td);const ce=l.createStereoPanner();if(A.length<=1)ce.pan.value=0;else{const Te=A.indexOf(Y.groupId);ce.pan.value=A.length>1?Te/(A.length-1)*2-1:0}Q.connect(fe),fe.connect(ce),ce.connect(u),Q.start(),p.set(Y.id,{taskId:Y.id,oscillator:Q,gainNode:fe,panNode:ce})}function x(Y){const te=p.get(Y);if(!te||!l)return;const j=l.currentTime;te.gainNode.gain.cancelScheduledValues(j),te.gainNode.gain.setValueAtTime(te.gainNode.gain.value,j),te.gainNode.gain.linearRampToValueAtTime(0,j+bi),te.oscillator.stop(j+bi+.05),p.delete(Y)}function W(){for(const Y of Array.from(p.keys()))x(Y)}function K(){if(r!=="playing"||!l)return;const Y=l.currentTime-c;if(f=Math.min(Y/o,1),f>=1){I();return}const te=h+f*b;for(const j of M){const Q=te>=j.startMs&&te<j.endMs,se=p.has(j.id);Q&&!se?P(j):!Q&&se&&x(j.id)}Z(),v=requestAnimationFrame(K)}function q(){R(),N(),l&&(_(),r==="paused"?c=l.currentTime-S*o:(c=l.currentTime,f=0),r="playing",H(),U(),v=requestAnimationFrame(K))}function F(){r==="playing"&&(r="paused",S=f,W(),cancelAnimationFrame(v),H())}function I(){r="stopped",f=0,S=0,W(),cancelAnimationFrame(v),H(),ee()}function O(){r==="playing"?F():q()}function L(Y){const te=ts(Y).getTime(),j=Math.max(0,Math.min((te-h)/b,1));r==="playing"&&l?c=l.currentTime-j*o:(S=j,f=j)}function H(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=re(),D.classList.remove("ng-son-btn--active")))}function U(){T&&T.classList.remove("ng-hidden")}function ee(){T&&T.classList.add("ng-hidden")}function Z(){if(!d||!g||!k||!w)return;d.getByteFrequencyData(g);const Y=w.width,te=w.height;k.clearRect(0,0,Y,te);const j=k.createLinearGradient(0,0,0,te);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),k.fillStyle=j,k.fillRect(0,0,Y,te);const Q=Y/dn*.8,se=Y/dn*.2,de=Math.floor(g.length/dn);for(let ie=0;ie<dn;ie++){let fe=0;for(let z=0;z<de;z++)fe+=g[ie*de+z]??0;const ce=fe/de,Te=ce/255*te*.85,ve=ie*(Q+se),X=te-Te,$=30+ce/255*15,B=55+ce/255*15;k.fillStyle=`hsl(${$}, 90%, ${B}%)`,k.fillRect(ve,X,Q,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function be(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(Y){a=Y,Dd(),C.push(Y.on("sonification:play",()=>q())),C.push(Y.on("sonification:pause",()=>F())),C.push(Y.on("sonification:stop",()=>I())),C.push(Y.on("sonification:scrub",(...te)=>{const j=typeof te[0]=="string"?te[0]:void 0;j&&L(j)})),C.push(Y.on("sonification:configure",(...te)=>{const j=te[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(Y,te,j){if(r==="stopped"||!a)return;const{headerHeight:Q}=te.config,se=te.scrollX,de=te.scrollY,ie=Q,fe=a.getTimeScale(),ce=h+f*b,Te=new Date(ce),ve=fe.dateToX(Te);Y.save(),Y.beginPath(),Y.rect(0,ie,Y.canvas.width,Y.canvas.height-ie),Y.clip(),Y.translate(-se,0),Y.save(),Y.shadowColor=es,Y.shadowBlur=Ti,Y.strokeStyle=es,Y.lineWidth=Sd,Y.beginPath(),Y.moveTo(ve,ie),Y.lineTo(ve,Y.canvas.height+de),Y.stroke(),Y.restore();const X=new Map;for(const $ of j)X.set($.taskId,$);for(const $ of p.values()){const B=X.get($.taskId);if(!B)continue;const z=B.x,G=B.barY-de,V=B.width,ne=B.barHeight;if(G+ne<ie||G>Y.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);Y.save(),Y.globalAlpha=ae,Y.shadowColor=wd,Y.shadowBlur=Ti,Y.fillStyle=es;const le=Math.min(te.config.theme.barBorderRadius,V/2,ne/2);Y.beginPath(),Y.moveTo(z+le,G),Y.lineTo(z+V-le,G),Y.arcTo(z+V,G,z+V,G+le,le),Y.lineTo(z+V,G+ne-le),Y.arcTo(z+V,G+ne,z+V-le,G+ne,le),Y.lineTo(z+le,G+ne),Y.arcTo(z,G+ne,z,G+ne-le,le),Y.lineTo(z,G+le),Y.arcTo(z,G,z+le,G,le),Y.closePath(),Y.fill(),Y.restore()}Y.restore()},renderDOM(Y,te){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=re(),D.title="Play / Pause",D.addEventListener("click",()=>O()),m.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=be(),E.title="Stop",E.addEventListener("click",()=>I()),m.appendChild(E);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const Q=document.createElement("div");Q.style.display="flex",Q.style.flexDirection="column",Q.style.alignItems="center",Q.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",Q.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),Q.appendChild(de),m.appendChild(Q);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const B of Object.keys(Zn)){const z=document.createElement("option");z.value=B,z.textContent=B.charAt(0).toUpperCase()+B.slice(1),B===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const ve=document.createElement("div");ve.style.display="flex",ve.style.flexDirection="column",ve.style.alignItems="center",ve.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",ve.appendChild(X);const $=document.createElement("input");$.type="range",$.className="ng-son-slider",$.min="0",$.max="100",$.value=String(Math.round(i*100)),$.addEventListener("input",()=>{i=Number($.value)/100,u&&(u.gain.value=i)}),ve.appendChild($),m.appendChild(ve),Y.appendChild(m)}if(!T){T=document.createElement("div"),T.className="ng-sonification-waveform ng-hidden",w=document.createElement("canvas"),k=w.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,Q=Y.getBoundingClientRect();w.width=Q.width*j,w.height=Qn*j,w.style.width="100%",w.style.height=Qn+"px",k&&k.scale(j,j),T.appendChild(w),Y.appendChild(T)}},destroy(){for(const Y of C)Y();C.length=0,I(),W(),l&&(l.close(),l=null),u=null,d=null,g=null,m&&(m.remove(),m=null),T&&(T.remove(),T=null),w=null,k=null,D=null,E=null,Ed(),a=null,M=[],A=[]}}}const Id=.55,Md=[4,3],Ad=1,Ld=4,Rd=600;function Pd(e={}){let t=null;const n=vi(e.futureFadeStrength??Id,0,1),s=e.futureDashedBorder!==!1,o=e.futureDashPattern??Md,i=e.futureDashWidth??Ad,a=e.pastShowCheckmark!==!1,l=e.todayProvider??(()=>new Date);return{name:"TemporalAsymmetryPlugin",install(u){t=u},renderCanvas(u,d,g){if(!t||g.length===0)return;const{config:p,scrollX:r,scrollY:c,tasks:f}=d,{theme:S}=p,v=p.headerHeight,h=S.barBorderRadius,y=l();let b;try{b=t.getTimeScale().dateToX(y)}catch{return}const m=e.futureFadeColor??S.timelineBg??"#ffffff",T=typeof window<"u"&&window.devicePixelRatio||1,w=u.canvas.width/T,k=u.canvas.height/T;u.save();const D=v,E=k-D;u.beginPath(),u.rect(0,D,w,E),u.clip(),u.translate(-r,0);for(const C of g){if(C.isMilestone)continue;const M=f.get(C.taskId);if(!M||M.status==="group-header")continue;const A=C.x,R=C.barY-c,N=C.width,_=C.barHeight;if(R+_<0||R>E)continue;const P=A+N,x=A>=b,W=P<=b,K=!x&&!W;if(x||K){const q=x?A:b,F=x?N:P-b;F>.5&&(u.save(),u.beginPath(),Si(u,A,R,N,_,h),u.clip(),u.globalAlpha=n,u.fillStyle=m,u.fillRect(q,R,F,_),u.restore())}if(s&&(x||K)){const q=e.futureDashColor??_d(C.color,.4);if(u.save(),u.lineWidth=i,u.strokeStyle=q,u.setLineDash(o),x)$d(u,A,R,N,_,h);else{const F=R+.5,I=R+_-.5;u.beginPath(),u.moveTo(b,F),u.lineTo(P-h,F),u.moveTo(b,I),u.lineTo(P-h,I),u.moveTo(b,R),u.lineTo(b,R+_),u.stroke()}u.setLineDash([]),u.restore()}if(a&&W&&(M.progress??0)>=1){const q=A+Ld+5,F=R+_/2,I=e.pastCheckmarkColor??Nd(C.color);u.save(),u.font=`${Rd} ${Math.max(10,S.fontSize-1)}px ${S.fontFamily}`,u.textBaseline="middle",u.textAlign="left",u.fillStyle=I,u.fillText("✓",q-5,F),u.restore()}}u.restore()},destroy(){t=null}}}function vi(e,t,n){return Math.max(t,Math.min(n,e))}function Si(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.quadraticCurveTo(t+s,n,t+s,n+a),e.lineTo(t+s,n+o-a),e.quadraticCurveTo(t+s,n+o,t+s-a,n+o),e.lineTo(t+a,n+o),e.quadraticCurveTo(t,n+o,t,n+o-a),e.lineTo(t,n+a),e.quadraticCurveTo(t,n,t+a,n)}function $d(e,t,n,s,o,i){e.beginPath(),Si(e,t,n,s,o,i),e.stroke()}function _d(e,t){const n=wi(e);if(!n)return e;const s=Math.round((n.r+n.g+n.b)/3),o=i=>Math.round(i*(1-t)+s*t);return Od(o(n.r),o(n.g),o(n.b))}function Nd(e){const t=wi(e);return t?.299*t.r+.587*t.g+.114*t.b>140?"#1f2937":"#ffffff":"#1f2937"}function wi(e){const t=e.replace("#","");return t.length===3?{r:parseInt(t[0]+t[0],16),g:parseInt(t[1]+t[1],16),b:parseInt(t[2]+t[2],16)}:t.length===6?{r:parseInt(t.substring(0,2),16),g:parseInt(t.substring(2,4),16),b:parseInt(t.substring(4,6),16)}:null}function Od(e,t,n){const s=o=>vi(o,0,255).toString(16).padStart(2,"0");return`#${s(e)}${s(t)}${s(n)}`}const Hd=5e3,xd=3e4,Bd=500,Fd=new Set(["SET_DATA","UPDATE_TASK","ADD_TASK","REMOVE_TASK","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function ot(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}})}function Ud(e={}){const t=Math.max(100,e.capacity??Hd),n=e.compactAfterIdleMs??xd,s=Math.min(t,Math.max(50,e.compactKeep??Bd)),o=[],i=[];let a=null,l=null,u=null,d=null;function g(){d&&clearTimeout(d),d=setTimeout(p,n)}function p(){if(o.length<=s)return;const y=o.length-s;o.splice(0,y),ot("history:compaction",{dropped:y,kept:o.length})}function r(y){var b;if(o.push(y),ot("history:entry-recorded",{actionType:y.action.type,ts:y.wallTs,source:y.source}),o.length>t){const m=o.splice(0,1);ot("history:overflow-drop",{ts:(b=m[0])==null?void 0:b.wallTs})}if(g(),e.onEntry)try{const m=e.onEntry(y);m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}e.hydrate&&o.push(...e.hydrate),e.hydrateAnnotations&&i.push(...e.hydrateAnnotations);function c(y,b){switch(b.type){case"SET_DATA":{const m=Array.from(y.tasks.values()),T=Array.from(y.dependencies.values());return{type:"SET_DATA",tasks:m,dependencies:T}}case"UPDATE_TASK":{const m=y.tasks.get(b.taskId);if(!m)return null;const T={};for(const w of Object.keys(b.changes))T[w]=m[w];return{type:"UPDATE_TASK",taskId:b.taskId,changes:T}}case"ADD_TASK":return{type:"REMOVE_TASK",taskId:b.task.id};case"REMOVE_TASK":{const m=y.tasks.get(b.taskId);return m?{type:"ADD_TASK",task:m}:null}case"TASK_MOVE":case"TASK_RESIZE":{const m=y.tasks.get(b.taskId);return m?{type:b.type,taskId:b.taskId,startDate:m.startDate,endDate:m.endDate}:null}case"ADD_DEPENDENCY":return{type:"REMOVE_DEPENDENCY",dependencyId:b.dependency.id};case"REMOVE_DEPENDENCY":{const m=y.dependencies.get(b.dependencyId);return m?{type:"ADD_DEPENDENCY",dependency:m}:null}default:return null}}function f(y,b){if(!Fd.has(y.type)){b(y);return}const m=a?a():null;if(!m){b(y);return}const T=c(m,y);b(y);const w=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),k=Date.now();r({ts:w,wallTs:k,action:y,inverse:T,actor:e.defaultActor,source:e.defaultSource??"local"})}function S(y){if(!a)return null;const b=y.getTime(),m=a();if(o.length===0)return m;const T=o[0].wallTs;if(b<T)return ot("history:snapshot-miss",{target:b,baselineTs:T}),null;const w=new un(m);for(let k=o.length-1;k>=0;k--){const D=o[k];if(D.wallTs<=b)break;D.inverse&&w.dispatch(D.inverse)}return w.getState()}function v(y){const b=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),m=Date.now(),T={ts:b,wallTs:m,...y};if(i.push(T),ot("history:annotation-added",{kind:T.kind,taskId:T.taskId}),e.onAnnotation)try{const w=e.onAnnotation(T);w&&typeof w.catch=="function"&&w.catch(()=>{})}catch{}}const h={entries:()=>o,annotations:()=>i,snapshotAt:S,appendAnnotation:v,lastWallTs:()=>o.length>0?o[o.length-1].wallTs:null,scrubTo:y=>{l==null||l.setTimeCursor(y),ot("history:scrub",{cursorWallTs:y?y.getTime():null})},scrubToNow:()=>{l==null||l.setTimeCursor(null),ot("history:scrub",{cursorWallTs:null})}};return{name:"HistoryPlugin",install(y){a=y.getState,l=y.__gantt??null,l&&(l.history=h,typeof l.registerReplayProvider=="function"&&(u=l.registerReplayProvider({snapshotAt:b=>S(b)}))),ot("history:hydrate",{entryCount:o.length})},middleware:f,destroy(){d&&(clearTimeout(d),d=null),u&&(u(),u=null),l&&l.history===h&&(l.history=null),l=null}}}const Yd="#3b82f6",Wd=2,Xd="#10b981",zd=864e5;function Gd(e={}){let t=null,n=null,s=null;const o=e.cursorColor??Yd,i=e.cursorWidth??Wd,a=e.showNowBracket!==!1,l=e.nowBracketColor??Xd,u=e.enableKeyboardShortcuts!==!1,d=e.stepMs??zd;function g(c){if(!n)return;const S=n.getTimeCursor()??new Date,v=new Date(S.getTime()+c);n.setTimeCursor(v)}function p(){if(!(n!=null&&n.history))return;const c=n.history.entries();c.length!==0&&n.setTimeCursor(new Date(c[0].wallTs))}function r(c){const f=document.activeElement;if(!(f&&(f.tagName==="INPUT"||f.tagName==="TEXTAREA"||f.isContentEditable))){if(c.key==="Home"){c.preventDefault(),p();return}if(c.key==="End"){c.preventDefault(),n==null||n.setTimeCursor(null);return}if(c.key==="ArrowLeft"&&(c.altKey||c.metaKey)){c.preventDefault(),g(-d);return}if(c.key==="ArrowRight"&&(c.altKey||c.metaKey)){c.preventDefault(),g(d);return}}}return{name:"TimeCursorPlugin",install(c){t=c,n=c.__gantt??null,u&&typeof document<"u"&&(s=r,document.addEventListener("keydown",s))},renderCanvas(c,f,S){if(!t)return;const{config:v,scrollX:h}=f,y=v.headerHeight,b=typeof window<"u"&&window.devicePixelRatio||1,m=c.canvas.width/b,T=c.canvas.height/b,w=y,k=T-w;let D;try{D=t.getTimeScale()}catch{return}if(c.save(),c.beginPath(),c.rect(0,w,m,k),c.clip(),c.translate(-h,0),a){const C=D.dateToX(new Date);c.save(),c.strokeStyle=l,c.lineWidth=3,c.beginPath(),c.moveTo(C-6,w+1),c.lineTo(C+6,w+1),c.moveTo(C-6,w+k-1),c.lineTo(C+6,w+k-1),c.stroke(),c.restore()}const E=f.timeCursorDate;if(E){const C=D.dateToX(E);c.save(),c.strokeStyle=o,c.lineWidth=i,c.beginPath(),c.moveTo(C,w),c.lineTo(C,w+k),c.stroke(),c.fillStyle=o,c.beginPath(),c.moveTo(C-6,w),c.lineTo(C+6,w),c.lineTo(C,w+8),c.closePath(),c.fill(),c.restore()}c.restore()},destroy(){s&&typeof document<"u"&&document.removeEventListener("keydown",s),s=null,t=null,n=null}}}const Vd=14,Kd=4,jd=6,qd="#6b7280",Zd={comment:"#3b82f6",decision:"#8b5cf6","agent-note":"#10b981",view:"#a3a3a3"};function Jd(e={}){let t=null,n=null;const s=e.height??Vd,o=e.position??"above-body",i=e.markerRadius??Kd,a=e.clusterDistancePx??jd,l=e.fallbackColor??qd,u={...Zd,...e.colorByKind??{}};return{name:"HistoryStripPlugin",install(d){t=d,n=d.__gantt??null},renderCanvas(d,g,p){if(!t||!(n!=null&&n.history))return;const r=n.history.annotations();if(r.length===0)return;const{config:c,scrollX:f}=g,S=c.headerHeight,v=typeof window<"u"&&window.devicePixelRatio||1,h=d.canvas.width/v;let y;try{y=t.getTimeScale()}catch{return}const b=o==="above-body"?S-s:S+2;d.save(),d.beginPath(),d.rect(0,b,h,s),d.clip(),d.translate(-f,0);const m=[];for(const k of r){const D=y.dateToX(new Date(k.wallTs));m.push({x:D,ann:k})}m.sort((k,D)=>k.x-D.x);const T=[];for(const k of m){const D=T[T.length-1];D&&Math.abs(k.x-D.x)<=a?(D.entries.push(k),D.x=D.entries.reduce((E,C)=>E+C.x,0)/D.entries.length):T.push({x:k.x,entries:[k]})}const w=[];for(const k of T){const D=b+s/2,E=k.entries.length>1,C=k.entries[0].ann.kind,M=u[C]??l;d.fillStyle=M,d.beginPath(),d.arc(k.x,D,E?i+1:i,0,Math.PI*2),d.fill(),E&&(d.fillStyle="#ffffff",d.font="600 9px sans-serif",d.textBaseline="middle",d.textAlign="center",d.fillText(String(k.entries.length),k.x,D+.5)),w.push({cx:k.x,cy:D,r:E?i+1:i,annotations:k.entries.map(A=>A.ann)})}d.restore()},destroy(){t=null,n=null}}}const ki="nimbus-gantt-ctxmenu-styles",pe="ng-ctxmenu",Di={maxCalls:1,windowMs:2e3};function Qd(e){if(e===!1)return()=>!0;const t=e??Di,n=[];return function(){const o=Date.now(),i=o-t.windowMs;for(;n.length>0&&n[0]<i;)n.shift();return n.length>=t.maxCalls?!1:(n.push(o),!0)}}function Ei(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:Date.now(),kind:e,...t??{}})}function eu(e={}){let t=null,n=null,s=null,o=null,i=null,a=null;const l=Qd(e.agentRateLimit===void 0?Di:e.agentRateLimit);async function u(h,y){if(e.onConfirmDestructive)try{return!!await e.onConfirmDestructive(h,y)}catch{return!1}if(typeof window<"u"&&typeof window.confirm=="function"){const b=h==="task"?`Delete task "${y}"?`:`Delete dependency "${y}"?`;try{return window.confirm(b)}catch{return!1}}return!0}function d(){if(typeof document>"u"||document.getElementById(ki))return;const h=document.createElement("style");h.id=ki,h.textContent=`
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
    `,document.head.appendChild(h)}function g(){if(s){try{s.remove()}catch{}s=null}a&&typeof document<"u"&&(document.removeEventListener("pointerdown",a,!0),document.removeEventListener("keydown",a,!0),a=null)}function p(h,y,b){if(typeof document>"u"||h.length===0)return;g(),d();const m=document.createElement("div");m.className=pe,m.setAttribute("role","menu"),m.style.left=`${y.x}px`,m.style.top=`${y.y}px`,m.addEventListener("pointerdown",T=>{T.stopPropagation()});for(const T of h){if(T.divider){const E=document.createElement("div");E.className=`${pe}-divider`,m.appendChild(E);continue}const w=document.createElement("div");w.className=`${pe}-item`,T.disabled&&w.setAttribute("aria-disabled","true");const k=document.createElement("span");k.className=`${pe}-icon`,T.agentSuggested&&k.classList.add(`${pe}-agent-glyph`),k.textContent=T.icon??(T.agentSuggested?"✦":""),w.appendChild(k);const D=document.createElement("span");if(D.className=`${pe}-label`,D.textContent=T.label,w.appendChild(D),T.shortcut){const E=document.createElement("span");E.className=`${pe}-shortcut`,E.textContent=T.shortcut,w.appendChild(E)}if(T.children&&T.children.length>0){const E=document.createElement("span");E.className=`${pe}-arrow`,E.textContent="▸",w.appendChild(E);let C=null;w.addEventListener("mouseenter",()=>{if(C)return;const M=w.getBoundingClientRect();C=document.createElement("div"),C.className=pe,C.style.left=`${M.right+2}px`,C.style.top=`${M.top}px`;for(const A of T.children){const R=r(A,b);C.appendChild(R)}document.body.appendChild(C)}),w.addEventListener("mouseleave",()=>{if(C){try{C.remove()}catch{}C=null}})}else T.disabled||w.addEventListener("click",E=>{E.stopPropagation(),c(T,b,y)});m.appendChild(w)}document.body.appendChild(m),s=m,a=T=>{T instanceof KeyboardEvent&&T.key!=="Escape"||T.type==="pointerdown"&&T.target instanceof Element&&T.target.closest(`.${pe}`)||g()},document.addEventListener("pointerdown",a,!0),document.addEventListener("keydown",a,!0),requestAnimationFrame(()=>{if(!s)return;const T=s.getBoundingClientRect(),w=window.innerWidth,k=window.innerHeight;let D=T.left,E=T.top;T.right>w&&(D=Math.max(4,w-T.width-4)),T.bottom>k&&(E=Math.max(4,k-T.height-4)),s.style.left=`${D}px`,s.style.top=`${E}px`})}function r(h,y){if(h.divider){const w=document.createElement("div");return w.className=`${pe}-divider`,w}const b=document.createElement("div");b.className=`${pe}-item`,h.disabled&&b.setAttribute("aria-disabled","true");const m=document.createElement("span");m.className=`${pe}-icon`,h.agentSuggested&&m.classList.add(`${pe}-agent-glyph`),m.textContent=h.icon??(h.agentSuggested?"✦":""),b.appendChild(m);const T=document.createElement("span");return T.className=`${pe}-label`,T.textContent=h.label,b.appendChild(T),h.disabled||b.addEventListener("click",w=>{w.stopPropagation(),c(h,y,{x:0,y:0})}),b}function c(h,y,b){if(g(),h.agentSuggested&&h.prompt&&e.onAgentRequest&&(t!=null&&t.agent)){if(!l()){Ei("ctxmenu:agent-rate-limited",{itemId:h.id});return}const m={hit:y,pos:b,prompt:h.prompt,snapshot:t.agent.getSnapshot()};try{const T=e.onAgentRequest(m);T&&typeof T.catch=="function"&&T.catch(()=>{})}catch{}return}if(h.onClick)try{const m=h.onClick();m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}function f(h,y,b){return async()=>{await u(h,y)?b():Ei("ctxmenu:destructive-cancelled",{kind:h,label:y})}}function S(h,y){const b=[],m=!!e.onAgentRequest&&!e.hideAgentSubmenu;switch(h.zone){case"bar":return b.push({id:"edit",label:"Edit task…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",h.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",h.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",h.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",h.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",h.task.name||h.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",h.task,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-why",label:"Ask Claude: why is this scheduled here?",agentSuggested:!0,prompt:`Explain why task "${h.task.name}" (id ${h.task.id}) is scheduled from ${h.task.startDate} to ${h.task.endDate} given current dependencies, parent context, and bucket assignment.`},{id:"agent-blocks",label:"Ask Claude: what blocks this?",agentSuggested:!0,prompt:`What dependencies, capacity constraints, or upstream blockers are gating task "${h.task.name}" (id ${h.task.id})? Walk the dependency graph and list the critical path.`},{id:"agent-resched",label:"Ask Claude: reschedule with critical-path optimization",agentSuggested:!0,prompt:`Suggest a new schedule for task "${h.task.name}" (id ${h.task.id}) that optimizes the critical path. Stage hypotheses via gantt.agent if possible.`}),b;case"row-label":return b.push({id:"edit",label:"Edit name…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",h.task,y)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",h.task,y)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",h.task,y)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",h.task,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",h.task.name||h.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",h.task,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-summarize",label:"Ask Claude: summarize this task",agentSuggested:!0,prompt:`Summarize task "${h.task.name}" (id ${h.task.id}) including its current status, parent, dependencies, and recent history if available.`}),b;case"date-header":{const T=h.date.toISOString().slice(0,10);return b.push({id:"scroll-here",label:`Scroll to ${T}`,icon:"↔",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"scroll-here",h.date,y)}},{id:"zoom-to",label:"Zoom to this range",icon:"⊕",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"zoom-to",h.date,y)}},{id:"add-milestone",label:`Add milestone on ${T}`,icon:"◆",onClick:()=>{var w;return(w=e.onDateAction)==null?void 0:w.call(e,"add-milestone",h.date,y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-summary",label:`Ask Claude: what's happening around ${T}?`,agentSuggested:!0,prompt:`Summarize tasks, milestones, and dependencies that intersect ${T}. Note any clusters, conflicts, or capacity hotspots.`}),b}case"canvas-empty":{const T=h.date.toISOString().slice(0,10),w=T,k=(()=>{const D=new Date(h.date);return D.setUTCDate(D.getUTCDate()+5),D.toISOString().slice(0,10)})();return b.push({id:"create-task",label:`Create work item starting ${T}`,icon:"＋",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:w,endDate:k,parentId:((D=h.nearestTask)==null?void 0:D.parentId)??null,bucket:h.bucketId},y)}},{id:"create-milestone",label:`Insert milestone on ${T}`,icon:"◆",onClick:()=>{var D,E;return(E=e.onCreateTask)==null?void 0:E.call(e,{startDate:T,endDate:T,parentId:((D=h.nearestTask)==null?void 0:D.parentId)??null,bucket:h.bucketId},y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-suggest",label:"Ask Claude: suggest a task here",agentSuggested:!0,prompt:`Given the project context and the dates around ${T}${h.bucketId?` in bucket "${h.bucketId}"`:""}, suggest a sensible work item to insert. Consider open dependencies, capacity, and priority.`}),b}case"bucket-header":{const T=h.bucketTask.name||h.bucketId||"(bucket)";return b.push({id:"add-to-bucket",label:`Add task to ${T}`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:new Date().toISOString().slice(0,10),endDate:new Date(Date.now()+432e6).toISOString().slice(0,10),parentId:h.bucketTask.id,bucket:h.bucketId},y)}},{id:"collapse",label:`Collapse all in ${T}`,icon:"⊟",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"collapse",h.bucketTask,y)}},{id:"expand",label:`Expand all in ${T}`,icon:"⊞",onClick:()=>{var w;return(w=e.onTaskAction)==null?void 0:w.call(e,"expand",h.bucketTask,y)}}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-rebalance",label:`Ask Claude: rebalance ${T}`,agentSuggested:!0,prompt:`Review the tasks in bucket "${T}" for capacity, sequencing, and priority alignment. Suggest moves to/from adjacent buckets and reordering within.`}),b}case"below-rows":{const T=h.date.toISOString().slice(0,10);return b.push({id:"create-end",label:`Add new task at end (starts ${T})`,icon:"＋",onClick:()=>{var w;return(w=e.onCreateTask)==null?void 0:w.call(e,{startDate:T,endDate:new Date(h.date.getTime()+432e6).toISOString().slice(0,10),parentId:null,bucket:null},y)}}),b}case"dependency":return b.push({id:"change-fs",label:"Change type → Finish-to-Start (FS)",icon:"→",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-fs",h.depId,y)}},{id:"change-ss",label:"Change type → Start-to-Start (SS)",icon:"↦",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ss",h.depId,y)}},{id:"change-ff",label:"Change type → Finish-to-Finish (FF)",icon:"↤",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ff",h.depId,y)}},{id:"change-sf",label:"Change type → Start-to-Finish (SF)",icon:"↔",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-sf",h.depId,y)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete dependency",icon:"×",onClick:f("dependency",h.depId,()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"delete",h.depId,y)})}),m&&b.push({id:"div-agent",label:"",divider:!0},{id:"agent-explain-dep",label:"Ask Claude: is this dependency necessary?",agentSuggested:!0,prompt:`Evaluate dependency ${h.depId}. Is it logically required, or could the predecessor and successor run in parallel? Consider data flow, resource contention, and external constraints.`}),b;case"outside":default:return[]}}function v(h){if(!t||!n||h.button!==void 0&&h.button!==2)return;const y=t.hitTestAt(h.clientX,h.clientY);if(y.zone==="outside")return;h.preventDefault(),h.stopPropagation();const b={x:h.clientX,y:h.clientY};let m=null;if(e.onContextMenu)try{m=e.onContextMenu(y,b)}catch{m=null}const T=m&&Array.isArray(m)&&m.length>0?m:S(y,b);T.length>0&&p(T,b,y)}return{name:"ContextMenuPlugin",install(h){t=h.__gantt??null,n=(t&&t.rootEl)??null;const y=n??(typeof document<"u"?document:null);y&&(o=b=>v(b),y.addEventListener("contextmenu",o),e.disablePointerDownFallback||(i=b=>{b.button===2&&v(b)},y.addEventListener("pointerdown",i)))},destroy(){g();const h=n??(typeof document<"u"?document:null);h&&(o&&h.removeEventListener("contextmenu",o),i&&h.removeEventListener("pointerdown",i)),o=null,i=null,t=null,n=null}}}return J.AutoSchedulePlugin=Yr,J.BaselinePlugin=Xa,J.CLOUD_NIMBUS_PRIORITY_BUCKETS=Ia,J.ConfigPanelPlugin=xl,J.ContextMenuPlugin=eu,J.CriticalPathPlugin=_a,J.DARK_THEME=ks,J.DarkThemePlugin=ir,J.DependencyRenderer=ms,J.EventBus=os,J.ExportPlugin=Ja,J.GroupingPlugin=ka,J.HeatmapViewPlugin=jl,J.HistoryPlugin=Ud,J.HistoryStripPlugin=Jd,J.HitTest=hs,J.KeyboardPlugin=ia,J.LIGHT_THEME=pn,J.LayoutEngine=cs,J.MSProjectPlugin=wr,J.MilestonePlugin=ga,J.MiniMapPlugin=rc,J.MonteCarloPlugin=Kc,J.MotionControlPlugin=mr,J.NarrativePlugin=od,J.NetworkGraphPlugin=Pl,J.NimbusGantt=Ji,J.PriorityGroupingPlugin=Ca,J.ResourceLevelingPlugin=Ur,J.RiskAnalysisPlugin=fl,J.SonificationPlugin=Cd,J.SplitTaskPlugin=Pr,J.TelemetryPlugin=hr,J.TemporalAsymmetryPlugin=Pd,J.TimeCursorPlugin=Gd,J.TimeScale=rs,J.TimeTravelPlugin=Nc,J.TimelineNotesPlugin=Dc,J.TooltipManager=ws,J.UndoRedoPlugin=sa,J.VirtualScrollPlugin=Ka,J.WhatIfPlugin=pd,J.WorkCalendarPlugin=dr,J.buildDependencyGraph=po,J.computeCPM=Tn,J.computeSchedule=_n,J.exportMSProjectXML=Mn,J.getAllParentIds=Cs,J.getDescendantIds=Is,J.hoursWeightedProgress=Ma,J.importMSProjectXML=In,J.parseDate=bt,J.resolveConfig=Ds,J.rollupHoursDeduped=ta,Object.defineProperty(J,Symbol.toStringTag,{value:"Module"}),J})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
