var NimbusGantt=(function(ne){"use strict";function xe(e,t){const n=new Map;for(const l of e.values()){const u=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let c=n.get(u);c||(c=[],n.set(u,c)),c.push(l)}const s=[];function o(l,u){const c=l.sortOrder??Number.MAX_SAFE_INTEGER,h=u.sortOrder??Number.MAX_SAFE_INTEGER;return c!==h?c-h:l.name.localeCompare(u.name)}function i(l,u,c){const h=n.get(l);return h?(h.sort(o),h.map(p=>{const d=n.has(p.id)&&t.has(p.id),g=c,b={task:p,children:[],depth:u,expanded:d,visible:g,rowIndex:-1};return g&&(b.rowIndex=s.length,s.push(p.id)),b.children=i(p.id,u+1,g&&d),b})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function gt(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class jn{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=oi(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function oi(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=xe(n,e.expandedIds),a=gt(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=xe(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=xe(n,e.expandedIds),i=gt(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=xe(n,e.expandedIds),i=gt(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=xe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=xe(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=xe(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=gt(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};default:return e}}function qn(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class Zn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const an=864e5,ii=an*7,ai={day:40,week:120,month:180,quarter:200},Jn=["January","February","March","April","May","June","July","August","September","October","November","December"],Qn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class es{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=ai[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/an)}countWeeks(){return Math.ceil(this.totalMs/ii)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=ts(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=rn(i),l=this.dateToX(i),u=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${Jn[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:u-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=ts(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${Qn[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=rn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,u=this.dateToX(a),c=this.dateToX(l);t.push({label:`${Jn[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:u,width:c-u,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:Qn[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=rn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,u=a*this.columnWidth;n.push({label:`Q${l}`,x:u,width:this.columnWidth,date:new Date(o)}),o=ri(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,u=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,c=this.dateToX(l),h=this.dateToX(u);t.push({label:String(i.getUTCFullYear()),x:c,width:h-c,date:new Date(l)}),i=a}return[t,n]}}function ts(e,t){return new Date(e.getTime()+t*an)}function ri(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function rn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class ns{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],u=n.get(l);if(!u)continue;const c=ht(u.startDate),h=ht(u.endDate),p=s.dateToX(c),r=s.dateToX(h)-p,d=Math.max(r,o.minBarWidth),g=a*o.rowHeight,b=g+(o.rowHeight-o.barHeight)/2,T=d*(u.progress||0),f=u.color||o.colorMap[u.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:p,y:g,width:d,barY:b,barHeight:o.barHeight,progressWidth:T,color:f,textColor:o.theme.barTextColor,label:u.status==="group-header"?u.name:(u.hoursLabel||(u.hours!=null?`${u.hours}h`:""))+(u.hoursLabel||u.hours!=null?" · ":"")+((u.progress||0)>0?`${Math.round((u.progress||0)*100)}% · `:"")+(u.title||u.name),isMilestone:u.isMilestone||!1})}return i}}function ht(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const It=864e5,ss=1,li=2,ci=.5,di=2,os=8,ui=6,ln=2;class gi{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:u}=t,{theme:c}=u,h=t.scrollX,p=t.scrollY;o.setTransform(l,0,0,l,0,0);const d=u.headerHeight,g=a-d;this.fillRect(0,0,i,a,c.timelineBg),o.save(),o.beginPath(),o.rect(0,d,i,g),o.clip(),o.translate(-h,0),u.showWeekends&&this.renderWeekendShading(t,s,d,g,c),this.renderGridLines(s,d,g,c,h),this.renderAltRows(t,n,d,c,h,p);const b=this.getTodayX(t,u,s);u.showToday&&b!==null&&this.renderTodayBackground(b,s,d,g,c),this.renderGroupRowBgs(t,n,u,h,p,d,g),this.renderTaskBars(t,n,u,c,h,p,d,g),this.renderDragSnapGuide(t,n,s,d,g,c),u.showToday&&b!==null&&this.renderTodayLine(b,d,g,c),o.restore(),this.renderHeader(s,u,c,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,u=new Date(a);u.setUTCHours(0,0,0,0);const c=l.getTime();for(;u.getTime()<=c;){const h=u.getUTCDay();if(h===0||h===6){const p=n.dateToX(u),r=new Date(u.getTime()+It),g=n.dateToX(r)-p;this.fillRect(p,s,g,o,i.timelineWeekendBg)}u.setTime(u.getTime()+It)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=ci;for(const u of l){const c=this.snapToPixel(u);a.moveTo(c,n),a.lineTo(c,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:u}=this,c=t.config.rowHeight,h=t.flatVisibleIds.length;for(let p=0;p<h;p++)if(p%2===1){const r=s+p*c-a;if(r+c<s||r>s+this.displayHeight)continue;this.fillRect(i,r,u+i,c,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+It),u=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,u,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:u,displayWidth:c}=this,h=s.rowHeight;for(const p of n){const r=t.tasks.get(p.taskId);if(!r||!r.groupBg)continue;const d=p.y-i+a;d+h<a||d>a+l||(u.save(),u.fillStyle=r.groupBg,u.fillRect(o,d,c,h),r.groupColor&&(u.fillStyle=r.groupColor,u.fillRect(o,d,c,2)),u.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const l=t.dragState;if(!l||l.type!=="move"&&l.type!=="resize-left"&&l.type!=="resize-right")return;const u=n.find(T=>T.taskId===l.taskId);if(!u)return;const c=new Date;c.setHours(0,0,0,0);const h=new Date(c.getTime()+It),p=s.dateToX(h)-s.dateToX(c);if(p<=0)return;const r=l.currentX-l.startX;let d;l.type==="move"||l.type==="resize-left"?d=u.x+r:d=u.x+u.width+r;const g=Math.round(d/p)*p,{ctx:b}=this;b.save(),b.strokeStyle=a.barSelectedBorder||"#3b82f6",b.lineWidth=1,b.setLineDash([4,3]),b.globalAlpha=.85,b.beginPath(),b.moveTo(g+.5,o),b.lineTo(g+.5,o+i),b.stroke(),b.restore()}renderTaskBars(t,n,s,o,i,a,l,u){const{ctx:c}=this,h=o.barBorderRadius,p=t.dragState,r=p?p.currentX-p.startX:0,d=4;for(const g of n){let b=g.x;const T=g.barY-a+l;let f=g.width;const y=g.barHeight;if(T+y<l||T>l+u)continue;const v=p&&p.taskId===g.taskId;if(v){if(p.type==="move")b+=r;else if(p.type==="resize-left"){const w=b+r,D=f-r;D>=d&&(b=w,f=D)}else if(p.type==="resize-right"){const w=f+r;w>=d&&(f=w)}}if(g.isMilestone){this.renderMilestone(b,T,y,g.color,o,t.selectedIds.has(g.taskId));continue}const m=t.tasks.get(g.taskId),S=m&&m.status!=="group-header"&&m.style?m.style:null,k=S?this.resolveFillOpacity(S):1;if(k<1?(c.save(),c.globalAlpha=k,this.fillRoundedRect(b,T,f,y,h,g.color),c.restore()):this.fillRoundedRect(b,T,f,y,h,g.color),s.showProgress&&g.progressWidth>0){const w=this.darkenColor(g.color,.2);c.save(),c.beginPath(),this.roundedRectPath(b,T,f,y,h),c.clip(),c.fillStyle=w,c.fillRect(b,T,g.progressWidth,y),c.restore()}t.selectedIds.has(g.taskId)&&this.strokeRoundedRect(b,T,f,y,h,o.barSelectedBorder,ln),v&&this.strokeRoundedRect(b,T,f,y,h,o.barSelectedBorder,ln),S&&S.borderStyle&&S.borderStyle!=="none"&&this.renderDecoratorBorder(S,b,T,f,y,h,g.color),this.renderBarLabel(g,b,T,f,y,o),S&&S.badge&&S.badge.text&&this.renderDecoratorBadge(S.badge,b,T,f,y,g.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,l){const{ctx:u}=this,c=t.borderWidth??2,h=t.borderColor??this.darkenColor(l,.3),p=t.borderStyle??"solid";let r;switch(p){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(u.save(),u.setLineDash(r),u.strokeStyle=h,u.lineWidth=c,this.roundedRectPath(n,s,o,i,a),u.stroke(),p==="double"){const d=c+1,g=Math.max(0,a-d);u.lineWidth=c,this.roundedRectPath(n+d,s+d,Math.max(0,o-d*2),Math.max(0,i-d*2),g),u.stroke()}u.restore()}renderDecoratorBadge(t,n,s,o,i,a,l){const{ctx:u}=this,c=t.text,h=t.placement??"end",p=Math.max(14,i*.65),r=6;u.save();const d=`${Math.round(l.fontSize*.85)}px ${l.fontFamily}`;u.font=d,u.textBaseline="middle";const b=u.measureText(c).width+r*2,T=s+(i-p)/2,f=h==="start"?n+2:n+o-b-2;u.shadowColor="rgba(0,0,0,0.25)",u.shadowBlur=3,u.shadowOffsetY=1;const y=t.color??"#ffffff";u.fillStyle=y,this.roundedRectPath(f,T,b,p,p/2),u.fill(),u.shadowColor="transparent",u.shadowBlur=0,u.shadowOffsetY=0,u.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),u.textAlign="center",u.fillText(c,f+b/2,T+p/2),u.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,u=(s-di*2)/2,c=n+s/2;l.save(),l.beginPath(),l.moveTo(t,c-u),l.lineTo(t+u,c),l.lineTo(t,c+u),l.lineTo(t-u,c),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=ln,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const u=`${a.fontSize}px ${a.fontFamily}`;l.font=u,l.textBaseline="middle";const c=l.measureText(t.label).width,h=s+i/2;c+os*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+os,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+ui,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=li,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,u=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const c=u.length||2,h=l/c,p=`${s.fontSize}px ${s.fontFamily}`;i.font=p,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let d=0;d<u.length;d++){const g=u[d],b=d*h;for(const T of g){const f=T.x-o,y=T.width;if(f+y<0||f>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=ss;const v=this.snapToPixelRaw(f+y);i.moveTo(v,b),i.lineTo(v,b+h),i.stroke(),i.save(),i.beginPath(),i.rect(f,b,y,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=d===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(T.label,f+y/2,b+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=ss,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:u}=this;u.beginPath(),this.roundedRectPath(t,n,s,o,i),u.strokeStyle=a,u.lineWidth=l,u.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=u=>u.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const is="ng-tree-grid-styles";function hi(e,t){const n=e.querySelector(`#${is}`);n&&n.remove();const s=document.createElement("style");s.id=is,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function fi(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Mt(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class pi{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;hi(this.rootEl,a),this.columns=o,this.columnWidths=o.map(c=>c.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=fi(n),u=l.map(c=>c.task.id);this.updateRows(l,u,t),this.currentVisibleIds=u}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],u=l.querySelector(".ng-th-text");u&&u.textContent!==t[a].header&&(u.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const u=document.createElement("th");u.className="ng-grid-th",u.setAttribute("data-field",a.field);const c=document.createElement("span");c.className="ng-th-text",c.textContent=a.header,u.appendChild(c);const h=document.createElement("span");h.className="ng-resize-handle",u.appendChild(h),this.attachResizeListener(h,l),i.appendChild(u)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=c=>{const h=c.clientX-o,p=Math.max(a,i+h);this.columnWidths[n]=p;const r=this.headerColgroup.children,d=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${p}px`),d[n]&&(d[n].style.width=`${p}px`)},u=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",u),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",u)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const c of t)l.set(c.task.id,c);for(const[c,h]of this.rows)a.has(c)||(h.remove(),this.rows.delete(c));let u=null;for(let c=0;c<t.length;c++){const h=t[c],p=h.task.id;let r=this.rows.get(p);r?this.updateRowContent(r,h,c,s):(r=this.createRow(h,c,s),this.rows.set(p,r)),r.style.height=`${i}px`,u?u.nextSibling!==r&&this.tbody.insertBefore(r,u.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),u=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const u of i){const c=this.createCell(t,u,s);l.appendChild(c)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const c=document.createElement("span");c.className="ng-expand-icon",t.expanded&&c.classList.add("ng-expanded"),c.innerHTML="&#9654;",c.setAttribute("data-expand",t.task.id),o.appendChild(c)}else{const c=document.createElement("span");c.className="ng-expand-spacer",o.appendChild(c)}if(t.children.length===0&&!t.task.groupBg){const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",o.appendChild(c)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const c=document.createElement("span");c.className="ng-status-dot",c.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(c)}const u=document.createElement("span");u.className="ng-grid-cell-text",u.textContent=Mt(t.task,n),o.appendChild(u)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=Mt(t.task,n);return o}updateRowContent(t,n,s,o){var u;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let c=0;c<a.length;c++){const h=a[c],p=l[c];if(!p){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const d=`${n.depth*20+8}px`;p.style.paddingLeft!==d&&(p.style.paddingLeft=d);const g=p.querySelector(".ng-expand-icon"),b=p.querySelector(".ng-expand-spacer");if(n.children.length>0)if(g)n.expanded?g.classList.add("ng-expanded"):g.classList.remove("ng-expanded");else{b&&b.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),p.insertBefore(m,p.firstChild)}else if(g){g.remove();const m=document.createElement("span");m.className="ng-expand-spacer",p.insertBefore(m,p.firstChild)}const T=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!T){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const S=p.querySelector(".ng-status-dot")||p.querySelector(".ng-grid-cell-text");S?p.insertBefore(m,S):p.appendChild(m)}}else T&&T.remove();const f=p.querySelector(".ng-status-dot"),y=n.task.color||((u=o.config.colorMap)==null?void 0:u[n.task.status??""])||"";if(y&&n.children.length===0)if(f)f.style.background=y;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${y};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const S=p.querySelector(".ng-grid-cell-text");S?p.insertBefore(m,S):p.appendChild(m)}else f&&f.remove();const v=p.querySelector(".ng-grid-cell-text");if(v){const m=Mt(n.task,h);v.textContent!==m&&(v.textContent=m)}}else if(h.field==="_drag"){const r=p.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){p.textContent="";const d=document.createElement("span");d.className="ng-drag-handle",d.innerHTML="&#9776;",p.appendChild(d)}}else r&&(p.textContent="")}else{const r=Mt(n.task,h);p.textContent!==r&&(p.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class mi{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class as{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:u}=s;if(t<i||t>i+l||n<a||n>a+u)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const c=i+s.progressWidth;if(Math.abs(t-c)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const rs=864e5;function At(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/rs)}function ft(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function _e(e,t){const n=ft(e),s=new Date(n.getTime()+t*rs),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function ls(e,t,n){return Math.max(t,Math.min(n,e))}const yi=3,Ti=300;class bi{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new as,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.panning){t.preventDefault();const l=t.clientX-this.panStartClientX,u=t.clientY-this.panStartClientY,c=this.options.scrollManager;if(c){const h=Math.max(0,this.panOrigScrollX-l),p=Math.max(0,this.panOrigScrollY-u);c.setScrollPosition(h,p)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const u=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-u.left,t.clientY-u.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const u=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=u.x,this.panOrigScrollY=u.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l){this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const u=vi(a.type);u&&this.options.dispatch({type:"DRAG_START",drag:{type:u,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=At(i,o);let l="";if(this.dragHit.type==="bar"){const d=_e(this.dragOriginalStartDate,a),g=_e(this.dragOriginalEndDate,a);l=`${d} → ${g}`}else if(this.dragHit.type==="bar-left-edge")l=`Start → ${_e(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")l=`End → ${_e(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const d=this.dragHit.layout,{canvasX:g}=this.toCanvasCoords(t),b=g-d.x;l=`${Math.round(ls(b/d.width,0,1)*100)}%`}if(!l)return;if(!this.gestureLabelEl){const d=document.createElement("div");d.setAttribute("data-nga-gesture-label","1"),d.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(d),this.gestureLabelEl=d,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=l;const u=12,c=window.innerWidth||document.documentElement.clientWidth,h=this.gestureLabelEl.offsetWidth,p=Math.min(t.clientX+u,c-h-4),r=t.clientY+u;this.gestureLabelEl.style.left=`${p}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<yi?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Ti){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var u,c,h,p,r,d,g,b,T,f;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,l=t.clientX-this.dragStartX;switch(a){case"bar":{const y=t.clientY-this.dragStartY,v=Math.abs(l),m=Math.abs(y),S=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),k=m>v*1.5&&m>12;if(S&&k){const I=this.options.getLayouts(),M=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),R=I.find(P=>P.rowIndex===M),_=R?R.taskId:null;let H=null;const N=I.slice().sort((P,B)=>P.rowIndex-B.rowIndex);for(const P of N){if(P.rowIndex>M)break;const B=P.taskId;typeof B=="string"&&B.indexOf("__bucket_header__")===0&&(H=B.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",M,"target=",_,"bucket=",H)}catch{}(c=(u=this.options).onBarReorderDrag)==null||c.call(u,s,_,M,H);break}const w=At(l,o),D=_e(this.dragOriginalStartDate,w),E=_e(this.dragOriginalEndDate,w);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:D,endDate:E});try{console.log("[NG engine] drag commit move",s.id,D,E,"hasCb=",!!this.options.onTaskMove)}catch{}(p=(h=this.options).onTaskMove)==null||p.call(h,s,D,E);break}case"bar-left-edge":{const y=At(l,o),v=_e(this.dragOriginalStartDate,y),m=ft(this.dragOriginalEndDate),k=ft(v).getTime()>=m.getTime()?_e(this.dragOriginalEndDate,-1):v;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:k,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,k,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(d=(r=this.options).onTaskResize)==null||d.call(r,s,k,this.dragOriginalEndDate);break}case"bar-right-edge":{const y=At(l,o),v=_e(this.dragOriginalEndDate,y),m=ft(this.dragOriginalStartDate),k=ft(v).getTime()<=m.getTime()?_e(this.dragOriginalStartDate,1):v;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:k});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,k,"hasCb=",!!this.options.onTaskResize)}catch{}(b=(g=this.options).onTaskResize)==null||b.call(g,s,this.dragOriginalStartDate,k);break}case"progress-handle":{const y=this.dragHit.layout,{canvasX:v}=this.toCanvasCoords(t),m=v-y.x,S=ls(m/y.width,0,1),k=Math.round(S*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:k}}),(f=(T=this.options).onTaskProgressChange)==null||f.call(T,s,k);break}}this.options.dispatch({type:"DRAG_END"})}}function vi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const ot=12,Lt=6,Rt=4,wi=3;class cs{render(t,n,s,o,i,a,l){const{dependencies:u}=n;if(u.size===0)return;const c=new Map;for(const r of s)c.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),p=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,p-l),t.clip(),t.translate(-i,0);for(const r of u.values()){const d=c.get(r.source),g=c.get(r.target);if(!d||!g)continue;const b=r.type||"FS",{sourceX:T,sourceY:f,targetX:y,targetY:v}=this.getConnectionPoints(b,d,g,a,l);this.drawRoutedPath(t,b,T,f,y,v,o),this.drawArrowhead(t,b,y,v,o),this.drawConnectionDot(t,T,f,o),this.drawConnectionDot(t,y,v,o)}t.restore()}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const u=n==="FS"||n==="FF",c=n==="FS"||n==="SS",h=u?s+ot:s-ot,p=c?i-ot:i+ot;if(u?c?p>=h:i+ot>=h:c?i-ot<=h:p<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const d=(o+a)/2;t.lineTo(h,o),t.lineTo(h,d),t.lineTo(p,d),t.lineTo(p,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-Lt,o-Rt),t.lineTo(s-Lt,o+Rt)):(t.moveTo(s,o),t.lineTo(s+Lt,o-Rt),t.lineTo(s+Lt,o+Rt)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,wi,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const Pt=12,Si=100,Ei=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Di=`
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
`;function it(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function ds(e){const t=e.split("-");if(t.length!==3)return it(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?it(e):`${Ei[n]} ${s}`}function pt(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${it(e)}</span><span class="ng-tooltip-value">${it(t)}</span></div>`}function ki(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=pt("Status",e.status||"None"),i+=pt("Assignee",e.assignee||"Unassigned"),i+=pt("Dates",`${ds(e.startDate)} → ${ds(e.endDate)}`),n>0&&(i+=pt("Progress",`${n}%`)),s!=null&&(i+=pt("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${it(t)}"><span class="ng-tooltip-name">${it(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class us{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Di,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const c=this.customRenderer(t);typeof c=="string"?this.tooltipEl.innerHTML=c:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(c))}else this.tooltipEl.innerHTML=ki(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+Pt,u=s+Pt;l+i.width>a.width&&(l=n-Pt-i.width),u+i.height>a.height&&(u=s-Pt-i.height),l=Math.max(0,l),u=Math.max(0,u),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${u}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Si))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const cn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},gs={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Ci=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function hs(e){const t=Ii(e.theme);return{columns:e.columns??Ci,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function Ii(e){return!e||e==="light"?{...cn}:e==="dark"?{...gs}:{...cn,...e}}function at(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const fs="nimbus-gantt-root-styles";function Mi(){if(typeof document>"u"||document.getElementById(fs))return;const e=document.createElement("style");e.id=fs,e.textContent=`
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
  `,document.head.appendChild(e)}class Ai{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.container=t,this.config=hs(n),Mi(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=xe(s,i),u=gt(s),c={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:u,dragState:null,config:this.config};if(this.eventBus=new Zn,this.store=new jn(c),this.layoutEngine=new ns,this.timeScale=this.createTimeScale(c),this.canvasRenderer=new gi(this.timelinePanel),this.treeGrid=new pi(this.gridPanel),this.scrollManager=new mi(this.timelinePanel,(h,p)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y:p})}),this.dependencyRenderer=new cs,this.tooltipManager=new us(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new bi(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:p=>this.timeScale.dateToX(p),xToDate:p=>this.timeScale.xToDate(p),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:p=>this.store.dispatch(p),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:p=>{this.eventBus.emit("taskClick",p)},onTaskDblClick:p=>{this.eventBus.emit("taskDblClick",p)},onHover:(p,r,d,g)=>{var b;p?this.tooltipManager.show(p,r,d,g):this.tooltipManager.hide();try{(b=n.onHover)==null||b.call(n,p,r,d,g)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(p,r)=>this.scrollManager.setScrollPosition(p,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,p)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:p.ctrlKey||p.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){at("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){at("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(at("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const u=qn(this.store.getState(),t);for(const c of u)this.store.dispatch(c);at("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=qn(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,l=0;for(const u of n){let c=null;if(u.type==="UPDATE_TASK"?c=u.taskId:u.type==="ADD_TASK"?c=u.task.id:u.type==="REMOVE_TASK"&&(c=u.taskId),c&&typeof s=="number"){const h=this.lastAppliedTs.get(c);if(h!==void 0&&s<h){l++;continue}}this.store.dispatch(u),c&&typeof s=="number"&&this.lastAppliedTs.set(c,s),u.type==="UPDATE_TASK"?o++:u.type==="ADD_TASK"?i++:u.type==="REMOVE_TASK"&&a++}l>0&&at("remote:dropped-stale",{kind:t.kind,count:l}),o+i+a>0&&at("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const u=n.tasks.get(t);u&&this.scrollToDate(u.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.store.getState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const u=l.getContext("2d");u&&this.dependencyRenderer.render(u,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const u=this.timelinePanel.querySelector("canvas");if(u){const c=u.getContext("2d");c&&l.renderCanvas(c,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new es(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:t=>this.store.dispatch(t),on:(t,n)=>this.eventBus.on(t,n),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:t=>this.timeScale.dateToX(t),xToDate:t=>this.timeScale.xToDate(t),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const t=this.store.getState(),{tree:n,flatIds:s}=xe(t.tasks,t.expandedIds);t.tree=n,t.flatVisibleIds.length=0;for(const o of s)t.flatVisibleIds.push(o)}}}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new jn(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function ps(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function ms(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of ps(a)){let u=s.get(l);u||(u=[],s.set(l,u)),u.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const u of l)o.has(u)||(o.add(u),i.push(u))}return o}function Li(e,t){const n=ms(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const Ri=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function dn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Pi(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,u=null;function c(d){s.push(d),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const d=dn(n.getState()),g=s.pop();o.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function p(){if(!n||o.length===0)return;const d=dn(n.getState()),g=o.pop();s.push(d),i=!0,n.dispatch({type:"SET_DATA",tasks:g.tasks,dependencies:g.dependencies}),i=!1}function r(d){(d.ctrlKey||d.metaKey)&&(d.key==="z"||d.key==="Z")&&(d.shiftKey?(d.preventDefault(),p()):(d.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(d){n=d,u=d.on("render",()=>{if(l)return;const g=document.querySelector(".nimbus-gantt");g&&(l=g.parentElement??g,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(d,g){if(i){g(d);return}if(Ri.has(d.type)&&n){const b=dn(n.getState());c(b),o=[]}g(d)},destroy(){a&&l&&l.removeEventListener("keydown",a),u&&u(),n=null,l=null,a=null,s=[],o=[]}}}const mt=["day","week","month","quarter"];function _i(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function un(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function $i(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,u=_i(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c>0&&e.dispatch({type:"SELECT_TASK",taskId:l[c-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!u)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const c=l.indexOf(u);c<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[c+1]})}break}case"ArrowRight":{if(u)if(un(u,a))if(!a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+c})}break}case"ArrowLeft":{if(u)if(un(u,a))if(a.expandedIds.has(u))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u});else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}else{const c=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-c)})}break}case"Enter":{if(!u)return;i.preventDefault();const c=a.tasks.get(u);if(c&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:c,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(u);if(h&&n){const p=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(p)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const c=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:c})}break}case"+":case"=":{i.preventDefault();const c=mt.indexOf(a.zoomLevel);c>0&&e.dispatch({type:"SET_ZOOM",level:mt[c-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const c=mt.indexOf(a.zoomLevel);c<mt.length-1&&e.dispatch({type:"SET_ZOOM",level:mt[c+1]});break}case" ":{if(!u)return;const c=i.target;if(c.tagName==="INPUT"||c.tagName==="TEXTAREA"||c.tagName==="BUTTON")return;un(u,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:u}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const ys="#D4A017",Oi="rgba(212, 160, 23, 0.25)",Ni=[6,4],xi=1,Hi=2,Bi=4,Ts=8,bs=10,vs=16,Fi=6;function Yi(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,u=o.headerHeight,c=s.filter(r=>r.isMilestone);if(c.length===0)return;t.save();const h=u,p=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),p),t.clip(),t.translate(-i,0);for(const r of c){const d=r.x,g=r.barY-a,b=r.barHeight,T=g+b/2,f=r.color===l.barDefaultColor?ys:r.color||ys;t.save(),t.beginPath(),t.strokeStyle=Oi,t.lineWidth=xi,t.setLineDash(Ni),t.moveTo(d,h),t.lineTo(d,h+p),t.stroke(),t.setLineDash([]),t.restore();const y=(b-Hi*2)/2;t.save(),t.beginPath(),t.moveTo(d,T-y),t.lineTo(d+y,T),t.lineTo(d,T+y),t.lineTo(d-y,T),t.closePath(),t.fillStyle=f,t.fill(),t.strokeStyle=ws(f,.25),t.lineWidth=1,t.stroke(),t.restore();const v=d+y+Bi,m=T-vs/2;if(t.save(),t.beginPath(),t.strokeStyle=ws(f,.15),t.lineWidth=1.5,t.moveTo(v,m),t.lineTo(v,m+vs),t.stroke(),t.beginPath(),t.moveTo(v,m),t.lineTo(v+Ts,m+bs/2),t.lineTo(v,m+bs),t.closePath(),t.fillStyle=f,t.fill(),t.restore(),r.label){const S=v+Ts+Fi,k=T;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,S,k),t.restore()}}t.restore()},destroy(){e=null}}}function ws(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Ui="rgba(100, 116, 139, 0.12)",Wi="rgba(100, 116, 139, 0.25)",Ss="#334155",Xi="rgba(100, 116, 139, 0.2)",zi="#475569",Gi=8,Vi=6,Ki=2,ze=5,ji=12,qi=28,Zi=8;function Ji(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function u(h){const p=new Map,r=[];for(const d of h.flatVisibleIds){const g=h.tasks.get(d);if(g)if(g.groupId){let b=p.get(g.groupId);b||(b={groupId:g.groupId,groupName:g.groupName||g.groupId,taskIds:[],collapsed:t.has(g.groupId)},p.set(g.groupId,b)),b.taskIds.push(d)}else r.push(d)}n=Array.from(p.values()),o=[],s=new Map;for(const d of r)o.push(d);for(const d of n){const g=o.length,b=`__group_header__${d.groupId}`;if(o.push(b),s.set(g,d),!d.collapsed)for(const T of d.taskIds)o.push(T)}}function c(h){if(t.has(h)?t.delete(h):t.add(h),e){const p=e.getState();e.dispatch({type:"SET_SCROLL",x:p.scrollX,y:p.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const p=document.querySelector(".nimbus-gantt");p&&(a=p.parentElement??p,i=r=>{if(!e)return;const d=e.getState(),g=p.querySelector(".ng-timeline-panel");if(!g)return;const b=g.getBoundingClientRect(),T=r.clientY-b.top,f=d.config.headerHeight;if(T<f)return;const y=T-f+d.scrollY,v=Math.floor(y/d.config.rowHeight),m=s.get(v);m&&(r.preventDefault(),r.stopPropagation(),c(m.groupId))},a.addEventListener("click",i))})},middleware(h,p){if(p(h),!e)return;const r=e.getState();let d=!1;for(const g of r.tasks.values())if(g.groupId){d=!0;break}if(!d){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(u(r),t.size>0){const g=new Set;for(const b of n)if(b.collapsed)for(const T of b.taskIds)g.add(T);if(g.size>0){const b=r.flatVisibleIds.filter(T=>!g.has(T));if(b.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const T of b)r.flatVisibleIds.push(T)}}}},renderCanvas(h,p,r){if(!e||n.length===0)return;const{config:d,scrollX:g,scrollY:b}=p,{theme:T}=d,f=d.headerHeight,y=d.rowHeight,v=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-f;h.save(),h.beginPath(),h.rect(0,f,v,m),h.clip();let S=0;const k=[];for(const w of p.flatVisibleIds){const D=p.tasks.get(w);D&&!D.groupId&&k.push(w)}S=k.length;for(const w of n){const D=f+S*y-b;if(D+y>=f&&D<f+m){h.fillStyle=Ui,h.fillRect(0,D,v,y),h.beginPath(),h.strokeStyle=Wi,h.lineWidth=1,h.moveTo(0,Math.round(D+y)+.5),h.lineTo(v,Math.round(D+y)+.5),h.stroke();const E=ji,I=D+y/2;h.save(),h.beginPath(),h.fillStyle=Ss,w.collapsed?(h.moveTo(E,I-ze),h.lineTo(E+ze,I),h.lineTo(E,I+ze)):(h.moveTo(E-ze/2,I-ze/2),h.lineTo(E+ze/2,I-ze/2),h.lineTo(E,I+ze/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${T.fontSize}px ${T.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=Ss;const M=qi,R=D+y/2;h.fillText(w.groupName,M,R);const _=h.measureText(w.groupName).width;h.restore();const H=`${w.taskIds.length}`;h.save(),h.font=`${T.fontSize-1}px ${T.fontFamily}`;const P=h.measureText(H).width+Vi*2,B=T.fontSize+Ki*2,W=M+_+Zi,K=R-B/2;h.beginPath();const q=Gi;h.moveTo(W+q,K),h.lineTo(W+P-q,K),h.arcTo(W+P,K,W+P,K+q,q),h.lineTo(W+P,K+B-q),h.arcTo(W+P,K+B,W+P-q,K+B,q),h.lineTo(W+q,K+B),h.arcTo(W,K+B,W,K+B-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=Xi,h.fill(),h.fillStyle=zi,h.textBaseline="middle",h.textAlign="center",h.fillText(H,W+P/2,R),h.restore()}S+=1,w.collapsed||(S+=w.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const rt="__bucket_header__";function Es(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Qi(e){return e.groupId??null}function ea(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function ta(e){const t=[...e.buckets].sort((r,d)=>r.order-d.order),n=new Map;t.forEach((r,d)=>n.set(r.id,d));const s=e.getBucket??Qi,o=e.getBucketProgress??ea,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],u=null;function c(r,d){l=t.map(g=>({config:g,taskIds:[],allTaskIds:[],collapsed:i.has(g.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const g of d){const b=r.tasks.get(g);if(!b)continue;const T=s(b);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].taskIds.push(g)}for(const[g,b]of r.tasks){if(g.startsWith(rt))continue;const T=s(b);if(!T)continue;const f=n.get(T);f!==void 0&&l[f].allTaskIds.push(g)}for(const g of l){if(g.allTaskIds.length===0){g.progress=0,g.startDate=null,g.endDate=null,g.totalHours=0,g.totalLogged=0;continue}const b=[];let T=1/0,f=-1/0,y=0,v=0;for(const m of g.allTaskIds){const S=r.tasks.get(m);if(!S)continue;if(b.push(S),S.startDate){const w=ht(S.startDate).getTime();!isNaN(w)&&w<T&&(T=w)}if(S.endDate){const w=ht(S.endDate).getTime();!isNaN(w)&&w>f&&(f=w)}const k=S.metadata;typeof(k==null?void 0:k.hoursHigh)=="number"&&(y+=k.hoursHigh),typeof(k==null?void 0:k.hoursLogged)=="number"&&(v+=k.hoursLogged)}g.startDate=isFinite(T)?new Date(T):null,g.endDate=isFinite(f)?new Date(f):null,g.totalHours=y,g.totalLogged=v,g.progress=Math.max(0,Math.min(1,o(b)))}}function h(r){if(!r.startDate||!r.endDate)return null;const d=r.totalHours>0&&r.totalLogged>=r.totalHours,g=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),b=r.totalHours>0?`${r.totalHours}h (${g}% budget)`:`${r.allTaskIds.length} items`;return{id:`${rt}${r.config.id}`,name:b,startDate:Es(r.startDate),endDate:Es(r.endDate),progress:r.progress,color:d?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function p(r){if(i.has(r)?i.delete(r):i.add(r),a){const d=a.getState();a.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,u=r.on("taskClick",((...d)=>{const g=d[0];let b=null;typeof g=="string"?b=g:g&&typeof g=="object"&&"id"in g&&(b=String(g.id)),b&&b.startsWith(rt)&&p(b.substring(rt.length))}))},middleware(r,d){if(d(r),!a)return;const g=a.getState(),b=[];for(const y of g.tasks.keys())y.startsWith(rt)&&b.push(y);for(const y of b)g.tasks.delete(y);const T=g.flatVisibleIds.filter(y=>!y.startsWith(rt));let f=!1;for(const y of g.tasks.values())if(s(y)!=null){f=!0;break}if(!f){if(l=[],T.length!==g.flatVisibleIds.length){g.flatVisibleIds.length=0;for(const y of T)g.flatVisibleIds.push(y)}return}c(g,T);for(const y of l){if(y.allTaskIds.length===0)continue;const v=h(y);if(v){g.tasks.set(v.id,v);for(const m of y.allTaskIds){const S=g.tasks.get(m);S&&(S.parentId=v.id)}y.collapsed?g.expandedIds.delete(v.id):g.expandedIds.add(v.id)}}a.rebuildTree()},destroy(){u&&u(),a=null,l=[],u=null,i.clear()}}}const na=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function sa(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Ds=864e5,oa=6,ia=2,aa=2,ra=.18,la=.4;function ks(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function gn(e,t){return Math.round((t.getTime()-e.getTime())/Ds)}function lt(e,t){return new Date(e.getTime()+t*Ds)}function hn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const E of n)s.set(E,[]),o.set(E,[]),i.set(E,0);for(const E of t.values()){if((E.type||"FS")!=="FS"||!e.has(E.source)||!e.has(E.target))continue;const M=E.lag||0;s.get(E.source).push({target:E.target,lag:M,depId:E.id}),o.get(E.target).push({source:E.source,lag:M,depId:E.id}),i.set(E.target,(i.get(E.target)||0)+1)}const a=new Map,l=new Map,u=new Map;for(const[E,I]of e){const M=ks(I.startDate),R=ks(I.endDate);l.set(E,M),u.set(E,R),a.set(E,Math.max(gn(M,R),0))}const c=new Map,h=new Map,p=[],r=[],d=new Map(i);for(const E of n)d.get(E)===0&&(r.push(E),c.set(E,l.get(E)),h.set(E,u.get(E)));for(;r.length>0;){const E=r.shift();p.push(E),c.get(E);const I=h.get(E);for(const M of s.get(E)){const{target:R,lag:_}=M,H=lt(I,_),N=c.get(R);(!N||H.getTime()>N.getTime())&&(c.set(R,H),h.set(R,lt(H,a.get(R))));const P=d.get(R)-1;d.set(R,P),P===0&&r.push(R)}}for(const E of n)c.has(E)||(c.set(E,l.get(E)),h.set(E,u.get(E)),p.push(E));let g=-1/0;for(const E of h.values())E.getTime()>g&&(g=E.getTime());const b=new Date(g);let T=1/0;for(const E of c.values())E.getTime()<T&&(T=E.getTime());const f=new Date(T),y=gn(f,b),v=new Map,m=new Map;for(const E of n)s.get(E).length===0&&(m.set(E,b),v.set(E,lt(b,-a.get(E))));for(let E=p.length-1;E>=0;E--){const I=p[E];if(!m.has(I)){let M=1/0;for(const R of s.get(I)){const _=v.get(R.target);if(_){const H=lt(_,-R.lag);H.getTime()<M&&(M=H.getTime())}}M===1/0?m.set(I,b):m.set(I,new Date(M)),v.set(I,lt(m.get(I),-a.get(I)))}}for(const E of n)m.has(E)||(m.set(E,b),v.set(E,lt(b,-a.get(E))));const S=.5,k=new Set,w=new Map;for(const E of n){const I=c.get(E),M=h.get(E),R=v.get(E),_=m.get(E),H=gn(I,R),N=Math.abs(H)<S;N&&k.add(E),w.set(E,{earlyStart:I,earlyFinish:M,lateStart:R,lateFinish:_,totalFloat:H,isCritical:N})}const D=new Set;for(const E of t.values())(E.type||"FS")==="FS"&&k.has(E.source)&&k.has(E.target)&&D.add(E.id);return{criticalTaskIds:k,criticalDependencyIds:D,taskAnalysis:w,projectDuration:y}}function ca(){let e,t=null,n=[];function s(){const o=e.getState();t=hn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:u,rowHeight:c,barHeight:h}=i.config,p=l.criticalPathColor||"#E53E3E",r=i.scrollX,d=i.scrollY,g=u,b=e.getTimeScale(),T=new Map;for(const m of a)T.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,g,o.canvas.width,o.canvas.height-g),o.clip(),o.translate(-r,0);for(const m of a){const S=t.taskAnalysis.get(m.taskId);if(!S||S.isCritical||S.totalFloat<=0)continue;const k=m.barY-d,w=h*la,D=m.x+m.width,I=b.dateToX(S.lateFinish)-D;I>1&&(o.fillStyle=m.color,o.globalAlpha=ra,o.fillRect(D,k+h-w,I,w),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const S=m.x,k=m.barY-d,w=m.width,D=m.barHeight;if(!(k+D<g||k>o.canvas.height)){o.save(),o.shadowColor=p,o.shadowBlur=oa;for(let E=0;E<ia;E++){o.strokeStyle=p,o.lineWidth=aa,o.beginPath();const I=l.barBorderRadius,M=Math.min(I,w/2,D/2);o.moveTo(S+M,k),o.lineTo(S+w-M,k),o.arcTo(S+w,k,S+w,k+M,M),o.lineTo(S+w,k+D-M),o.arcTo(S+w,k+D,S+w-M,k+D,M),o.lineTo(S+M,k+D),o.arcTo(S,k+D,S,k+D-M,M),o.lineTo(S,k+M),o.arcTo(S,k,S+M,k,M),o.closePath(),o.stroke()}o.restore()}}const f=6,y=4,v=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const S=T.get(m.source),k=T.get(m.target);if(!S||!k)continue;const w=S.x+S.width,D=S.barY+S.barHeight/2-d,E=k.x,I=k.barY+k.barHeight/2-d;o.beginPath(),o.strokeStyle=p,o.lineWidth=l.dependencyWidth+1;const M=w+v,R=E-v;if(o.moveTo(w,D),R>=M)o.lineTo(M,D),o.lineTo(M,I),o.lineTo(E,I);else{const _=(D+I)/2;o.lineTo(M,D),o.lineTo(M,_),o.lineTo(R,_),o.lineTo(R,I),o.lineTo(E,I)}o.stroke(),o.beginPath(),o.moveTo(E,I),o.lineTo(E-f,I-y),o.lineTo(E-f,I+y),o.closePath(),o.fillStyle=p,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const da=864e5,ua=.6,Cs=.25,ga="#38A169",ha="#E53E3E",fa="#A0AEC0",pa=10,ma=4,Ge=16,ya=3;function _t(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ta(e,t){return Math.round((t.getTime()-e.getTime())/da)}function ba(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:_t(s.startDate),end:_t(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var b,T;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:u}=o.config,c=o.scrollX,h=o.scrollY,p=l,r=n.getTimeScale(),d=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,p,s.canvas.width,s.canvas.height-p),s.clip(),s.translate(-c,0);const g=u*ua;for(const f of i){if(f.isMilestone)continue;const y=t.get(f.taskId);if(!y)continue;const v=f.barY-h;if(v+u+g<p||v>s.canvas.height)continue;const m=r.dateToX(y.start),S=r.dateToX(y.end),k=Math.max(S-m,2),w=v+u+1;_t(((b=o.tasks.get(f.taskId))==null?void 0:b.startDate)||"");const D=_t(((T=o.tasks.get(f.taskId))==null?void 0:T.endDate)||""),E=Ta(y.end,D);let I;E<0?I=ga:E>0?I=ha:I=fa,s.save(),s.globalAlpha=Cs,s.fillStyle=I;const M=Math.min(d,k/2,g/2);if(s.beginPath(),s.moveTo(m+M,w),s.lineTo(m+k-M,w),s.arcTo(m+k,w,m+k,w+M,M),s.lineTo(m+k,w+g-M),s.arcTo(m+k,w+g,m+k-M,w+g,M),s.lineTo(m+M,w+g),s.arcTo(m,w+g,m,w+g-M,M),s.lineTo(m,w+M),s.arcTo(m,w,m+M,w,M),s.closePath(),s.fill(),s.globalAlpha=Cs*2,s.strokeStyle=I,s.lineWidth=1,s.stroke(),s.restore(),E!==0){const R=E>0?`+${E}d`:`${E}d`;s.save(),s.font=`600 ${pa}px ${a.fontFamily}`;const N=s.measureText(R).width+ma*2,P=f.x+f.width+4,B=w+(g-Ge)/2;s.globalAlpha=.85,s.fillStyle=I;const W=ya;s.beginPath(),s.moveTo(P+W,B),s.lineTo(P+N-W,B),s.arcTo(P+N,B,P+N,B+W,W),s.lineTo(P+N,B+Ge-W),s.arcTo(P+N,B+Ge,P+N-W,B+Ge,W),s.lineTo(P+W,B+Ge),s.arcTo(P,B+Ge,P,B+Ge-W,W),s.lineTo(P,B+W),s.arcTo(P,B,P+W,B,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(R,P+N/2,B+Ge/2),s.restore()}}s.restore()},destroy(){}}}const Is=5,va=5,wa=.3,Sa=15;function Ea(){let e,t=null,n=0,s=0;const o=[];function i(c){const{rowHeight:h,headerHeight:p}=c.config,r=c.scrollY,d=c.flatVisibleIds.length,g=a(c),b=Math.floor(r/h),T=Math.ceil((r+g)/h);let f=Math.max(0,b-Is),y=Math.min(d,T+Is);if(Math.abs(s)>0){const m=Math.min(Sa,Math.ceil(Math.abs(s*wa)/h));s>0?y=Math.min(d,y+m):f=Math.max(0,f-m)}const v=new Set;for(let m=f;m<y&&m<c.flatVisibleIds.length;m++)v.add(c.flatVisibleIds[m]);return{startRow:f,endRow:y,totalRows:d,visibleTaskIds:v}}function a(c){const p=c.flatVisibleIds.length*c.config.rowHeight-c.scrollY;return Math.min(800,Math.max(p,200))}function l(c){const h=performance.now();for(o.push({y:c,time:h});o.length>va;)o.shift();if(o.length>=2){const p=o[0],r=o[o.length-1],d=(r.time-p.time)/1e3;d>0&&(s=(r.y-p.y)/d)}n=c}const u={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const c=e.getState();return(!t||c.scrollY!==n)&&(l(c.scrollY),t=i(c)),t},filterLayouts(c){const h=u.getVisibleRange();return h.totalRows===0?[]:c.filter(p=>h.visibleTaskIds.has(p.taskId))},isVisible(c){return u.getVisibleRange().visibleTaskIds.has(c)},getContentHeight(){if(!e)return 0;const c=e.getState();return c.flatVisibleIds.length*c.config.rowHeight+c.config.headerHeight}};return{name:"VirtualScrollPlugin",install(c){e=c},middleware(c,h){if(h(c),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(c.type)&&(t=null,c.type==="SET_SCROLL"||c.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:u}}const He=864e5,fn=1,Ms=2,As=.5,Ls=2,$t=8,Rs=6,Ps=2,Ot=1e4;function pn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function _s(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function et(e){return Math.round(e)+.5}function $s(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Os(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,u=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,u),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let c=0;for(const p of a){const r=p.width??120;e.save(),e.beginPath(),e.rect(c,0,r,u),e.clip(),e.textAlign=p.align==="right"?"right":p.align==="center"?"center":"left";const d=p.align==="right"?c+r-8:p.align==="center"?c+r/2:c+8;e.fillText(p.header,d,u/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(c+r,0),e.lineTo(c+r,s),e.stroke(),c+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,u),e.lineTo(n,u),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let p=0;p<h.length;p++){const r=t.tasks.get(h[p]);if(!r)continue;const d=u+p*l;p%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,d,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,d+l),e.lineTo(n,d+l),e.stroke();let g=0;e.fillStyle=i.gridTextColor;for(const b of a){const T=b.width??120,f=$s(r,b.field);e.save(),e.beginPath(),e.rect(g,d,T,l),e.clip(),e.textBaseline="middle";const y=b.tree?8:0;e.textAlign=b.align==="right"?"right":b.align==="center"?"center":"left";const v=b.align==="right"?g+T-8:b.align==="center"?g+T/2:g+8+y;e.fillText(f,v,d+l/2),e.restore(),g+=T}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function Ns(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,u=i.rowHeight,c=s.getTotalWidth(),h=t.flatVisibleIds.length*u,p=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,c,p),i.showWeekends){const{start:g,end:b}=t.dateRange,T=new Date(g);T.setUTCHours(0,0,0,0);const f=b.getTime();for(;T.getTime()<=f;){const y=T.getUTCDay();if(y===0||y===6){const v=o+s.dateToX(T),m=new Date(T.getTime()+He),S=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(v,l,S-v,h)}T.setTime(T.getTime()+He)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=As;for(const g of r){const b=et(o+g);e.moveTo(b,l),e.lineTo(b,p)}e.stroke();for(let g=0;g<t.flatVisibleIds.length;g++)g%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+g*u,c,u));if(i.showToday){const g=new Date;g.setHours(0,0,0,0);const{start:b,end:T}=t.dateRange;if(g.getTime()>=b.getTime()&&g.getTime()<=T.getTime()){const f=o+s.dateToX(g),y=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(f,l,y,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Ms,e.moveTo(et(f),l),e.lineTo(et(f),p),e.stroke()}}const d=a.barBorderRadius;for(const g of n){const b=o+g.x,T=g.barY,f=g.width,y=g.barHeight;if(g.isMilestone){const v=(y-Ls*2)/2,m=T+y/2;e.beginPath(),e.moveTo(b,m-v),e.lineTo(b+v,m),e.lineTo(b,m+v),e.lineTo(b-v,m),e.closePath(),e.fillStyle=g.color,e.fill();continue}if(mn(e,b,T,f,y,d),e.fillStyle=g.color,e.fill(),i.showProgress&&g.progressWidth>0){const v=_s(g.color,.2);e.save(),e.beginPath(),mn(e,b,T,f,y,d),e.clip(),e.fillStyle=v,e.fillRect(b,T,g.progressWidth,y),e.restore()}if(t.selectedIds.has(g.taskId)&&(e.beginPath(),mn(e,b,T,f,y,d),e.strokeStyle=a.barSelectedBorder,e.lineWidth=Ps,e.stroke()),g.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const v=e.measureText(g.label).width,m=T+y/2;v+$t*2<=f?(e.beginPath(),e.rect(b,T,f,y),e.clip(),e.fillStyle=g.textColor,e.textAlign="left",e.fillText(g.label,b+$t,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(g.label,b+f+Rs,m)),e.restore()}}Da(e,t,n,a,o),ka(e,s,i,a,o)}function Da(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const c of n)i.set(c.taskId,c);const a=12,l=6,u=4;e.save();for(const c of t.dependencies.values()){const h=i.get(c.source),p=i.get(c.target);if(!h||!p)continue;const r=c.type||"FS",d=h.barY+h.barHeight/2,g=p.barY+p.barHeight/2;let b,T;const f=r==="FS"||r==="FF",y=r==="FS"||r==="SS";switch(r){case"FS":b=o+h.x+h.width,T=o+p.x;break;case"SS":b=o+h.x,T=o+p.x;break;case"FF":b=o+h.x+h.width,T=o+p.x+p.width;break;case"SF":b=o+h.x,T=o+p.x+p.width;break}const v=f?b+a:b-a,m=y?T-a:T+a,S=f?y?m>=v:T+a>=v:y?T-a<=v:m<=v;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(b,d),S)e.lineTo(v,d),e.lineTo(v,g),e.lineTo(T,g);else{const k=(d+g)/2;e.lineTo(v,d),e.lineTo(v,k),e.lineTo(m,k),e.lineTo(m,g),e.lineTo(T,g)}e.stroke(),e.beginPath(),y?(e.moveTo(T,g),e.lineTo(T-l,g-u),e.lineTo(T-l,g+u)):(e.moveTo(T,g),e.lineTo(T+l,g-u),e.lineTo(T+l,g+u)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function ka(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,u=i/l;e.textBaseline="middle";for(let c=0;c<a.length;c++){const h=a[c],p=c*u;for(const r of h){const d=o+r.x,g=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=fn,e.moveTo(et(d+g),p),e.lineTo(et(d+g),p+u),e.stroke(),e.save(),e.beginPath(),e.rect(d,p,g,u),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,d+g/2,p+u/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=fn,e.moveTo(o,et(i)),e.lineTo(o+t.getTotalWidth(),et(i)),e.stroke()}function mn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function yt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Ca(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,u=n.getTotalWidth(),c=s+u,h=e.flatVisibleIds.length*l,p=a+h,r=i.barBorderRadius,d=[];d.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${c}" height="${p}" viewBox="0 0 ${c} ${p}">`),d.push(`<style>text { font-family: ${yt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),d.push(`<rect x="0" y="0" width="${s}" height="${p}" fill="${i.gridBg}" />`),d.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let g=0;for(const m of o.columns){const S=m.width??120;d.push(`<text x="${g+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${yt(m.header)}</text>`),d.push(`<line x1="${g+S}" y1="0" x2="${g+S}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),g+=S}for(let m=0;m<e.flatVisibleIds.length;m++){const S=e.tasks.get(e.flatVisibleIds[m]);if(!S)continue;const k=a+m*l;m%2===1&&d.push(`<rect x="0" y="${k}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let w=0;for(const D of o.columns){const E=D.width??120,I=$s(S,D.field),M=D.tree?8:0;d.push(`<text x="${w+8+M}" y="${k+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${I}]]></text>`),w+=E}d.push(`<line x1="0" y1="${k+l}" x2="${s}" y2="${k+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}d.push(`<line x1="${s}" y1="0" x2="${s}" y2="${p}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<line x1="0" y1="${a}" x2="${c}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${p}" fill="${i.timelineBg}" />`),d.push(`<rect x="${s}" y="0" width="${u}" height="${a}" fill="${i.timelineHeaderBg}" />`);const b=n.getHeaderRows(),T=b.length||2,f=a/T;for(let m=0;m<b.length;m++){const S=b[m],k=m*f;for(const w of S){const D=s+w.x+w.width/2,E=k+f/2,I=m===0?' font-weight="600"':"";d.push(`<text x="${D}" y="${E}" text-anchor="middle" dominant-baseline="central"${I} fill="${i.timelineHeaderText}">${yt(w.label)}</text>`),d.push(`<line x1="${s+w.x+w.width}" y1="${k}" x2="${s+w.x+w.width}" y2="${k+f}" stroke="${i.timelineGridColor}" stroke-width="${fn}" />`)}}const y=n.getGridLines();for(const m of y)d.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${p}" stroke="${i.timelineGridColor}" stroke-width="${As}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&d.push(`<rect x="${s}" y="${a+m*l}" width="${u}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:S}=e.dateRange,k=new Date(m);for(k.setUTCHours(0,0,0,0);k.getTime()<=S.getTime();){if(k.getUTCDay()===0||k.getUTCDay()===6){const w=s+n.dateToX(k),D=new Date(k.getTime()+He),E=s+n.dateToX(D);d.push(`<rect x="${w}" y="${a}" width="${E-w}" height="${h}" fill="${i.timelineWeekendBg}" />`)}k.setTime(k.getTime()+He)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:S,end:k}=e.dateRange;if(m.getTime()>=S.getTime()&&m.getTime()<=k.getTime()){const w=s+n.dateToX(m),D=n.getColumnWidth();d.push(`<rect x="${w}" y="${a}" width="${D}" height="${h}" fill="${i.todayBg}" />`),d.push(`<line x1="${w}" y1="${a}" x2="${w}" y2="${p}" stroke="${i.todayLineColor}" stroke-width="${Ms}" />`)}}for(const m of t){const S=s+m.x,k=m.barY,w=m.width,D=m.barHeight;if(m.isMilestone){const E=(D-Ls*2)/2,I=k+D/2;d.push(`<polygon points="${S},${I-E} ${S+E},${I} ${S},${I+E} ${S-E},${I}" fill="${m.color}" />`);continue}if(d.push(`<rect x="${S}" y="${k}" width="${w}" height="${D}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const E=_s(m.color,.2);d.push(`<clipPath id="clip-${m.taskId}"><rect x="${S}" y="${k}" width="${w}" height="${D}" rx="${r}" ry="${r}" /></clipPath>`),d.push(`<rect x="${S}" y="${k}" width="${m.progressWidth}" height="${D}" fill="${E}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&d.push(`<rect x="${S}" y="${k}" width="${w}" height="${D}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${Ps}" />`),m.label){const E=k+D/2;i.fontSize*.6*m.label.length+$t*2<=w?d.push(`<text x="${S+$t}" y="${E}" dominant-baseline="central" fill="${m.textColor}">${yt(m.label)}</text>`):d.push(`<text x="${S+w+Rs}" y="${E}" dominant-baseline="central" fill="${i.gridTextColor}">${yt(m.label)}</text>`)}}const v=new Map;for(const m of t)v.set(m.taskId,m);for(const m of e.dependencies.values()){const S=v.get(m.source),k=v.get(m.target);if(!S||!k)continue;const w=m.type||"FS",D=S.barY+S.barHeight/2,E=k.barY+k.barHeight/2;let I,M;const R=w==="FS"||w==="FF",_=w==="FS"||w==="SS";switch(w){case"FS":I=s+S.x+S.width,M=s+k.x;break;case"SS":I=s+S.x,M=s+k.x;break;case"FF":I=s+S.x+S.width,M=s+k.x+k.width;break;case"SF":I=s+S.x,M=s+k.x+k.width;break}const H=12,N=6,P=4,B=R?I+H:I-H,W=_?M-H:M+H,K=R?_?W>=B:M+H>=B:_?M-H<=B:W<=B;let q;if(K)q=`M${I},${D} L${B},${D} L${B},${E} L${M},${E}`;else{const U=(D+E)/2;q=`M${I},${D} L${B},${D} L${B},${U} L${W},${U} L${W},${E} L${M},${E}`}d.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),_?d.push(`<polygon points="${M},${E} ${M-N},${E-P} ${M-N},${E+P}" fill="${i.dependencyColor}" />`):d.push(`<polygon points="${M},${E} ${M+N},${E-P} ${M+N},${E+P}" fill="${i.dependencyColor}" />`)}return d.push("</svg>"),d.join(`
`)}function Ia(){let e=null;function t(){const a=e,l=a.getState(),u=a.getTimeScale(),{start:c,end:h}=l.dateRange,p=h.getTime()-c.getTime(),r=u.getColumnWidth(),d=l.zoomLevel;let g;switch(d){case"day":g=Math.round(p/He);break;case"week":g=Math.ceil(p/(He*7));break;case"month":{const T=c.getUTCFullYear(),f=c.getUTCMonth(),y=h.getUTCFullYear(),v=h.getUTCMonth();g=(y-T)*12+(v-f);break}case"quarter":{const T=c.getUTCFullYear(),f=Math.floor(c.getUTCMonth()/3),y=h.getUTCFullYear(),v=Math.floor(h.getUTCMonth()/3);g=(y-T)*4+(v-f);break}}const b=g*r;return{dateToX(T){return(T.getTime()-c.getTime())/p*b},getColumnWidth(){return r},getTotalWidth(){return b},getHeaderRows(){return La(d,c,h,r,b)},getGridLines(){return this.getHeaderRows()[1].map(f=>f.x).filter(f=>f>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const u of a.config.columns)l+=u.width??120;return l}function s(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=u.getTotalWidth(),r=h+p,d=l.flatVisibleIds.length*l.config.rowHeight,g=l.config.headerHeight+d,b=a??"gantt-export.png";if(r>Ot||g>Ot){o(l,c,u,h,r,g,b);return}const T=document.createElement("canvas");T.width=r,T.height=g;const f=T.getContext("2d");f&&(h>0&&Os(f,l,h,g),Ns(f,l,c,u,h),T.toBlob(y=>{y&&pn(y,b)},"image/png"))}function o(a,l,u,c,h,p,r){const d=Math.min(1,Ot/h,Ot/p),g=Math.ceil(h*d),b=Math.ceil(p*d),T=document.createElement("canvas");T.width=g,T.height=b;const f=T.getContext("2d");f&&(f.scale(d,d),c>0&&Os(f,a,c,p),Ns(f,a,l,u,c),T.toBlob(y=>{y&&pn(y,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),u=t(),c=e.getLayouts(),h=n(),p=Ca(l,c,u,h),r=new Blob([p],{type:"image/svg+xml;charset=utf-8"});pn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const xs=["January","February","March","April","May","June","July","August","September","October","November","December"],Hs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Bs(e,t){return new Date(e.getTime()+t*He)}function yn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function Ma(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Aa(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function La(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Aa(l,t,i,o);switch(e){case"day":{const l=[],u=[],c=Math.round(i/He);let h=new Date(t);for(let r=0;r<c;r++)u.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Bs(h,1);let p=new Date(t);for(;p.getTime()<n.getTime();){const r=yn(p),d=a(p),g=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${xs[p.getUTCMonth()]} ${p.getUTCFullYear()}`,x:d,width:g-d,date:new Date(p)}),p=r}return[l,u]}case"week":{const l=[],u=[],c=Math.ceil(i/(He*7));for(let p=0;p<c;p++){const r=Bs(t,p*7);u.push({label:`${Hs[r.getUTCMonth()]} ${r.getUTCDate()}`,x:p*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const p=yn(h),r=h.getTime()<t.getTime()?t:h,d=p.getTime()>n.getTime()?n:p;l.push({label:`${xs[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(d)-a(r),date:new Date(r)}),h=p}return[l,u]}case"month":{const l=[],u=[],c=t.getUTCFullYear(),h=t.getUTCMonth(),p=n.getUTCFullYear(),r=n.getUTCMonth(),d=(p-c)*12+(r-h);let g=new Date(Date.UTC(c,h,1));for(let T=0;T<d;T++)u.push({label:Hs[g.getUTCMonth()],x:T*s,width:s,date:new Date(g)}),g=yn(g);let b=new Date(Date.UTC(c,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,y=T.getTime()>n.getTime()?n:T;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(y)-a(f),date:new Date(f)}),b=T}return[l,u]}case"quarter":{const l=[],u=[],c=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),p=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),d=(p-c)*4+(r-h);let g=new Date(Date.UTC(c,h*3,1));for(let T=0;T<d;T++){const f=Math.floor(g.getUTCMonth()/3)+1;u.push({label:`Q${f}`,x:T*s,width:s,date:new Date(g)}),g=Ma(g,3)}let b=new Date(Date.UTC(c,0,1));for(;b.getTime()<n.getTime();){const T=new Date(Date.UTC(b.getUTCFullYear()+1,0,1)),f=b.getTime()<t.getTime()?t:b,y=T.getTime()>n.getTime()?n:T;l.push({label:String(b.getUTCFullYear()),x:a(f),width:a(y)-a(f),date:new Date(f)}),b=T}return[l,u]}default:return[[],[]]}}const Ra={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},Tn="nimbus-gantt-dark-theme-transition";function Pa(){if(typeof document>"u"||document.getElementById(Tn))return;const e=document.createElement("style");e.id=Tn,e.textContent=`
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
  `,document.head.appendChild(e)}function _a(){if(typeof document>"u")return;const e=document.getElementById(Tn);e&&e.remove()}function $a(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function u(){if(!n||s)return;const d=n.getState();o={...d.config.theme};const g={...d.config.theme,...Ra};Object.assign(d.config.theme,g),s=!0,p()}function c(){if(!n||!s||!o)return;const d=n.getState();Object.assign(d.config.theme,o),s=!1,p()}function h(){s?c():u()}function p(){if(!n)return;const d=n.getState();n.dispatch({type:"SET_SCROLL",x:d.scrollX,y:d.scrollY})}function r(d){d.matches?u():c()}return{name:"DarkThemePlugin",install(d){n=d,Pa(),d.on("theme:toggle",()=>{h()}),d.on("theme:dark",()=>{u()}),d.on("theme:light",()=>{c()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=d.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&u()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const d=n.getState();Object.assign(d.config.theme,o)}_a(),n=null,o=null,i=null,a=null,s=!1}}}const Ae=864e5,Oa=[1,2,3,4,5],Na="rgba(128, 128, 128, 0.06)",xa="rgba(128, 128, 128, 0.04)",Ha="#f87171",Tt=4;function bt(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function $e(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ba(e){const t=new Set((e==null?void 0:e.workDays)??Oa),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const d=$e(r);return t.has(d.getUTCDay())}function i(r){const d=bt(r);return n.has(d)?!1:t.has(r.getUTCDay())}function a(r){let d=$e(r);for(d=new Date(d.getTime()+Ae);!i(d);)d=new Date(d.getTime()+Ae);return bt(d)}function l(r,d){if(d===0)return r;let g=$e(r);const b=d>0?1:-1;let T=Math.abs(d);if(!i(g))for(g=new Date(g.getTime()+b*Ae);!i(g);)g=new Date(g.getTime()+b*Ae);for(;T>0;)g=new Date(g.getTime()+b*Ae),i(g)&&T--;return bt(g)}function u(r,d){const g=$e(r),b=$e(d);if(g.getTime()>b.getTime())return-u(d,r);let T=0,f=new Date(g.getTime());for(;f.getTime()<b.getTime();)i(f)&&T++,f=new Date(f.getTime()+Ae);return T}function c(r,d="forward"){if(o(r))return r;let g=$e(r);const b=d==="forward"?Ae:-Ae;for(let T=0;T<30;T++)if(g=new Date(g.getTime()+b),i(g))return bt(g);return r}function h(r,d){if(r.type==="TASK_MOVE"){const g=c(r.startDate,"forward"),b=c(r.endDate,"backward"),T=$e(b).getTime()<$e(g).getTime()?g:b;d({...r,startDate:g,endDate:T});return}if(r.type==="TASK_RESIZE"){const g=c(r.startDate,"forward"),b=c(r.endDate,"backward"),T=$e(b).getTime()<$e(g).getTime()?g:b;d({...r,startDate:g,endDate:T});return}d(r)}function p(r,d,g){const{config:b}=d,T=b.headerHeight,f=d.flatVisibleIds.length*b.rowHeight,y=s==null?void 0:s.getTimeScale();if(!y||f===0)return;const{start:v,end:m}=d.dateRange,S=d.scrollX,k=d.scrollY;r.save();const w=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(w,0,0,w,0,0),r.beginPath(),r.rect(0,T,r.canvas.width/w,f),r.clip(),r.translate(-S,0);const D=new Date(v);D.setUTCHours(0,0,0,0);const E=m.getTime();for(y.getColumnWidth();D.getTime()<=E;){const I=bt(D),M=n.has(I),R=!t.has(D.getUTCDay());if(M||R){const _=y.dateToX(D),H=new Date(D.getTime()+Ae),P=y.dateToX(H)-_;if(r.fillStyle=Na,r.fillRect(_,T-k,P,f+k),R&&!M){r.save(),r.beginPath(),r.rect(_,T,P,f),r.clip(),r.strokeStyle=xa,r.lineWidth=1;const B=8,W=f;for(let K=-W;K<P+W;K+=B)r.beginPath(),r.moveTo(_+K,T),r.lineTo(_+K+W,T+W),r.stroke();r.restore()}}if(M){const _=y.dateToX(D),H=new Date(D.getTime()+Ae),N=y.dateToX(H),P=(_+N)/2;r.save(),r.setTransform(w,0,0,w,0,0),r.translate(-S,0);const B=T-Tt-3;r.beginPath(),r.moveTo(P,B-Tt),r.lineTo(P+Tt,B),r.lineTo(P,B+Tt),r.lineTo(P-Tt,B),r.closePath(),r.fillStyle=Ha,r.fill(),r.restore()}D.setTime(D.getTime()+Ae)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...d)=>{const g=d[0],b=d[1],T=d[2],f=l(g,b);T&&T(f)}),r.on("calendar:workDaysBetween",(...d)=>{const g=d[0],b=d[1],T=d[2],f=u(g,b);T&&T(f)}),r.on("calendar:isWorkDay",(...d)=>{const g=d[0],b=d[1],T=o(g);b&&b(T)}),r.on("calendar:nextWorkDay",(...d)=>{const g=d[0],b=d[1],T=a(g);b&&b(T)})},middleware:h,renderCanvas:p,destroy(){s=null}}}function Fa(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Ya(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function Ua(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=Fa(),a=[],l=Date.now();let u=null,c=null,h=!1,p=[];const r=[];function d(m,S){if(h)return;const k={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:S};a.push(k),o&&o(k)}function g(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function b(){c===null&&(c=setInterval(()=>{g()},s))}function T(){c!==null&&(clearInterval(c),c=null)}const f=Ya(()=>{if(!u)return;const m=u.getState();d("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let y=0;function v(m,S){switch(m.type){case"SET_ZOOM":{const k=u?u.getState().zoomLevel:"unknown";S(m),d("gantt.zoom",{oldLevel:k,newLevel:m.level});return}case"TASK_MOVE":{const k=y>0?Date.now()-y:0;S(m),d("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:k}),y=0;return}case"TASK_RESIZE":{S(m),d("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{y=Date.now(),S(m);return}case"SELECT_TASK":{S(m),d("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{S(m),f();return}case"TOGGLE_EXPAND":{const k=u?u.getState().expandedIds.has(m.taskId):!1;S(m),d(k?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{S(m),d("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{S(m),d("gantt.collapse",{all:!0});return}default:S(m);return}}return{name:"TelemetryPlugin",install(m){u=m,b();const S=m.getState();d("gantt.init",{taskCount:S.tasks.size,dependencyCount:S.dependencies.size,zoomLevel:S.zoomLevel}),setTimeout(()=>{h||d("gantt.feature.used",{plugins:p})},0);const k=m.on("taskClick",(...w)=>{const D=w[0];D&&d("gantt.task.click",{taskId:D.id})});r.push(k)},middleware:v,destroy(){h=!0;const m=Date.now()-l;d("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),g(),T();for(const S of r)S();r.length=0,u=null}}}const Fs=5,bn=.15,vn=.85,Wa=2,Ys=30,Be=["day","week","month","quarter"];function Us(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function Xa(e,t,n){return Math.max(t,Math.min(n,e))}function za(e){const t=Xa((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,u=!1,c=0,h=0,p=0,r=null,d=null,g=null,b=null,T=null,f=null,y=0,v=0,m=0,S=!1;function k(N,P,B){m=N,y=P,v=B,S=!0,r===null&&(r=N)}function w(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(b=N=>{u||N.alpha==null||N.beta==null||N.gamma==null||k(N.alpha,N.beta,N.gamma)},window.addEventListener("deviceorientation",b),!0)}function D(){b&&(window.removeEventListener("deviceorientation",b),b=null)}function E(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function I(N){try{const P=JSON.parse(N);P.type==="orientation"?k(P.alpha,P.beta,P.gamma):P.type==="gesture"&&M(P.gesture)}catch{}}function M(N){if(!l)return;const P=l.getState();switch(N){case"tap":{P.selectedIds.size===0&&P.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:P.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const B=Be.indexOf(P.zoomLevel);B<Be.length-1&&l.dispatch({type:"SET_ZOOM",level:Be[B+1]});break}case"swipe-right":{const B=Be.indexOf(P.zoomLevel);B>0&&l.dispatch({type:"SET_ZOOM",level:Be[B-1]});break}}}function R(){if(u||typeof WebSocket>"u")return;const N=E();try{T=new WebSocket(N),T.onmessage=P=>{typeof P.data=="string"&&I(P.data)},T.onclose=()=>{T=null,u||(f=setTimeout(R,3e3))},T.onerror=()=>{T&&T.close()}}catch{u||(f=setTimeout(R,3e3))}}function _(){f!==null&&(clearTimeout(f),f=null),T&&(T.onmessage=null,T.onclose=null,T.onerror=null,T.close(),T=null)}function H(){if(!(u||!l)){if(S){c=c*vn+y*bn,h=h*vn+v*bn,p=p*vn+m*bn;const N=l.getState(),P=Wa*a;if(n){const B=Us(h,Fs);if(B!==0){const W=B*P,K=Math.max(0,N.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const B=Us(c,Fs);if(B!==0){const W=B*P,K=Math.max(0,N.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(p-r+540)%360-180,K=Be.indexOf(N.zoomLevel);if(W>Ys&&K>0){const q=Be[K-1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}else if(W<-Ys&&K<Be.length-1){const q=Be[K+1];d!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),d=q,r=m)}}}g=requestAnimationFrame(H)}}return{name:"MotionControlPlugin",install(N){l=N,d=N.getState().zoomLevel,(!w()||i)&&R(),g=requestAnimationFrame(H)},destroy(){u=!0,g!==null&&(cancelAnimationFrame(g),g=null),D(),_(),l=null}}}const vt="http://schemas.microsoft.com/project",Ga=8,Ws=4800,Va={0:"FF",1:"FS",2:"SF",3:"SS"},Ka={FF:0,FS:1,SF:2,SS:3};function Xs(e){return e?e.substring(0,10):""}function zs(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(vt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function ja(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function qa(e){return`PT${e*Ga}H0M0S`}function wt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function wn(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(vt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let f=0;f<l.length;f++){const y=l[f],v=Ee(y,"UID"),m=Ee(y,"Name");v&&m&&i.set(v,m)}const u=new Map,c=o.getElementsByTagNameNS(vt,"Assignment"),h=c.length>0?c:o.getElementsByTagName("Assignment");for(let f=0;f<h.length;f++){const y=h[f],v=Ee(y,"TaskUID"),m=Ee(y,"ResourceUID");if(v&&m){const S=i.get(m);S&&u.set(v,S)}}const p=[],r=[],d=o.getElementsByTagNameNS(vt,"Task"),g=d.length>0?d:o.getElementsByTagName("Task"),b=[];let T=1;for(let f=0;f<g.length;f++){const y=g[f],v=Ee(y,"UID"),m=Ee(y,"Name"),S=Ee(y,"Start"),k=Ee(y,"Finish"),w=Ee(y,"PercentComplete"),D=Ee(y,"Summary")==="1",E=Ee(y,"Milestone")==="1",I=parseInt(Ee(y,"OutlineLevel")||"0",10);if(v==="0"&&!m)continue;const M=`msp-${v}`,R=Xs(S),_=Xs(k);if(!R&&!E)continue;let H;I>0&&b[I-1]&&(H=b[I-1]),b[I]=M,b.length=I+1;const N={id:M,name:m||`Task ${v}`,startDate:R||_,endDate:_||R,progress:w?parseInt(w,10)/100:0,isMilestone:E,parentId:H,sortOrder:f},P=u.get(v);P&&(N.assignee=P),D&&(N.metadata={...N.metadata,isSummary:!0}),p.push(N);const B=y.getElementsByTagNameNS(vt,"PredecessorLink"),W=B.length>0?B:y.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],U=Ee(q,"PredecessorUID"),C=parseInt(Ee(q,"Type")||"1",10),$=Ee(q,"LinkLag"),A=$?parseInt($,10):0;if(!U||U==="0")continue;const O={id:`msp-dep-${T++}`,source:`msp-${U}`,target:M,type:Va[C]??"FS",lag:A!==0?A/Ws:void 0};r.push(O)}}return{tasks:p,dependencies:r}}function Sn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function u(v){let m=1,S=v;for(;S!=null&&S.parentId;)m++,S=e.tasks.get(S.parentId);return m}const c=new Map,h=new Map;for(const v of a){const m=v.parentId??"__root__",S=(c.get(m)??0)+1;if(c.set(m,S),!v.parentId)h.set(v.id,String(S));else{const k=h.get(v.parentId)??"0";h.set(v.id,`${k}.${S}`)}}const p=new Set;for(const v of a)v.parentId&&p.add(v.parentId);const r=new Map;a.forEach((v,m)=>{r.set(v.id,m+1)});const d=new Map;for(const v of l){const m=d.get(v.target)??[];m.push(v),d.set(v.target,m)}const g=new Set;for(const v of a)v.assignee&&g.add(v.assignee);const b=Array.from(g),T=new Map;b.forEach((v,m)=>{T.set(v,m+1)});const f=[];f.push('<?xml version="1.0" encoding="UTF-8"?>'),f.push('<Project xmlns="http://schemas.microsoft.com/project">'),f.push(`  <Name>${wt(n)}</Name>`),f.push(`  <Author>${wt(s)}</Author>`),f.push(`  <CreationDate>${o}</CreationDate>`),f.push("  <CalendarUID>1</CalendarUID>"),f.push("  <Calendars>"),f.push("    <Calendar>"),f.push("      <UID>1</UID>"),f.push(`      <Name>${wt(i)}</Name>`),f.push("      <IsBaseCalendar>1</IsBaseCalendar>"),f.push("    </Calendar>"),f.push("  </Calendars>"),f.push("  <Tasks>");for(const v of a){const m=r.get(v.id)??0,S=u(v),k=h.get(v.id)??"1",w=p.has(v.id),D=v.isMilestone??!1,E=zs(v.startDate),I=zs(v.endDate),M=ja(E,I),R=qa(M),_=Math.round((v.progress??0)*100);f.push("    <Task>"),f.push(`      <UID>${m}</UID>`),f.push(`      <ID>${m}</ID>`),f.push(`      <Name>${wt(v.name)}</Name>`),f.push(`      <Start>${v.startDate}T08:00:00</Start>`),f.push(`      <Finish>${v.endDate}T17:00:00</Finish>`),f.push(`      <Duration>${R}</Duration>`),f.push(`      <PercentComplete>${_}</PercentComplete>`),f.push(`      <Summary>${w?"1":"0"}</Summary>`),f.push(`      <Milestone>${D?"1":"0"}</Milestone>`),f.push(`      <OutlineLevel>${S}</OutlineLevel>`),f.push(`      <OutlineNumber>${k}</OutlineNumber>`);const H=d.get(v.id);if(H)for(const N of H){const P=r.get(N.source)??0;if(P===0)continue;const B=Ka[N.type??"FS"]??1,W=Math.round((N.lag??0)*Ws);f.push("      <PredecessorLink>"),f.push(`        <PredecessorUID>${P}</PredecessorUID>`),f.push(`        <Type>${B}</Type>`),f.push(`        <LinkLag>${W}</LinkLag>`),f.push("      </PredecessorLink>")}f.push("    </Task>")}f.push("  </Tasks>"),f.push("  <Resources>");for(const v of b){const m=T.get(v)??0;f.push("    <Resource>"),f.push(`      <UID>${m}</UID>`),f.push(`      <Name>${wt(v)}</Name>`),f.push("    </Resource>")}f.push("  </Resources>"),f.push("  <Assignments>");let y=1;for(const v of a){if(!v.assignee)continue;const m=r.get(v.id)??0,S=T.get(v.assignee)??0;m===0||S===0||(f.push("    <Assignment>"),f.push(`      <UID>${y++}</UID>`),f.push(`      <TaskUID>${m}</TaskUID>`),f.push(`      <ResourceUID>${S}</ResourceUID>`),f.push("    </Assignment>"))}return f.push("  </Assignments>"),f.push("</Project>"),f.join(`
`)}function Za(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var c;const u=(c=l.target)==null?void 0:c.result;if(!(!u||!e))try{const h=wn(u);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=wn(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],u=o.getState(),c=Sn(u,a);l&&l(c)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",u=o.getState(),c=Sn(u,a),h=new Blob([c],{type:"application/xml;charset=utf-8"}),p=URL.createObjectURL(h),r=document.createElement("a");r.href=p,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(p)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const Ja=[4,3],Qa=1.5,er=.5,tr=.06,nr=4,sr=8,or=.35,ir=1,Gs=.2,St=6,Vs=864e5;function Oe(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ks(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function En(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function Dn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function ar(e){let t=0;for(const n of e){const s=Oe(n.startDate).getTime(),o=Oe(n.endDate).getTime();t+=Math.max(o-s,Vs)}return t}function rr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const u=Oe(l.startDate).getTime(),h=Oe(s.startDate).getTime()-u,p=i.segments.map(r=>{const d=new Date(Oe(r.startDate).getTime()+h),g=new Date(Oe(r.endDate).getTime()+h);return{startDate:Ks(d),endDate:Ks(g)}});i.segments=p}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const u=l.startDate,c=l.endDate;if(s.startDate!==u&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==c){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:u}=o,{theme:c,headerHeight:h,barHeight:p}=a,r=n.getTimeScale(),d=c.barBorderRadius,g=h;s.save(),s.beginPath(),s.rect(0,g,s.canvas.width,s.canvas.height-g),s.clip(),s.translate(-l,0);for(const b of i){if(b.isMilestone)continue;const T=t.get(b.taskId);if(!T||T.segments.length===0)continue;const f=b.barY-u,y=b.barHeight,v=f+y/2;if(f+y<g||f>s.canvas.height)continue;const m=[];for(const I of T.segments){const M=r.dateToX(Oe(I.startDate)),R=r.dateToX(Oe(I.endDate)),_=Math.max(R-M,4);m.push({startX:M,endX:M+_,width:_})}s.save(),s.fillStyle=c.timelineBg,s.fillRect(b.x-1,f-1,b.width+2,y+2),s.restore();for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX,_=R-M;if(!(_<=0)){s.save(),s.globalAlpha=tr,s.strokeStyle=b.color,s.lineWidth=nr,s.beginPath(),s.rect(M,f,_,y),s.clip();for(let H=M-y;H<R+y;H+=sr)s.beginPath(),s.moveTo(H,f+y),s.lineTo(H+y,f),s.stroke();s.restore()}}for(let I=0;I<m.length-1;I++){const M=m[I].endX,R=m[I+1].startX;s.save(),s.globalAlpha=er,s.strokeStyle=En(b.color,Gs),s.lineWidth=Qa,s.setLineDash(Ja),s.beginPath(),s.moveTo(M,v),s.lineTo(R,v),s.stroke(),s.setLineDash([]),s.restore()}const S=o.tasks.get(b.taskId),k=(S==null?void 0:S.progress)??0,w=ar(T.segments);let E=k*w;for(let I=0;I<m.length;I++){const M=m[I],R=Math.max(Oe(T.segments[I].endDate).getTime()-Oe(T.segments[I].startDate).getTime(),Vs);if(s.save(),Dn(s,M.startX,f,M.width,y,d),s.fillStyle=b.color,s.fill(),s.strokeStyle=En(b.color,Gs),s.lineWidth=ir,s.stroke(),s.restore(),E>0&&a.showProgress){const _=Math.min(E,R),H=_/R,N=M.width*H;s.save(),Dn(s,M.startX,f,M.width,y,d),s.clip(),s.globalAlpha=or,s.fillStyle=En(b.color,.3),s.fillRect(M.startX,f,N,y),s.restore(),E-=_}}if(b.label){const I=m[0],M=m[m.length-1],R=M.endX-I.startX;s.save(),s.font=`${c.fontSize}px ${c.fontFamily}`;const H=s.measureText(b.label).width;s.textBaseline="middle",s.textAlign="left",H+St*2<=I.width?(s.fillStyle=b.textColor,Dn(s,I.startX,f,I.width,y,d),s.clip(),s.fillText(b.label,I.startX+St,v)):H+St<=R?(s.fillStyle=b.textColor,s.fillText(b.label,I.startX+St,v)):(s.fillStyle=c.gridTextColor,s.fillText(b.label,M.endX+St,v)),s.restore()}}s.restore()},destroy(){n=null}}}const kn=864e5,js=1e3,Nt=4,lr=.6,cr="#E53E3E",dr="#48BB78",ur="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ct(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function xt(e,t){return Math.round((t.getTime()-e.getTime())/kn)}function qs(e,t){return new Date(e.getTime()+t*kn)}function Ve(e,t){return ct(qs(he(e),t))}function Fe(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ct(n)),o;for(;i.getTime()<s.getTime();)o.push(ct(i)),i.setTime(i.getTime()+kn);return o}class Cn{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,u;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const c of s){const p=(i.get(c)??0)-o;p<=0?i.delete(c):i.set(c,p),(l=a.get(c))==null||l.delete(n),((u=a.get(c))==null?void 0:u.size)===0&&a.delete(c)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var u;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const c of s){let h=(a==null?void 0:a.get(c))??0;if((u=l==null?void 0:l.get(c))!=null&&u.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Ht(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const u=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:u})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function gr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let u=1/0;if(typeof l=="number")u=l;else if(typeof l=="string"){const c=parseInt(l,10);isNaN(c)||(u=c)}s.set(i,{taskId:i,isCritical:!1,priority:u,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Zs(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function hr(e,t,n,s,o){const i=new Map;for(const f of s)e.has(f.taskId)&&n.has(f.resourceId)&&(i.has(f.taskId)||i.set(f.taskId,[]),i.get(f.taskId).push({resourceId:f.resourceId,units:f.units||1}));const a=new Map,l=new Map;for(const f of e.keys())a.set(f,[]),l.set(f,[]);for(const f of t.values()){if((f.type||"FS")!=="FS"||!e.has(f.source)||!e.has(f.target))continue;const v=f.lag||0;a.get(f.source).push({target:f.target,lag:v}),l.get(f.target).push({source:f.source,lag:v})}const u=new Map;for(const[f,y]of e){const v=he(y.startDate),m=he(y.endDate);u.set(f,{taskId:f,startDate:y.startDate,endDate:y.endDate,duration:Math.max(xt(v,m),0)})}const c=new Cn;function h(){c.clear();for(const[f,y]of u){const v=i.get(f);if(!v)continue;const m=Fe(y.startDate,y.endDate);for(const S of v)c.allocate(S.resourceId,f,m,S.units)}}function p(f,y){const v=u.get(f);if(!v)return new Set;const m=new Set,S=v.startDate;if(y===S||he(y).getTime()<he(S).getTime())return m;const k=i.get(f);if(k){const w=Fe(v.startDate,v.endDate);for(const D of k)c.deallocate(D.resourceId,f,w,D.units)}if(v.startDate=y,v.endDate=Ve(y,v.duration),m.add(f),k){const w=Fe(v.startDate,v.endDate);for(const D of k)c.allocate(D.resourceId,f,w,D.units)}return m}function r(f){const y=new Set,v=u.get(f);if(!v)return y;const m=a.get(f)??[];for(const{target:S,lag:k}of m){const w=u.get(S);if(!w)continue;const D=Ve(v.endDate,k);if(he(w.startDate).getTime()<he(D).getTime()){const E=p(S,D);for(const I of E){y.add(I);const M=r(I);for(const R of M)y.add(R)}}}return y}function d(f){const y=l.get(f)??[];let v=u.get(f).startDate;v=e.get(f).startDate;for(const{source:S,lag:k}of y){const w=u.get(S);if(!w)continue;const D=Ve(w.endDate,k);he(D).getTime()>he(v).getTime()&&(v=D)}return v}h();for(let f=0;f<js;f++){const y=Ht(c,n);if(y.length===0)break;let v=!1;const m=y[0],S=m.taskIds.map(k=>o.get(k)).filter(k=>k!==void 0).sort(Zs);if(!(S.length<2))for(let k=1;k<S.length;k++){const w=S[k],D=u.get(w.taskId);if(!D)continue;const E=u.get(S[0].taskId);if(!E)continue;const I=E.endDate,M=d(w.taskId),R=he(I).getTime()>he(M).getTime()?I:M;he(R).getTime()>he(D.startDate).getTime()&&(p(w.taskId,R),r(w.taskId),v=!0);const _=c.getLoad(m.resourceId,m.date),H=n.get(m.resourceId).maxUnits;if(_<=H)break}}const g=new Map;let b=0;for(const[f,y]of u){const v=e.get(f),m=xt(he(v.startDate),he(y.startDate));m!==0&&(g.set(f,{startDate:y.startDate,endDate:y.endDate,delayDays:m}),b+=m)}const T=Ht(c,n);return{adjustedTasks:g,totalDelay:b,conflicts:T,resolved:T.length===0}}function fr(e,t,n,s,o){const i=new Map;for(const y of s)e.has(y.taskId)&&n.has(y.resourceId)&&(i.has(y.taskId)||i.set(y.taskId,[]),i.get(y.taskId).push({resourceId:y.resourceId,units:y.units||1}));const a=new Map;for(const y of e.keys())a.set(y,[]);for(const y of t.values())(y.type||"FS")==="FS"&&(!e.has(y.source)||!e.has(y.target)||a.get(y.target).push({source:y.source,lag:y.lag||0}));const l=Array.from(e.keys()).map(y=>o.get(y)).filter(y=>y!==void 0).sort(Zs),u=new Map,c=new Cn,h=new Set,p=new Map;for(const[y,v]of e)p.set(y,Math.max(xt(he(v.startDate),he(v.endDate)),0));function r(y){let m=e.get(y).startDate;const S=a.get(y)??[];for(const{source:k,lag:w}of S){const D=u.get(k);if(!D)continue;const E=Ve(D.endDate,w);he(E).getTime()>he(m).getTime()&&(m=E)}return m}function d(y,v,m){const S=i.get(y);if(!S||S.length===0)return v;let k=v;const w=365*5;for(let D=0;D<w;D++){const E=Ve(k,m),I=Fe(k,E);let M=!0;for(const R of S){const _=n.get(R.resourceId);if(!_||_.maxUnits===0)continue;const H=_.calendar?new Set(_.calendar):null;if(H&&I.some(P=>H.has(P))){M=!1;break}if(!c.canFit(R.resourceId,y,I,R.units,_.maxUnits)){M=!1;break}}if(M)return k;k=Ve(k,1)}return v}const g=new Set(l.map(y=>y.taskId));for(let y=0;y<js&&g.size>0;y++){let v=!1;for(const m of l){if(!g.has(m.taskId)||!(a.get(m.taskId)??[]).every(_=>h.has(_.source)))continue;const w=m.taskId,D=p.get(w)??0,E=r(w),I=d(w,E,D),M=Ve(I,D);u.set(w,{taskId:w,startDate:I,endDate:M,duration:D});const R=i.get(w);if(R){const _=Fe(I,M);for(const H of R)c.allocate(H.resourceId,w,_,H.units)}h.add(w),g.delete(w),v=!0}if(!v){for(const m of g){const S=e.get(m),k=p.get(m)??0;u.set(m,{taskId:m,startDate:S.startDate,endDate:S.endDate,duration:k});const w=i.get(m);if(w){const D=Fe(S.startDate,S.endDate);for(const E of w)c.allocate(E.resourceId,m,D,E.units)}h.add(m)}g.clear()}}const b=new Map;let T=0;for(const[y,v]of u){const m=e.get(y),S=xt(he(m.startDate),he(v.startDate));S!==0&&(b.set(y,{startDate:v.startDate,endDate:v.endDate,delayDays:S}),T+=S)}const f=Ht(c,n);return{adjustedTasks:b,totalDelay:T,conflicts:f,resolved:f.length===0}}function pr(e,t,n,s){const o=[],i=Fe(n,Ve(s,1)),a=i.length;for(const[l,u]of t){const c=new Map;let h=0,p=0;for(const g of i){const b=e.getLoad(l,g);c.set(g,b),h+=b,b>p&&(p=b)}const r=u.maxUnits===0?1:u.maxUnits,d=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:u.name,dailyLoad:c,overallUtilization:Math.min(d,1),peakUtilization:p})}return o}function Js(e,t,n,s){const o=new Cn,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const u=i.get(a);if(!u)continue;const c=s.get(a),h=(c==null?void 0:c.startDate)??l.startDate,p=(c==null?void 0:c.endDate)??l.endDate,r=Fe(h,p);for(const d of u)o.allocate(d.resourceId,a,r,d.units)}return o}function mr(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function u(){return null}function c(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:d,dependencies:g}=r;if(d.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const b=u(),T=gr(d,b,n);s==="parallel"?i=fr(d,g,t,e.assignments,T):i=hr(d,g,t,e.assignments,T);const f=h(d,i.adjustedTasks),y=Js(d,t,e.assignments,i.adjustedTasks);return a=pr(y,t,f.start,f.end),i}function h(r,d){let g=1/0,b=-1/0;for(const[T,f]of r){const y=d.get(T),v=he((y==null?void 0:y.startDate)??f.startDate).getTime(),m=he((y==null?void 0:y.endDate)??f.endDate).getTime();v<g&&(g=v),m>b&&(b=m)}if(g===1/0){const T=ct(new Date);return{start:T,end:T}}return{start:ct(new Date(g)),end:ct(new Date(b))}}function p(r){const d=[];for(const g of e.assignments)g.taskId===r&&d.push(g.resourceId);return d}return{name:"ResourceLevelingPlugin",install(r){o=r,c(),l.push(r.on("resourceLeveling:run",(...d)=>{const g=d[0],b=c();g&&g(b)})),l.push(r.on("resourceLeveling:result",(...d)=>{const g=d[0];g&&g(i)})),l.push(r.on("resourceLeveling:utilization",(...d)=>{const g=d[0];g&&g(a)})),l.push(r.on("resourceLeveling:conflicts",(...d)=>{const g=d[0];if(!g)return;const b=r.getState(),T=Js(b.tasks,t,e.assignments,new Map);g(Ht(T,t))}))},middleware(r,d){d(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&c()},renderCanvas(r,d,g){if(!i||a.length===0)return;const{config:b}=d,{headerHeight:T,rowHeight:f}=b,y=d.scrollX,v=d.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,T,r.canvas.width,r.canvas.height-T),r.clip(),r.translate(-y,0);const S=new Map;for(const k of a)S.set(k.resourceId,k);for(const k of g){const w=p(k.taskId);if(w.length===0)continue;const D=S.get(w[0]);if(!D)continue;const E=t.get(w[0]);if(!E)continue;const I=E.maxUnits===0?1:E.maxUnits,R=k.barY+k.barHeight-v+1;if(R+Nt<T||R>r.canvas.height)continue;const _=d.tasks.get(k.taskId);if(!_)continue;const H=i.adjustedTasks.get(k.taskId),N=(H==null?void 0:H.startDate)??_.startDate,P=(H==null?void 0:H.endDate)??_.endDate,B=m.dateToX(he(N)),K=m.dateToX(he(P))-B;if(K<2)continue;r.fillStyle=ur,r.fillRect(B,R,K,Nt);const q=Fe(N,P);for(const U of q){const C=D.dailyLoad.get(U)??0;if(C===0)continue;const $=m.dateToX(he(U)),O=m.dateToX(qs(he(U),1))-$,Q=Math.min(C/I,2)/2*Nt,Z=C>I;r.globalAlpha=lr,r.fillStyle=Z?cr:dr,r.fillRect($,R+Nt-Q,O,Q),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const yr=864e5,Tr=75,br=50,Qs=25,Bt=.3,Ft=.25,eo=.2,In=.15,Yt=.1,vr=.3,to=.5,wr=20,no=40,Sr=3,Er=5,Dr=30,so=.25,oo=4,kr=2,Cr=5,Mn=5,io=4,ao=.4,Ir=.003,Ke=260,dt=260,ro=16,Ye=14,Mr="rgba(30, 30, 46, 0.92)",An="#e0e0e0",Ar=10,Ut=32,Lr=6,Wt="#EF4444",Xt="#F97316",zt="#EAB308",Gt="#22C55E";function ve(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ke(e,t){return Math.round((t.getTime()-e.getTime())/yr)}function De(e,t,n){return Math.max(t,Math.min(n,e))}function Rr(e){return e>=Tr?"critical":e>=br?"high":e>=Qs?"medium":"low"}function Pr(e){switch(e){case"critical":return Wt;case"high":return Xt;case"medium":return zt;case"low":return Gt}}function Vt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function _r(e,t){const n=new Map,s=new Map;for(const f of e.keys())n.set(f,[]),s.set(f,[]);for(const f of t.values())!e.has(f.source)||!e.has(f.target)||(n.get(f.source).push(f.target),s.get(f.target).push(f.source));const o=new Map,i=new Set;function a(f){if(o.has(f))return o.get(f);if(i.has(f))return 0;i.add(f);let y=0;for(const v of n.get(f)||[])y+=1+a(v);return o.set(f,y),y}for(const f of e.keys())a(f);const l=new Map;for(const[f,y]of e){const v=ve(y.startDate),m=ve(y.endDate);l.set(f,Math.max(ke(v,m),0))}const u=new Map,c=new Map,h=new Map;for(const f of e.keys())h.set(f,(s.get(f)||[]).length),u.set(f,l.get(f)||0),c.set(f,null);const p=[],r=new Map(h);for(const[f,y]of r)y===0&&p.push(f);for(;p.length>0;){const f=p.shift();for(const y of n.get(f)||[]){const v=u.get(f)+(l.get(y)||0);v>u.get(y)&&(u.set(y,v),c.set(y,f));const m=r.get(y)-1;r.set(y,m),m===0&&p.push(y)}}const d=new Set;let g=0,b=null;for(const[f,y]of u)y>g&&(g=y,b=f);let T=b;for(;T!==null;)d.add(T),T=c.get(T)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:d}}function $r(e){const t=Vt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=ve(o.startDate),a=ve(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function Or(e,t,n){const s=[],o=Vt(),i=ve(e.startDate),a=ve(e.endDate),l=Math.max(ke(i,a),1),u=Math.max(ke(i,o),0),c=Math.max(ke(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let p=0;const r=o.getTime()>a.getTime();if(r){const D=ke(a,o);p=De(80+D*2,80,100),s.push({type:"time-pressure",description:`Task is ${D} day${D===1?"":"s"} past its end date`,impact:Math.round(p*Bt)})}else{const D=c/l;D<.2&&h<.5?(p=85,s.push({type:"time-pressure",description:`Only ${Math.round(D*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(p*Bt)})):(p=De(Math.round((1-D)*70),0,70),p>0&&s.push({type:"time-pressure",description:`${Math.round(D*100)}% of scheduled time remaining`,impact:Math.round(p*Bt)}))}let d=0;const g=De(u/l,0,1),b=g-h;b>to?(d=De(Math.round(b*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Ft)})):b>vr?(d=De(Math.round(b*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(b*100)}% behind expected progress (expected ${Math.round(g*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(d*Ft)})):b>.1&&(d=De(Math.round(b*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(g*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(d*Ft)}));let T=0;const f=t.downstreamCount.get(e.id)||0,y=t.criticalPathIds.has(e.id);if(f>0){T=De(Math.round(Math.log2(f+1)*20),0,70),y&&(T=De(Math.round(T*1.5),0,100));const D=y?" (on critical path)":"";s.push({type:"dependency-chain",description:`${f} downstream dependent${f===1?"":"s"}${D}`,impact:Math.round(T*eo)})}let v=0;l>no?(v=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(v*In)})):l>wr&&(v=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(v*In)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*Yt)});else{const D=n.activeTasks.get(e.assignee)||[];D.length>Er?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Yt)})):D.length>Sr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${D.length} concurrent active tasks`,impact:Math.round(m*Yt)}))}const S=De(Math.round(p*Bt+d*Ft+T*eo+v*In+m*Yt),0,100),k=Rr(S);let w;return r&&h===0?w="Task is overdue with no progress — escalate immediately":r?w="Task is past its deadline — review scope or extend timeline":b>to?w="Task is significantly behind schedule — investigate blockers":l>no&&h<so?w="Large task with little progress — consider splitting into smaller work items":(k==="high"||k==="critical")&&(w="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:k,riskScore:S,factors:s,suggestion:w}}function Nr(e,t,n,s,o){const i=Vt();let a=0,l=0,u=0;for(const[y,v]of e){if(v.isCompleted||(v.progress??0)>=1)continue;l++;const m=ve(v.startDate),S=ve(v.endDate),k=Math.max(ke(m,S),1),w=Math.max(ke(m,i),0),D=De(w/k,0,1);(v.progress??0)>=D-.1&&a++;const I=t.get(y);I&&(I.riskLevel==="high"||I.riskLevel==="critical")&&u++}const c=l>0?a/l:1;let h=0;for(const y of n.criticalPathIds){const v=e.get(y);if(!v||v.isCompleted)continue;const m=ve(v.endDate);i.getTime()>m.getTime()&&(h+=ke(m,i))}const p=[],r=[];for(const[y,v]of s.activeTasks)p.push(v.length),v.length>oo&&r.push(y);let d=100;if(p.length>1){const y=p.reduce((v,m)=>v+m,0)/p.length;if(y>0){const v=p.reduce((S,k)=>S+(k-y)**2,0)/p.length,m=Math.sqrt(v)/y;d=De(Math.round(100-m*50),0,100)}}let g=100;if(l>0){let y=0,v=0,m=0;for(const S of e.values()){if(S.isCompleted)continue;const k=ve(S.startDate),w=ve(S.endDate),D=Math.max(ke(k,w),1),E=Math.max(ke(k,i),0),I=De(E/D,0,2);y+=S.progress??0,v+=I,m++}if(m>0){const S=y/m,k=v/m;if(k>0){const w=S/k;g=De(Math.round(w*100),0,100)}}}const b=c*100,T=De(100-h*10,0,100);return{overallScore:De(Math.round(b*.25+T*.25+d*.25+g*.25),0,100),tasksAtRisk:u,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function xr(e,t,n,s){const o=[],i=Vt();let a=1;for(const[p,r]of e){if(r.isCompleted)continue;const d=ve(r.endDate),g=ke(d,i),b=r.progress??0;g>Cr&&b===0&&o.push({type:"escalate",description:`"${r.name}" is ${g} days overdue with zero progress — flag for management`,impact:`Prevents further ${g}-day cascade to dependents`,taskIds:[p],priority:a++})}for(const[p,r]of e){if(r.isCompleted)continue;const d=ve(r.startDate),g=ve(r.endDate),b=ke(d,g),T=r.progress??0;if(b>Dr&&T<so){const f=Math.ceil(b/15);o.push({type:"split",description:`"${r.name}" spans ${b} days — split into ${f} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[p],priority:a++})}}const l=[],u=[];for(const[p,r]of n.activeTasks)r.length>oo?l.push({assignee:p,taskIds:r}):r.length<kr&&u.push(p);if(l.length>0&&u.length>0)for(const{assignee:p,taskIds:r}of l){const d=r.filter(g=>!t.criticalPathIds.has(g));d.length>0&&o.push({type:"reassign",description:`"${p}" has ${r.length} active tasks — move non-critical work to ${u.join(", ")}`,impact:`Reduces ${p}'s load and unblocks parallel progress`,taskIds:d,priority:a++})}for(const p of t.criticalPathIds){const r=e.get(p);if(!r||r.isCompleted)continue;const d=ve(r.endDate),g=ke(i,d);if(g>=0&&g<=5){const b=s.get(p);b&&b.riskScore>=Qs&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${g} day${g===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${g}-day slip`,taskIds:[p],priority:a++})}}const c=Array.from(t.criticalPathIds).map(p=>e.get(p)).filter(p=>p&&!p.isCompleted).sort((p,r)=>ve(p.startDate).getTime()-ve(r.startDate).getTime()),h=new Set;for(const[,p]of t.successors)for(const r of p);for(const[p,r]of t.predecessors)for(const d of r)h.add(`${d}->${p}`);for(let p=0;p<c.length;p++)for(let r=p+1;r<c.length;r++){const d=c[p],g=c[r],b=ve(d.endDate),T=ve(g.startDate);if(b.getTime()<=T.getTime()&&!(h.has(`${d.id}->${g.id}`)||h.has(`${g.id}->${d.id}`))){const y=ke(b,T);y>0&&o.push({type:"parallel",description:`"${d.name}" and "${g.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${y} days on the critical path`,taskIds:[d.id,g.id],priority:a++});break}}return o.sort((p,r)=>p.priority-r.priority),o}function Hr(e,t,n,s,o,i,a){if(e.save(),i){const l=ao+(1-ao)*(.5+.5*Math.sin(a*Ir));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function Br(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,u=l-a,c=a+u*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Gt:i>=50?zt:i>=25?Xt:Wt;e.beginPath(),e.arc(t,n,s,a,c),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=An,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function Fr(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:Wt,label:"Critical"},{count:o.high,color:Xt,label:"High"},{count:o.medium,color:zt,label:"Medium"},{count:o.low,color:Gt,label:"Low"}];let l=-Math.PI/2;for(const u of a){if(u.count===0)continue;const c=u.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+c),e.closePath(),e.fillStyle=u.color,e.fill(),l+=c}}function Yr(e,t,n,s,o){const i=t-Ke-ro,a=n+ro;e.save(),e.beginPath();const l=Ar;e.moveTo(i+l,a),e.lineTo(i+Ke-l,a),e.arcTo(i+Ke,a,i+Ke,a+l,l),e.lineTo(i+Ke,a+dt-l),e.arcTo(i+Ke,a+dt,i+Ke-l,a+dt,l),e.lineTo(i+l,a+dt),e.arcTo(i,a+dt,i,a+dt-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=Mr,e.fill(),e.fillStyle=An,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+Ye,a+Ye);const u=i+Ye+Ut+4,c=a+Ye+20+Ut+8;Br(e,u,c,Ut,Lr,s.overallScore);const h=24,p=i+Ke-Ye-h-4,r=c;Fr(e,p,r,h,o),e.font="9px sans-serif",e.textAlign="center";const d=r+h+8,g=[{count:o.critical,color:Wt,label:"C"},{count:o.high,color:Xt,label:"H"},{count:o.medium,color:zt,label:"M"},{count:o.low,color:Gt,label:"L"}],b=28,T=p-g.length*b/2+b/2;for(let m=0;m<g.length;m++){const S=g[m],k=T+m*b;e.fillStyle=S.color,e.fillText(`${S.label}:${S.count}`,k,d)}const f=c+Ut+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+Ye,f);const y=f+18;e.font="10px sans-serif",e.fillStyle=An,e.fillText("Recommendations:",i+Ye,y);const v=s.recommendations.slice(0,3);for(let m=0;m<v.length;m++){const S=v[m],k=y+14+m*16,w=S.type==="escalate"?"⚠":S.type==="split"?"✂":S.type==="reassign"?"⇄":S.type==="parallel"?"⇉":S.type==="add-buffer"?"⏱":"ℹ",D=34,E=S.description.length>D?S.description.substring(0,D-1)+"…":S.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${w} ${E}`,i+Ye,k)}v.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+Ye,y+14)),e.restore()}function Ur(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const u=e.getState(),{tasks:c,dependencies:h}=u;if(c.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const p=_r(c,h),r=$r(c),d=new Map;for(const[g,b]of c)d.set(g,Or(b,p,r));n=d,o=xr(c,p,r,n),s=Nr(c,n,p,r,o)}return{name:"RiskAnalysisPlugin",install(u){e=u,a=Date.now(),l(),t.push(e.on("risk:analysis",c=>{typeof c=="function"&&c(n)})),t.push(e.on("risk:health",c=>{typeof c=="function"&&c(s)})),t.push(e.on("risk:recommendations",c=>{typeof c=="function"&&c(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(u,c){c(u),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(u.type)&&l()},renderCanvas(u,c,h){if(n.size===0)return;const{headerHeight:p}=c.config,r=c.scrollX,d=c.scrollY,g=p,b=Date.now()-a;u.save(),u.beginPath(),u.rect(0,g,u.canvas.width,u.canvas.height-g),u.clip(),u.translate(-r,0);for(const T of h){const f=n.get(T.taskId);if(!f||f.riskLevel==="low")continue;const y=T.x,v=T.barY-d,m=T.width,S=T.barHeight;if(v+S<g||v>u.canvas.height||y+m<0)continue;const k=y+m-Mn-io,w=v+Mn+io,D=Pr(f.riskLevel),E=f.riskLevel==="critical";Hr(u,k,w,Mn,D,E,b)}if(u.restore(),i){const T={critical:0,high:0,medium:0,low:0};for(const f of n.values())T[f.riskLevel]++;u.save(),Yr(u,u.canvas.width,p,s,T),u.restore()}},destroy(){for(const u of t)u();t=[],n=new Map,o=[]}}}const Le=160,je=80,Ln=8,Wr=240,Xr=160,zr=100,Gr=200,Kt=8,lo=.1,co=3,Vr=.001,Kr=500,jr=5,qr=864e5,Zr={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function uo(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Jr(e,t){return Math.round((t.getTime()-e.getTime())/qr)}function go(e,t,n){return e+(t-e)*n}function jt(e,t,n){return Math.max(t,Math.min(n,e))}function Rn(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function Qr(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,u]of i)u===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),u=n.get(l);for(const c of s.get(l)){const h=n.get(c),p=u+1;(h===void 0||p>h)&&n.set(c,p);const r=i.get(c)-1;i.set(c,r),r===0&&a.push(c)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function el(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function tl(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<jr;a++){for(let l=1;l<e.length;l++){const u=e[l],c=new Map;for(const h of u){const p=o.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}for(let l=e.length-2;l>=0;l--){const u=e[l],c=new Map;for(const h of u){const p=s.get(h);if(p.size===0){c.set(h,i.get(h)??0);continue}let r=0;for(const d of p)r+=i.get(d)??0;c.set(h,r/p.size)}u.sort((h,p)=>(c.get(h)??0)-(c.get(p)??0));for(let h=0;h<u.length;h++)i.set(u[h],h)}}}function nl(e,t){const n=new Map;if(t==="radial")return sl(e);const s=t==="lr",o=s?Wr:Xr,i=s?zr:Gr;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let p=0;p<l.length;p++){const r=l[p],d=h+p*i;s?n.set(r,{x:a*o,y:d}):n.set(r,{x:d,y:a*o})}}return n}function sl(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,u=n*.5;t.set(o[a],{x:Math.cos(l)*u,y:Math.sin(l)*u})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const u=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(u)*i,y:Math.sin(u)*i})}}}return t}function Et(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function ol(e,t){return e.color?e.color:e.status&&(t[e.status]||Zr[e.status])||"#94A3B8"}function il(e){const t=uo(e.startDate),n=uo(e.endDate);return Math.max(Jr(t,n),0)}function al(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,u=null,c=new Map,h=[],p=null,r=0,d=0,g=1,b=!1,T=0,f=0,y=0,v=0,m=null,S=0,k=0,w=null,D=null,E=new Set,I=!1,M=0,R=0,_=0,H=0;function N(X,L){return{x:(X-r)/g,y:(L-d)/g}}function P(X,L){const{x,y:z}=N(X,L);for(const G of c.values()){const V=G.x,te=G.y;if(x>=V&&x<=V+Le&&z>=te&&z<=te+je)return G}return null}function B(){const X=e.getState(),{tasks:L,dependencies:x,config:z}=X;if(L.size===0){c=new Map,h=[];return}p=hn(L,x);const G=Qr(L,x),V=el(G);tl(V,x,L);const te=nl(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:Se}of te.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Le),le=Math.min(le,Se),pe=Math.max(pe,Se+je);const be=(oe+ae)/2,Ce=(le+pe)/2,Ie=c;c=new Map;for(const[ue,Se]of L){const Me=te.get(ue);if(!Me)continue;const Xe=Me.x-be,Qe=Me.y-Ce,Ne=Ie.get(ue);c.set(ue,{id:ue,task:Se,layer:G.get(ue)??0,orderInLayer:0,x:Ne?Ne.x:Xe,y:Ne?Ne.y:Qe,targetX:Xe,targetY:Qe,isCritical:p.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let Se=0;Se<ue.length;Se++){const Me=c.get(ue[Se]);Me&&(Me.orderInLayer=Se)}h=[];for(const ue of x.values())!L.has(ue.source)||!L.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:p.criticalTaskIds.has(ue.source)&&p.criticalTaskIds.has(ue.target)})}function W(X){const L=e.getState(),x=new Set;x.add(X);const z=new Map,G=new Map;for(const oe of L.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of L.dependencies.values())!L.tasks.has(oe.source)||!L.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])x.has(ae)||(x.add(ae),V.push(ae))}const te=[X];for(;te.length>0;){const oe=te.shift();for(const ae of z.get(oe)||[])x.has(ae)||(x.add(ae),te.push(ae))}return x}function K(){I&&cancelAnimationFrame(R),I=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,L=jt(X/Kr,0,1),x=1-Math.pow(1-L,3);let z=!1;for(const G of c.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),te=Math.abs(G.y-G.targetY);V>.5||te>.5?(G.x=go(G.x,G.targetX,x),G.y=go(G.y,G.targetY,x),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(U(),z&&L<1)R=requestAnimationFrame(q);else{I=!1;for(const G of c.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);U()}}function U(){if(!i||!o)return;const X=e.getState(),{config:L}=X,x=L.theme,z=L.colorMap,G=x.timelineBg==="#1A202C"||x.gridBg==="#1A202C"||x.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(x.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,_,H),i.save(),i.translate(r,d),i.scale(g,g);for(const V of h){const te=c.get(V.sourceId),oe=c.get(V.targetId);if(!te||!oe)continue;const ae=E.has(V.sourceId)&&E.has(V.targetId),le=w===V.sourceId||w===V.targetId,pe=w!==null&&!le||D!==null&&!ae,be=te.x+Le,Ce=te.y+je/2,Ie=oe.x,ue=oe.y+je/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=x.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const Se=(be+Ie)/2;i.beginPath(),i.moveTo(be,Ce),i.quadraticCurveTo(Se,Ce,(be+Ie)/2,(Ce+ue)/2),i.quadraticCurveTo(Se,ue,Ie,ue),i.stroke();const Me=Math.atan2(ue-(Ce+ue)/2,Ie-Se);i.beginPath(),i.moveTo(Ie,ue),i.lineTo(Ie-Kt*Math.cos(Me-Math.PI/6),ue-Kt*Math.sin(Me-Math.PI/6)),i.lineTo(Ie-Kt*Math.cos(Me+Math.PI/6),ue-Kt*Math.sin(Me+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Xe=V.dep.type||"FS",Qe=V.dep.lag||0,Ne=Qe!==0?`${Xe} +${Qe}d`:Xe!=="FS"?Xe:"";if(Ne&&!pe){const Ct=(be+Ie)/2,Kn=(Ce+ue)/2-8;i.font=`10px ${x.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(Ne,Ct,Kn)}i.restore()}for(const V of c.values()){const te=w!==null&&w!==V.id&&!$(w,V.id)||D!==null&&!E.has(V.id),oe=w===V.id,ae=D===V.id,le=ol(V.task,z),pe=V.x,be=V.y;i.save(),te&&(i.globalAlpha=.25),V.isCritical&&!te&&(i.save(),i.shadowColor=x.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Et(i,pe,be,Le,je,Ln),i.fillStyle="transparent",i.fill(),i.restore()),Et(i,pe,be,Le,je,Ln),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=x.selectionColor||"#3182CE",i.lineWidth=2,Et(i,pe-2,be-2,Le+4,je+4,Ln+2),i.stroke()),i.font=`600 12px ${x.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ce=Rn(i,V.task.name,Le-20);i.fillText(Ce,pe+10,be+8);const Ie=be+26;i.beginPath(),i.arc(pe+16,Ie+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${x.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText(Rn(i,ue,Le-40),pe+24,Ie);const Se=il(V.task),Me=Se===1?"1 day":`${Se} days`;i.font=`10px ${x.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Me,pe+10,be+42),V.task.assignee&&(i.font=`10px ${x.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText(Rn(i,V.task.assignee,Le/2-10),pe+Le-10,be+42));const Xe=V.task.progress??0,Qe=be+je-6,Ne=Le-20,Ct=3;if(Et(i,pe+10,Qe,Ne,Ct,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),Xe>0){const Kn=Math.max(Ct,Ne*jt(Xe,0,1));Et(i,pe+10,Qe,Kn,Ct,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),C(G,x.fontFamily)}function C(X,L){if(!i)return;const x={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${L}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${x[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(g*100)}%`,_-12,12),i.restore()}function $(X,L){for(const x of h)if(x.sourceId===X&&x.targetId===L||x.sourceId===L&&x.targetId===X)return!0;return!1}function A(X){l=X;const L=X.querySelector(".ng-timeline-panel");if(!L)return;u=L.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",L.appendChild(o);const x=o.getContext("2d");x&&(i=x,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",me),o.addEventListener("mouseup",Y),o.addEventListener("mouseleave",ee),o.addEventListener("dblclick",j),o.addEventListener("wheel",J,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",ye))}function O(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(_=X.clientWidth,H=X.clientHeight,o.width=Math.round(_*a),o.height=Math.round(H*a),o.style.width=`${_}px`,o.style.height=`${H}px`)}function F(){if(o){n=!0,o.style.display="block",u&&(u.style.visibility="hidden"),O(),Z(),B();for(const X of c.values())X.x=X.targetX,X.y=X.targetY;U()}}function Q(){o&&(n=!1,o.style.display="none",u&&(u.style.visibility="visible"),w=null,D=null,E=new Set)}function Z(){r=_/2,d=H/2,g=1}function re(X){if(!o)return{x:0,y:0};const L=o.getBoundingClientRect();return{x:X.clientX-L.left,y:X.clientY-L.top}}function ge(X){const{x:L,y:x}=re(X),z=P(L,x);z?(m=z,z.isDragging=!0,S=N(L,x).x-z.x,k=N(L,x).y-z.y,D=z.id,E=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),U()):(b=!0,T=L,f=x,y=r,v=d,D&&(D=null,E=new Set,e.dispatch({type:"DESELECT_ALL"}),U()))}function me(X){if(!o)return;const{x:L,y:x}=re(X);if(m){const V=N(L,x);m.x=V.x-S,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U();return}if(b){const V=L-T,te=x-f;r=y+V,d=v+te,U();return}const z=P(L,x),G=z?z.id:null;G!==w&&(w=G,o.style.cursor=w?"pointer":"default",U())}function Y(X){m&&(m.isDragging=!1,m=null),b=!1}function ee(X){m&&(m.isDragging=!1,m=null),b=!1,w&&(w=null,U())}function j(X){const{x:L,y:x}=re(X),z=P(L,x);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function J(X){if(X.preventDefault(),!o)return;const{x:L,y:x}=re(X),z=N(L,x),G=-X.deltaY*Vr;g=jt(g+G*g,lo,co);const V=N(L,x);r+=(V.x-z.x)*g,d+=(V.y-z.y)*g,U()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const L=X.touches[0],x=o.getBoundingClientRect(),z=L.clientX-x.left,G=L.clientY-x.top,V=P(z,G);V?(m=V,V.isDragging=!0,S=N(z,G).x-V.x,k=N(z,G).y-V.y,D=V.id,E=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(b=!0,T=z,f=G,y=r,v=d),U()}else if(X.touches.length===2){b=!1,m&&(m.isDragging=!1,m=null);const L=X.touches[0],x=X.touches[1];se=Math.hypot(x.clientX-L.clientX,x.clientY-L.clientY),de=(L.clientX+x.clientX)/2,ie=(L.clientY+x.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const L=o.getBoundingClientRect();if(X.touches.length===1){const x=X.touches[0],z=x.clientX-L.left,G=x.clientY-L.top;if(m){const V=N(z,G);m.x=V.x-S,m.y=V.y-k,m.targetX=m.x,m.targetY=m.y,U()}else if(b){const V=z-T,te=G-f;r=y+V,d=v+te,U()}}else if(X.touches.length===2){const x=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-x.clientX,z.clientY-x.clientY),V=(x.clientX+z.clientX)/2,te=(x.clientY+z.clientY)/2,oe=V-L.left,ae=te-L.top;if(se>0){const le=G/se,pe=N(oe,ae);g=jt(g*le,lo,co);const be=N(oe,ae);r+=(be.x-pe.x)*g,d+=(be.y-pe.y)*g}r+=V-de,d+=te-ie,se=G,de=V,ie=te,U()}}function ye(X){m&&(m.isDragging=!1,m=null),b=!1,se=0}function Te(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",me),o.removeEventListener("mouseup",Y),o.removeEventListener("mouseleave",ee),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",J),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",ye),o.remove(),o=null,i=null),u&&(u.style.visibility="visible",u=null),I&&(cancelAnimationFrame(R),I=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?Q():F()})),t.push(e.on("networkGraph:layout",(...L)=>{const x=L[0];x!==s&&(s=x,n&&(B(),K()))})),t.push(e.on("stateChange",()=>{n&&(B(),K())}))},renderDOM(X,L){o||A(X),n&&(O(),U())},destroy(){for(const X of t)X();t=[],Te(),c=new Map,h=[],p=null,n=!1}}}const ho=300,fo="nimbus-gantt-config-panel",Pn="nimbus-gantt-config-panel-styles",po=300,_n=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],rl=`
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
    transition: opacity ${po}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${ho}px;
    width: ${ho}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${po}ms ease;
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
`;function ll(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(fo);return e?JSON.parse(e):{}}catch{return{}}}function cl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(fo,JSON.stringify(e))}catch{}}function mo(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function qt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function dl(){if(typeof document>"u"||document.getElementById(Pn))return;const e=document.createElement("style");e.id=Pn,e.textContent=rl,document.head.appendChild(e)}function ul(){if(typeof document>"u")return;const e=document.getElementById(Pn);e&&e.remove()}function Zt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const u=document.createElement("input");u.type="range",u.className="ng-config-slider",u.min=String(t),u.max=String(n),u.step=String(o),u.value=String(s);const c=document.createElement("span");return c.className="ng-config-slider-value",c.textContent=String(s),u.addEventListener("input",()=>{const h=Number(u.value);c.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(u),a.appendChild(c),a}function Dt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function Jt(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=yo(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function yo(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function gl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function u(){if(!e)return;const w=e.getState();e.dispatch({type:"SET_SCROLL",x:w.scrollX,y:w.scrollY})}function c(w){Object.assign(t,w),cl(t)}function h(w,D,E){w[D]=E}function p(w,D){if(!e)return;const E=e.getState();h(E.config,w,D),c({[w]:D}),u()}function r(w,D){if(!e)return;const E=e.getState();h(E.config.theme,w,D),u()}function d(w){if(!e)return;const D=_n.find(I=>I.name===w);if(!D)return;const E=e.getState();Object.assign(E.config.theme,D.values),c({themePreset:w}),u()}function g(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function b(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function T(w,D){var X;const{config:E}=D;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?b():g()}),w.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",b),w.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",w.appendChild(o)),o.innerHTML="";const I=document.createElement("div");I.className="ng-config-panel-header",I.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",b),I.appendChild(M),o.appendChild(I);const R=f("Display Settings");R.appendChild(Zt("Row height",24,60,E.rowHeight,2,L=>p("rowHeight",L))),R.appendChild(Zt("Bar height",16,40,E.barHeight,2,L=>p("barHeight",L))),R.appendChild(Zt("Grid width",0,500,E.gridWidth,10,L=>p("gridWidth",L))),R.appendChild(Zt("Font size",10,16,E.theme.fontSize,1,L=>{h(D.config.theme,"fontSize",L),c({fontSize:L}),u()})),R.appendChild(Dt("Today marker",E.showToday,L=>{h(D.config,"showToday",L),c({showToday:L}),u()})),R.appendChild(Dt("Weekends",E.showWeekends,L=>{h(D.config,"showWeekends",L),c({showWeekends:L}),u()})),R.appendChild(Dt("Progress bars",E.showProgress,L=>{h(D.config,"showProgress",L),c({showProgress:L}),u()})),R.appendChild(Dt("Dependency arrows",a,L=>{a=L,c({showDependencies:L}),u()})),R.appendChild(Dt("Labels on bars",t.showBarLabels!==!1,L=>{c({showBarLabels:L}),u()})),o.appendChild(R);const _=f("Color Theme"),H=document.createElement("div");H.className="ng-config-row";const N=document.createElement("span");N.className="ng-config-label",N.textContent="Preset";const P=document.createElement("select");P.className="ng-config-select";const B=document.createElement("option");B.value="",B.textContent="Custom",P.appendChild(B);for(const L of _n){const x=document.createElement("option");x.value=L.name,x.textContent=L.name,t.themePreset===L.name&&(x.selected=!0),P.appendChild(x)}P.addEventListener("change",()=>{P.value&&d(P.value)}),H.appendChild(N),H.appendChild(P),_.appendChild(H),_.appendChild(Jt("Bar default",E.theme.barDefaultColor,L=>{r("barDefaultColor",L),c({customColors:{...t.customColors,barDefault:L}})})),_.appendChild(Jt("Today line",E.theme.todayLineColor,L=>{r("todayLineColor",L),c({customColors:{...t.customColors,todayLine:L}})})),_.appendChild(Jt("Grid lines",E.theme.timelineGridColor,L=>{r("timelineGridColor",L),c({customColors:{...t.customColors,gridLines:L}})})),_.appendChild(Jt("Background",E.theme.timelineBg,L=>{r("timelineBg",L),c({customColors:{...t.customColors,background:L}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",_.appendChild(W);const K={...E.colorMap,...t.statusColorMap},q=document.createElement("div");function U(){q.innerHTML="";const L=Object.entries(K);for(const[z,G]of L){const V=document.createElement("div");V.className="ng-config-color-map-entry";const te=document.createElement("input");te.className="ng-config-color-map-status",te.value=z,te.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=yo(G),oe.addEventListener("input",()=>{K[z]=oe.value,E.colorMap[z]=oe.value,c({statusColorMap:{...K}}),u()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete E.colorMap[z],c({statusColorMap:{...K}}),U(),u()}),V.appendChild(te),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const x=document.createElement("button");x.className="ng-config-color-map-add",x.textContent="+ Add status color",x.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",E.colorMap[z.trim()]="#3b82f6",c({statusColorMap:{...K}}),U(),u())}),q.appendChild(x)}U(),_.appendChild(q),o.appendChild(_);const C=f("Zoom & Time"),$=document.createElement("div");$.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const O=document.createElement("div");O.className="ng-config-zoom-group";const F=["day","week","month","quarter"];for(const L of F){const x=document.createElement("button");x.className="ng-config-zoom-btn"+(D.zoomLevel===L?" ng-active":""),x.textContent=L.charAt(0).toUpperCase()+L.slice(1),x.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:L}),c({zoomLevel:L}),O.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===x)))}),O.appendChild(x)}$.appendChild(A),$.appendChild(O),C.appendChild($);const Q=document.createElement("div");Q.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=mo(D.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const L=qt(re.value),x=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:L,end:x}),c({dateRangeStart:re.value})}),Q.appendChild(Z),Q.appendChild(re),C.appendChild(Q);const ge=document.createElement("div");ge.className="ng-config-row";const me=document.createElement("span");me.className="ng-config-label",me.textContent="End date";const Y=document.createElement("input");Y.type="date",Y.className="ng-config-date-input",Y.value=mo(D.dateRange.end),Y.addEventListener("change",()=>{if(!e||!Y.value)return;const L=e.getState().dateRange.start,x=qt(Y.value);e.dispatch({type:"SET_DATE_RANGE",start:L,end:x}),c({dateRangeEnd:Y.value})}),ge.appendChild(me),ge.appendChild(Y),C.appendChild(ge);const ee=document.createElement("div");ee.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),u())}),ee.appendChild(j),C.appendChild(ee),o.appendChild(C);const J=f("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY}),y("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>y("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&S(e.getState())}),se.appendChild(ce),J.appendChild(se),o.appendChild(J);const ye=f("Plugin Toggles"),Te=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const L of Te){const x=document.createElement("div");x.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=L.label;const G=((X=t.pluginToggles)==null?void 0:X[L.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const te=document.createElement("div");te.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",te.appendChild(oe);let ae=G;te.addEventListener("click",()=>{ae=!ae,te.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[L.key]:ae};c({pluginToggles:pe}),y(L.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),x.appendChild(le),x.appendChild(te),ye.appendChild(x)}o.appendChild(ye)}function f(w){const D=document.createElement("div");D.className="ng-config-section";const E=document.createElement("div");return E.className="ng-config-section-title",E.textContent=w,D.appendChild(E),D}function y(w){e&&v.forEach(D=>D(w))}const v=[];function m(w){const D=Array.from(w.tasks.values());if(D.length===0)return;const E=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],I=D.map(N=>[N.id,`"${(N.name||"").replace(/"/g,'""')}"`,N.startDate,N.endDate,String(Math.round((N.progress??0)*100))+"%",N.status||"",N.assignee||"",N.priority||"",N.groupName||""]),M=[E.join(","),...I.map(N=>N.join(","))].join(`
`),R=new Blob([M],{type:"text/csv;charset=utf-8;"}),_=URL.createObjectURL(R),H=document.createElement("a");H.href=_,H.download="gantt-tasks.csv",document.body.appendChild(H),H.click(),document.body.removeChild(H),URL.revokeObjectURL(_)}function S(w){const D=Array.from(w.tasks.values());if(D.length===0)return;const E=["Name","Start","End","Progress","Status","Assignee"],I=D.map(_=>[_.name,_.startDate,_.endDate,Math.round((_.progress??0)*100)+"%",_.status||"",_.assignee||""]),R=[E.join("	"),...I.map(_=>_.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(R).catch(()=>{})}function k(w){const D=t;if(D.rowHeight!==void 0&&h(w.config,"rowHeight",D.rowHeight),D.barHeight!==void 0&&h(w.config,"barHeight",D.barHeight),D.gridWidth!==void 0&&h(w.config,"gridWidth",D.gridWidth),D.fontSize!==void 0&&h(w.config.theme,"fontSize",D.fontSize),D.showToday!==void 0&&h(w.config,"showToday",D.showToday),D.showWeekends!==void 0&&h(w.config,"showWeekends",D.showWeekends),D.showProgress!==void 0&&h(w.config,"showProgress",D.showProgress),D.showDependencies!==void 0&&(a=D.showDependencies),D.themePreset){const E=_n.find(I=>I.name===D.themePreset);E&&Object.assign(w.config.theme,E.values)}D.customColors&&(D.customColors.barDefault&&h(w.config.theme,"barDefaultColor",D.customColors.barDefault),D.customColors.todayLine&&h(w.config.theme,"todayLineColor",D.customColors.todayLine),D.customColors.gridLines&&h(w.config.theme,"timelineGridColor",D.customColors.gridLines),D.customColors.background&&h(w.config.theme,"timelineBg",D.customColors.background)),D.statusColorMap&&Object.assign(w.config.colorMap,D.statusColorMap),D.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:D.zoomLevel})),D.dateRangeStart&&D.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:qt(D.dateRangeStart),end:qt(D.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(w){e=w,dl(),t=ll();const D=w.on("render",()=>{D(),k(w.getState()),u()});l.push(D);const E=w.on("config:open",()=>g()),I=w.on("config:close",()=>b()),M=w.on("config:toggle",()=>{i?b():g()});l.push(E,I,M)},renderDOM(w,D){T(w,D)},destroy(){l.forEach(w=>w()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),ul(),e=null,i=!1}}}const To=864e5,$n="nimbus-gantt-heatmap-styles",we=28,Re=2,qe=48,Pe=160,hl=3,bo="#1e1e2e",vo="#166534",wo="#a16207",So="#b91c1c",fl=`
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
`;function Eo(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function pl(e){return String(e.getUTCDate())}function ml(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function yl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Do(e,t){return Math.round((t.getTime()-e.getTime())/To)}function ko(e,t){return new Date(e.getTime()+t*To)}function ut(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Tl(e,t){return e===0?bo:e===1?vo:e===2?wo:So}function bl(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function vl(){if(typeof document>"u"||document.getElementById($n))return;const e=document.createElement("style");e.id=$n,e.textContent=fl,document.head.appendChild(e)}function wl(){if(typeof document>"u")return;const e=document.getElementById($n);e&&e.remove()}function Sl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const p=h.assignee||"Unassigned";n.add(p)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Do(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(ko(o,h));const u=new Map;let c=0;for(const h of s)for(const p of l){const r=`${h}|${ut(p)}`;u.set(r,{assignee:h,date:p,dateKey:ut(p),tasks:[],count:0})}for(const h of t){const p=h.assignee||"Unassigned",r=Eo(h.startDate),d=Eo(h.endDate),g=Do(r,d)+1;for(let b=0;b<g;b++){const T=ko(r,b),f=`${p}|${ut(T)}`,y=u.get(f);y&&(y.tasks.push(h),y.count++,y.count>c&&(c=y.count))}}return{assignees:s,dates:l,cells:u,maxCount:c}}function El(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&c(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&c(o)}function u(){s=!1,t&&t.classList.remove("ng-active")}function c(p){if(!t||!s)return;const r=Sl(p);let d=t.querySelector(".ng-heatmap-grid-wrapper");d||(d=document.createElement("div"),d.className="ng-heatmap-grid-wrapper",t.appendChild(d)),d.innerHTML="";const g=document.createElement("canvas"),b=Pe+r.dates.length*(we+Re),T=qe+r.assignees.length*(we+Re),f=window.devicePixelRatio||1;g.width=b*f,g.height=T*f,g.style.width=b+"px",g.style.height=T+"px",g.style.cursor="pointer";const y=g.getContext("2d");y.scale(f,f),y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle";let v="",m=Pe;for(let S=0;S<r.dates.length;S++){const k=r.dates[S],w=ml(k),D=Pe+S*(we+Re);if(w!==v){if(v&&S>0){const E=(m+D)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,E,12)}m=D,v=w}}if(v){const S=Pe+r.dates.length*(we+Re),k=(m+S)/2;y.fillStyle="#94a3b8",y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.fillText(v,k,12)}y.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let S=0;S<r.dates.length;S++){const k=r.dates[S],w=Pe+S*(we+Re)+we/2,D=k.getUTCDay()===0||k.getUTCDay()===6;y.fillStyle=D?"#475569":"#64748b",y.fillText(pl(k),w,32)}y.beginPath(),y.strokeStyle="#1e293b",y.lineWidth=1,y.moveTo(0,qe-.5),y.lineTo(b,qe-.5),y.stroke();for(let S=0;S<r.assignees.length;S++){const k=r.assignees[S],w=qe+S*(we+Re);y.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="left",y.textBaseline="middle",y.fillStyle="#cbd5e1",y.save(),y.beginPath(),y.rect(0,w,Pe-8,we),y.clip(),y.fillText(k,8,w+we/2),y.restore();for(let D=0;D<r.dates.length;D++){const E=r.dates[D],I=`${k}|${ut(E)}`,M=r.cells.get(I),R=(M==null?void 0:M.count)??0,_=Pe+D*(we+Re),H=Tl(R),N=bl(R,r.maxCount);y.globalAlpha=N,y.fillStyle=H,h(y,_,w,we,we,hl),y.fill(),R>=2&&(y.globalAlpha=1,y.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',y.textAlign="center",y.textBaseline="middle",y.fillStyle="#fff",y.fillText(String(R),_+we/2,w+we/2)),y.globalAlpha=1}}d.appendChild(g),g.addEventListener("mousemove",S=>{if(!n)return;const k=g.getBoundingClientRect(),w=S.clientX-k.left,D=S.clientY-k.top,E=Math.floor((w-Pe)/(we+Re)),I=Math.floor((D-qe)/(we+Re));if(E<0||E>=r.dates.length||I<0||I>=r.assignees.length||w<Pe||D<qe){n.classList.remove("ng-visible");return}const M=r.dates[E],R=r.assignees[I],_=`${R}|${ut(M)}`,H=r.cells.get(_);if(!H||H.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const N=document.createElement("div");N.className="ng-heatmap-tooltip-date",N.textContent=`${R} - ${yl(M)}`,n.appendChild(N);for(const W of H.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const P=S.clientX+12,B=S.clientY+12;n.style.left=P+"px",n.style.top=B+"px"}),g.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),g.addEventListener("click",S=>{if(!e)return;const k=g.getBoundingClientRect(),w=S.clientX-k.left,D=S.clientY-k.top,E=Math.floor((w-Pe)/(we+Re)),I=Math.floor((D-qe)/(we+Re));if(E<0||E>=r.dates.length||I<0||I>=r.assignees.length||w<Pe||D<qe)return;const M=r.dates[E],_=`${r.assignees[I]}|${ut(M)}`,H=r.cells.get(_);if(!(!H||H.count===0)){u();for(const N of H.tasks)e.dispatch({type:"SELECT_TASK",taskId:N.id,multi:!0})}})}function h(p,r,d,g,b,T){p.beginPath(),p.moveTo(r+T,d),p.lineTo(r+g-T,d),p.quadraticCurveTo(r+g,d,r+g,d+T),p.lineTo(r+g,d+b-T),p.quadraticCurveTo(r+g,d+b,r+g-T,d+b),p.lineTo(r+T,d+b),p.quadraticCurveTo(r,d+b,r,d+b-T),p.lineTo(r,d+T),p.quadraticCurveTo(r,d,r+T,d),p.closePath()}return{name:"HeatmapViewPlugin",install(p){e=p,vl();const r=p.on("heatmap:toggle",()=>a()),d=p.on("heatmap:show",()=>l()),g=p.on("heatmap:hide",()=>u());i.push(r,d,g)},renderDOM(p,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const d=document.createElement("div");d.className="ng-heatmap-header-bar";const g=document.createElement("span");g.className="ng-heatmap-title",g.textContent="Resource Heatmap",d.appendChild(g);const b=document.createElement("div");b.className="ng-heatmap-legend";const T=[{color:bo,label:"None"},{color:vo,label:"1 task"},{color:wo,label:"2 tasks"},{color:So,label:"3+ tasks"}];for(const y of T){const v=document.createElement("span");v.className="ng-heatmap-legend-swatch",v.style.background=y.color,b.appendChild(v);const m=document.createElement("span");m.textContent=y.label,b.appendChild(m)}d.appendChild(b);const f=document.createElement("button");f.className="ng-heatmap-close",f.textContent="Back to Gantt",f.addEventListener("click",u),d.appendChild(f),t.appendChild(d),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),p.appendChild(t)}s&&c(r)},destroy(){i.forEach(p=>p()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),wl(),e=null,s=!1,o=null}}}const Ze=200,Je=80,Co=12,Io=6,Dl="rgba(255, 255, 255, 0.95)",kl="#cbd5e1",Cl="rgba(59, 130, 246, 0.3)",Il="rgba(59, 130, 246, 0.7)",Ml=1.5,Al=2,Ll=1,On="nimbus-gantt-minimap-styles",Rl=864e5,Pl=`
  .ng-minimap {
    position: absolute;
    bottom: ${Co}px;
    right: ${Co}px;
    width: ${Ze}px;
    height: ${Je}px;
    z-index: 900;
    border-radius: ${Io}px;
    border: 1px solid ${kl};
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
    border-radius: ${Io}px;
  }
`;function _l(){if(typeof document>"u"||document.getElementById(On))return;const e=document.createElement("style");e.id=On,e.textContent=Pl,document.head.appendChild(e)}function $l(){if(typeof document>"u")return;const e=document.getElementById(On);e&&e.remove()}function Ol(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,u=1,c=0,h=0,p=0,r=0;function d(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function g(){o=!0,t&&t.classList.remove("ng-hidden")}function b(){o=!1,t&&t.classList.add("ng-hidden")}function T(S,k){const w=S/l-p/2,D=k/u-r/2;return{x:Math.max(0,Math.min(w,c-p)),y:Math.max(0,Math.min(D,h-r))}}function f(S){if(!e||!n)return;S.preventDefault(),i=!0;const k=n.getBoundingClientRect(),w=S.clientX-k.left,D=S.clientY-k.top,E=T(w,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function y(S){if(!i||!e||!n)return;S.preventDefault();const k=n.getBoundingClientRect(),w=Math.max(0,Math.min(S.clientX-k.left,Ze)),D=Math.max(0,Math.min(S.clientY-k.top,Je)),E=T(w,D);e.dispatch({type:"SET_SCROLL",x:E.x,y:E.y})}function v(){i=!1}function m(S,k){if(!s||!n||!o)return;const w=window.devicePixelRatio||1;n.width=Ze*w,n.height=Je*w,n.style.width=Ze+"px",n.style.height=Je+"px",s.scale(w,w);const{config:D,scrollX:E,scrollY:I,dateRange:M}=S,R=e.getTimeScale(),_=Math.round((M.end.getTime()-M.start.getTime())/Rl),H=R.getColumnWidth();if(c=Math.max(_*H,1),h=Math.max(S.flatVisibleIds.length*D.rowHeight,1),p=c>0?Math.min(c,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const A=t.parentElement;p=A.clientWidth-D.gridWidth,r=A.clientHeight-D.headerHeight}l=Ze/Math.max(c,1),u=Je/Math.max(h,1),s.fillStyle=Dl,s.fillRect(0,0,Ze,Je);const N=new Map;for(const A of k)N.has(A.rowIndex)||N.set(A.rowIndex,[]),N.get(A.rowIndex).push(A);for(const A of k){const O=A.x*l,F=Math.max(A.width*l,1),Q=A.rowIndex*D.rowHeight*u;s.fillStyle=A.color||D.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(O,Q,F,Math.max(Al,D.rowHeight*u-Ll))}s.globalAlpha=1;const P=E*l,B=I*u,W=p*l,K=r*u,q=Math.max(0,Math.min(P,Ze-1)),U=Math.max(0,Math.min(B,Je-1)),C=Math.min(W,Ze-q),$=Math.min(K,Je-U);s.fillStyle=Cl,s.fillRect(q,U,C,$),s.strokeStyle=Il,s.lineWidth=Ml,s.strokeRect(q,U,C,$)}return{name:"MiniMapPlugin",install(S){e=S,_l();const k=S.on("minimap:toggle",()=>d()),w=S.on("minimap:show",()=>g()),D=S.on("minimap:hide",()=>b());a.push(k,w,D),typeof document<"u"&&(document.addEventListener("mousemove",y),document.addEventListener("mouseup",v))},renderDOM(S,k){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",f),t.appendChild(n),S.appendChild(t));const w=(e==null?void 0:e.getLayouts())??[];m(k,w)},destroy(){a.forEach(S=>S()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",y),document.removeEventListener("mouseup",v)),t&&(t.remove(),t=null),n=null,s=null,$l(),e=null,o=!0,i=!1}}}const Nl="#f59e0b",xl=[6,4],Hl=1,tt=16,Bl=4,Fl="rgba(15, 23, 42, 0.95)",Yl="#e2e8f0",Ul="#334155",Wl=6,nt=10,Mo=220,Ao=12,Lo=13;function Xl(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function kt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function zl(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=kt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function Gl(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let u=0;u<l*2;u++){const c=u%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*u,p=t+Math.cos(h)*c,r=n+Math.sin(h)*c;u===0?e.moveTo(p,r):e.lineTo(p,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=kt(o,.25),e.lineWidth=.5,e.stroke()}function Vl(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=kt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function Kl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=kt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function jl(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=kt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const Ro={flag:zl,star:Gl,warning:Vl,info:Kl,deadline:jl};function ql(e,t,n,s,o){e.save();const i=`${Ao}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Lo}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const u=[];let c=0;if(t.description){const T=t.description.split(" ");let f="";for(const y of T){const v=f?f+" "+y:y;e.measureText(v).width>Mo-nt*2&&f?(u.push(f),c=Math.max(c,e.measureText(f).width),f=y):f=v}f&&(u.push(f),c=Math.max(c,e.measureText(f).width))}const h=Math.min(Mo,Math.max(l,c)+nt*2),p=Ao+4,r=Lo+4,d=nt*2+r+(u.length>0?4+u.length*p:0);let g=n-h/2;const b=s-d-8;if(g<4&&(g=4),g+h>o-4&&(g=o-h-4),e.beginPath(),Zl(e,g,b,h,d,Wl),e.fillStyle=Fl,e.fill(),e.strokeStyle=Ul,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Yl,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,g+nt,b+nt),u.length>0){e.font=i,e.fillStyle="#94a3b8";let T=b+nt+r+4;for(const f of u)e.fillText(f,g+nt,T),T+=p}e.restore()}function Zl(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function Jl(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,u=null,c=null;function h(f){return n.find(y=>y.id===f)}function p(f){n.push(f),b()}function r(f){n=n.filter(y=>y.id!==f),b()}function d(f,y){const v=h(f);v&&(Object.assign(v,y),b())}function g(){return[...n]}function b(){if(!t)return;const f=t.getState();t.dispatch({type:"SET_SCROLL",x:f.scrollX,y:f.scrollY})}function T(f){const y=f.canvas;c!==y&&(c&&u&&c.removeEventListener("mousemove",u),c=y,u=v=>{const m=y.getBoundingClientRect();a=v.clientX-m.left,l=v.clientY-m.top;let S=null;for(const k of o){const w=a-k.x,D=l-k.y;if(Math.sqrt(w*w+D*D)<=k.size){S=k.note.id;break}}S!==s&&(s=S,y.style.cursor=s?"pointer":"",b())},y.addEventListener("mousemove",u))}return{name:"TimelineNotesPlugin",install(f){t=f;const y=f.on("notes:add",(...k)=>{const w=k[0];w&&w.id&&w.date&&w.label&&p(w)}),v=f.on("notes:remove",(...k)=>{const w=k[0];w&&r(w)}),m=f.on("notes:update",(...k)=>{const w=k[0];if(w&&w.id){const{id:D,...E}=w;d(D,E)}}),S=f.on("notes:list",(...k)=>{const w=k[0];typeof w=="function"&&w(g())});i.push(y,v,m,S)},renderCanvas(f,y,v){if(!t||n.length===0)return;const{config:m,scrollX:S,scrollY:k,dateRange:w}=y,{theme:D}=m,E=m.headerHeight,I=t.getTimeScale();T(f);const M=f.canvas.width/(window.devicePixelRatio||1),R=f.canvas.height/(window.devicePixelRatio||1),_=E,H=R-_;o=[],f.save();for(const N of n){const P=Xl(N.date);if(P<w.start||P>w.end)continue;const B=N.color||Nl,W=N.icon||"flag",K=I.dateToX(P)-S;if(K<-tt||K>M+tt)continue;f.save(),f.beginPath(),f.setLineDash(xl),f.strokeStyle=B,f.globalAlpha=.5,f.lineWidth=Hl,f.moveTo(K,_),f.lineTo(K,_+H),f.stroke(),f.setLineDash([]),f.globalAlpha=1,f.restore();const q=K,U=_+Bl+tt/2,C=Ro[W]||Ro.flag;f.save(),f.beginPath(),f.arc(q,U,tt/2+3,0,Math.PI*2),f.fillStyle="rgba(0, 0, 0, 0.4)",f.fill(),f.restore(),f.save(),C(f,q,U,tt,B),f.restore(),o.push({note:N,x:q,y:U,size:tt/2+4}),s===N.id&&ql(f,N,q,U-tt/2-4,M)}f.restore()},destroy(){i.forEach(f=>f()),i.length=0,c&&u&&c.removeEventListener("mousemove",u),t=null,c=null,u=null,s=null,o=[]}}}const Ql=500,ec=40,Po=7,_o=3,$o=5,tc=500,Nn="nimbus-gantt-timetravel-styles",Oo={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},nc=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${ec}px;
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
    width: ${Po*2}px;
    height: ${Po*2}px;
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
    width: ${_o*2}px;
    height: ${_o*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${$o*2}px;
    height: ${$o*2}px;
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
`;function sc(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function oc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function ic(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function ac(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function rc(){if(typeof document>"u"||document.getElementById(Nn))return;const e=document.createElement("style");e.id=Nn,e.textContent=nc,document.head.appendChild(e)}function lc(){if(typeof document>"u")return;const e=document.getElementById(Nn);e&&e.remove()}const No=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),Qt=[.5,1,2,4];function cc(e){const t=(e==null?void 0:e.maxSnapshots)??Ql,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,u=null,c=1;const h=[];let p=null,r=null,d=null,g=null,b=null,T=null,f=null,y=!1;function v(U){if(!s||a)return;const C=s.getState(),$=ic(C,U);i<o.length-1&&(o.length=i+1),o.push($),o.length>t&&o.shift(),i=o.length-1}function m(U){if(!s||o.length===0)return;const C=Math.max(0,Math.min(U,o.length-1));i=C;const $=o[C];a=!0;const A=$.tasks.map(F=>({id:F.id,name:F.name,startDate:F.startDate,endDate:F.endDate,progress:F.progress,status:F.status})),O=$.dependencies.map(F=>({id:F.id,source:F.source,target:F.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:O}),a=!1,_()}function S(){o.length>0&&m(o.length-1),w()}function k(){if(l||o.length<=1)return;l=!0;const U=Qt[c],C=tc/U;u=setInterval(()=>{if(i>=o.length-1){w();return}m(i+1)},C),_()}function w(){l=!1,u!==null&&(clearInterval(u),u=null),_()}function D(){l?w():k()}function E(){c=(c+1)%Qt.length,l&&(w(),k()),_()}function I(){w(),i>0&&m(i-1)}function M(){w(),i<o.length-1&&m(i+1)}function R(){w(),o.length=0,i=-1,a=!1,_()}function _(){if(p){if(g){const U=o.length,C=U>0?i+1:0;g.textContent=`${C} / ${U}`}b&&(b.textContent=l?"⏸":"▶",b.classList.toggle("ng-active",l)),T&&(T.textContent=`${Qt[c]}x`),H(),N()}}function H(){if(!d||!r||o.length===0){d&&(d.style.display="none");return}d.style.display="block";const U=o.length<=1?50:i/(o.length-1)*100;d.style.left=`${U}%`}function N(){if(!f||!r||(f.innerHTML="",o.length===0))return;const U=200,C=o.length>U?Math.ceil(o.length/U):1;for(let $=0;$<o.length;$+=C){const A=o[$],O=o.length<=1?50:$/(o.length-1)*100,F=sc(A.action.split(" ")[0]==="Loaded"?"SET_DATA":P(A.action)),Q=Oo[F]||Oo.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${O}%`,Z.style.background=Q;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${ac(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=$;Z.addEventListener("click",me=>{me.stopPropagation(),w(),m(ge)}),f.appendChild(Z)}}function P(U){return U.startsWith("Moved")?"TASK_MOVE":U.startsWith("Resized")?"TASK_RESIZE":U.startsWith("Added task")?"ADD_TASK":U.startsWith("Added dependency")?"ADD_DEPENDENCY":U.startsWith("Removed task")?"REMOVE_TASK":U.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":U.startsWith("Updated")?"UPDATE_TASK":(U.startsWith("Loaded"),"SET_DATA")}function B(U){if(!r||o.length<=1)return;const C=r.getBoundingClientRect(),$=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round($*(o.length-1));w(),m(A)}function W(U){U.preventDefault(),U.stopPropagation(),y=!0,d&&d.classList.add("ng-dragging"),w()}function K(U){if(!y||!r||o.length<=1)return;const C=r.getBoundingClientRect(),$=Math.max(0,Math.min(1,(U.clientX-C.left)/C.width)),A=Math.round($*(o.length-1));m(A)}function q(){y&&(y=!1,d&&d.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(U){s=U,rc(),h.push(U.on("timeTravel:record",()=>{s&&(s.getState(),v("Manual snapshot"))}),U.on("timeTravel:scrub",(...C)=>{const $=C[0];w(),m($)}),U.on("timeTravel:play",()=>k()),U.on("timeTravel:pause",()=>w()),U.on("timeTravel:present",()=>S()),U.on("timeTravel:clear",()=>R()),U.on("timeTravel:history",(...C)=>{const $=C[0];typeof $=="function"&&$([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(U,C){let $="";n&&No.has(U.type)&&s&&!a&&($=oc(U,s.getState())),C(U),n&&No.has(U.type)&&!a&&$&&v($)},renderDOM(U,C){if(!p){p=document.createElement("div"),p.className="ng-timetravel";const $=document.createElement("button");$.className="ng-timetravel-btn",$.textContent="◀",$.title="Step backward",$.addEventListener("click",()=>I()),p.appendChild($),b=document.createElement("button"),b.className="ng-timetravel-btn",b.textContent="▶",b.title="Play / Pause",b.addEventListener("click",()=>D()),p.appendChild(b);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>M()),p.appendChild(A),T=document.createElement("span"),T.className="ng-timetravel-speed ng-timetravel-btn",T.textContent=`${Qt[c]}x`,T.title="Click to cycle speed",T.addEventListener("click",()=>E()),p.appendChild(T),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",B);const O=document.createElement("div");O.className="ng-timetravel-rail",r.appendChild(O),f=document.createElement("div"),f.style.position="absolute",f.style.inset="0",r.appendChild(f),d=document.createElement("div"),d.className="ng-timetravel-playhead",d.addEventListener("mousedown",W),r.appendChild(d),p.appendChild(r),g=document.createElement("span"),g.className="ng-timetravel-counter",p.appendChild(g);const F=document.createElement("button");F.className="ng-timetravel-btn ng-present",F.textContent="Present",F.title="Return to latest state",F.addEventListener("click",()=>S()),p.appendChild(F),U.appendChild(p)}_()},destroy(){w();for(const U of h)U();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),p&&(p.remove(),p=null),r=null,d=null,g=null,b=null,T=null,f=null,lc(),o.length=0,i=-1,a=!1,l=!1,y=!1,s=null}}}const xo=864e5,dc=60,uc=2,Ho=[6,4],xn="nimbus-gantt-montecarlo-styles",Bo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},gc=.08,hc=`
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
`;function Hn(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function en(e,t){return Math.round((t.getTime()-e.getTime())/xo)}function st(e,t){return new Date(e.getTime()+t*xo)}function Fo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Yo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function fc(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function pc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function mc(e,t){return e+Math.random()*(t-e)}function yc(e,t,n,s,o,i,a,l){const u=e.length;if(u===0)return 0;const c=new Float64Array(u),h=new Float64Array(u),p=new Int32Array(l),r=[];for(let b=0;b<u;b++)p[b]===0&&(r.push(b),c[b]=o[b],h[b]=o[b]+s[b]);let d=0;for(;d<r.length;){const b=r[d++],T=h[b],f=i[b];for(let y=0;y<f.length;y++){const v=f[y];T>c[v]&&(c[v]=T,h[v]=T+s[v]),p[v]--,p[v]===0&&r.push(v)}}for(let b=0;b<u;b++)h[b]===0&&s[b]>0&&(c[b]=o[b],h[b]=o[b]+s[b]);let g=0;for(let b=0;b<u;b++)h[b]>g&&(g=h[b]);return g}function Tc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),u=new Float64Array(e),c=new Float64Array(e),h=new Int32Array(i),p=[],r=[];for(let T=0;T<e;T++)h[T]===0&&(r.push(T),a[T]=n[T],l[T]=n[T]+t[T]);let d=0;for(;d<r.length;){const T=r[d++];p.push(T);const f=l[T];for(const y of s[T])f>a[y]&&(a[y]=f,l[y]=f+t[y]),h[y]--,h[y]===0&&r.push(y)}for(let T=0;T<e;T++)l[T]===0&&t[T]>0&&(a[T]=n[T],l[T]=n[T]+t[T],p.push(T));let g=0;for(let T=0;T<e;T++)l[T]>g&&(g=l[T]);for(let T=0;T<e;T++)s[T].length===0?(c[T]=g,u[T]=g-t[T]):(c[T]=1/0,u[T]=1/0);for(let T=p.length-1;T>=0;T--){const f=p[T];if(c[f]===1/0){let y=1/0;for(const v of s[f])u[v]<y&&(y=u[v]);y===1/0?c[f]=g:c[f]=y,u[f]=c[f]-t[f]}}const b=new Set;for(let T=0;T<e;T++){const f=u[T]-a[T];Math.abs(f)<.5&&b.add(T)}return b}function bc(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],u=new Map;for(const O of e.keys())u.set(O,l.length),l.push(O);const c=l.length;if(c===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(c),p=new Float64Array(c);let r=1/0;for(const O of e.values()){const F=Hn(O.startDate).getTime();F<r&&(r=F)}const d=new Date(r);for(let O=0;O<c;O++){const F=e.get(l[O]),Q=Hn(F.startDate),Z=Hn(F.endDate);h[O]=Math.max(en(Q,Z),1),p[O]=en(d,Q)}const g=Array.from({length:c},()=>[]),b=Array.from({length:c},()=>[]),T=new Int32Array(c);for(const O of t.values()){if((O.type||"FS")!=="FS")continue;const Q=u.get(O.source),Z=u.get(O.target);Q===void 0||Z===void 0||(g[Q].push(Z),b[Z].push(Q),T[Z]++)}const f=g.map(O=>new Int32Array(O)),y=b.map(O=>new Int32Array(O)),v=new Float64Array(s),m=new Float64Array(c),S=new Float64Array(c),k=new Float64Array(c),w=new Float64Array(c),D=new Float64Array(c),E=Math.max(1,Math.floor(s/100));for(let O=0;O<s;O++){for(let F=0;F<c;F++){const Q=h[F];let Z;switch(i){case"triangular":{const re=Q*(1-o),ge=Q,me=Q*(1+o*1.5);Z=fc(re,ge,me);break}case"normal":{Z=pc(Q,Q*o);break}case"uniform":{Z=mc(Q*(1-o),Q*(1+o));break}}m[F]=Math.max(.5,Z),S[F]+=m[F],k[F]+=m[F]*m[F],m[F]>h[F]&&w[F]++}if(v[O]=yc(l,u,h,m,p,f,y,T),O%E===0){const F=Tc(c,m,p,f,y,T);for(const Q of F)D[Q]++}}const I=Array.from(v).sort((O,F)=>O-F),M=I.map(O=>st(d,O)),R=new Map;for(const O of a){const F=Math.min(Math.floor(O*I.length),I.length-1);R.set(O,st(d,I[F]))}let _=0;for(let O=0;O<s;O++)_+=I[O];const H=_/s,N=st(d,H),P=Math.floor(s/2),B=st(d,I[P]);let W=0;for(let O=0;O<s;O++){const F=I[O]-H;W+=F*F}const K=Math.sqrt(W/s),q=st(d,I[0]),U=st(d,I[I.length-1]),C=new Map;for(let O=0;O<c;O++){const F=S[O]/s,Q=k[O]/s-F*F;C.set(l[O],{meanDuration:F,stdDev:Math.sqrt(Math.max(0,Q)),delayProbability:w[O]/s})}const $=Math.floor(s/E),A=new Map;for(let O=0;O<c;O++)D[O]>0&&A.set(l[O],D[O]/$);return{iterations:s,finishDates:M,percentiles:R,meanFinishDate:N,medianFinishDate:B,earliestFinish:q,latestFinish:U,standardDeviation:K,taskRisk:C,criticalPathFrequency:A}}function vc(){if(typeof document>"u"||document.getElementById(xn))return;const e=document.createElement("style");e.id=xn,e.textContent=hc,document.head.appendChild(e)}function wc(){if(typeof document>"u")return;const e=document.getElementById(xn);e&&e.remove()}function Sc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const d={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},g=n.getState();s=bc(g.tasks,g.dependencies,d),h()}function u(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function c(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",d=0;for(const[f,y]of s.criticalPathFrequency)y>d&&(d=y,r=f);let g=r;if(n){const f=n.getState().tasks.get(r);f&&(g=f.name)}let b=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const f of t.confidenceLevels){const y=s.percentiles.get(f);if(!y)continue;const v=Math.round(f*100),m=Bo[f]||"#94A3B8";b+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${v}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${Yo(y)}</span>
        </div>
      `}if(b+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${Yo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&d>0){const f=Math.round(d*100);b+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${g} (on critical path ${f}% of runs)
        </div>
      `}a.innerHTML=b;const T=a.querySelector(".ng-montecarlo-close");T&&T.addEventListener("click",()=>u())}function p(r,d){if(!s||!n||s.finishDates.length===0)return;const g=n.getTimeScale(),{headerHeight:b}=d.config,T=d.scrollX,f=r.canvas.width/(window.devicePixelRatio||1),y=r.canvas.height/(window.devicePixelRatio||1),v=b,m=y-v,S=s.earliestFinish,k=s.latestFinish,w=Math.max(en(S,k),1),D=g.getColumnWidth(),E=Math.max(D,uc),I=Math.max(Math.ceil(w),1),M=new Uint32Array(I);for(const P of s.finishDates){const B=en(S,P),W=Math.min(Math.max(Math.floor(B),0),I-1);M[W]++}let R=0;for(let P=0;P<I;P++)M[P]>R&&(R=M[P]);if(R===0)return;r.save(),r.beginPath(),r.rect(0,v,f,m),r.clip(),r.translate(-T,0);const _=s.finishDates[Math.floor(s.finishDates.length*.1)],H=s.finishDates[Math.floor(s.finishDates.length*.9)];if(_&&H){const P=g.dateToX(_),B=g.dateToX(H),W=r.createLinearGradient(P,0,B,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=gc*5,r.fillRect(P,v,B-P,m),r.globalAlpha=1}const N=y-8;for(let P=0;P<I;P++){if(M[P]===0)continue;const B=st(S,P),W=g.dateToX(B),K=M[P]/R*dc,q=I>1?P/(I-1):.5;let U,C,$;if(q<.5){const A=q*2;U=Math.round(34+200*A),C=Math.round(197+-18*A),$=Math.round(94+-86*A)}else{const A=(q-.5)*2;U=Math.round(234+5*A),C=Math.round(179+-111*A),$=Math.round(8+60*A)}r.fillStyle=`rgba(${U}, ${C}, ${$}, 0.6)`,r.fillRect(W,N-K,Math.max(E-1,1),K)}r.setLineDash(Ho),r.lineWidth=1.5;for(const[P,B]of s.percentiles){const W=g.dateToX(B),K=Bo[P]||"#94A3B8",q=`P${Math.round(P*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,v),r.lineTo(W,y),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const U=r.measureText(`${q}: ${Fo(B)}`).width,C=`${q}: ${Fo(B)}`,$=U+8,A=16,O=W-$/2,F=v+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(O+3,F),r.lineTo(O+$-3,F),r.arcTo(O+$,F,O+$,F+3,3),r.lineTo(O+$,F+A-3),r.arcTo(O+$,F+A,O+$-3,F+A,3),r.lineTo(O+3,F+A),r.arcTo(O,F+A,O,F+A-3,3),r.lineTo(O,F+3),r.arcTo(O,F,O+3,F,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(C,W,F+3),r.setLineDash(Ho)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,vc(),i.push(r.on("montecarlo:run",(...d)=>{const g=d[0];l(g)}),r.on("montecarlo:result",(...d)=>{const g=d[0];typeof g=="function"&&g(s)}),r.on("montecarlo:toggle-overlay",()=>u()),r.on("montecarlo:configure",(...d)=>{const g=d[0];g&&c(g)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,d){d(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,d,g){!o||!s||p(r,d)},renderDOM(r,d){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),wc(),s=null,n=null}}}const tn=864e5,Uo=400,Bn="nimbus-gantt-narrative-styles",Wo=300;function Ue(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Fn(e,t){return Math.round((t.getTime()-e.getTime())/tn)}function Xo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function zo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*tn)}function Go(e,t){return new Date(e.getTime()+t*tn)}function Ec(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const E of n){const I=Ue(E.startDate).getTime(),M=Ue(E.endDate).getTime();I<s&&(s=I),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=Fn(i,a),u=new Date;u.setUTCHours(0,0,0,0);const c=new Map,h=new Map;for(const E of t.values())!e.has(E.source)||!e.has(E.target)||(c.has(E.source)||c.set(E.source,[]),c.get(E.source).push(E.target),h.has(E.target)||h.set(E.target,[]),h.get(E.target).push(E.source));const p=Ic(n,t),r=zo(i),d=zo(a),g=[];let b=r;for(;b.getTime()<=d.getTime();)g.push({start:new Date(b),end:Go(b,6)}),b=Go(b,7);const T=[];for(let E=0;E<g.length;E++){const I=g[E],M=I.start,R=I.end,_=[],H=[],N=[],P=[],B=[],W=[],K=[];for(const A of n){const O=Ue(A.startDate),F=Ue(A.endDate);O>=M&&O<=R&&(_.push(A),A.isMilestone?(W.push(A),K.push(`Milestone: ${A.name}`)):K.push(`Started: ${A.name}`)),F>=M&&F<=R&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(H.push(A),K.push(`Completed: ${A.name}`)),O<=R&&F>=M&&(B.push(A),O<M&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&N.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&P.push(A))}for(const A of n)if(A.isMilestone){const O=Ue(A.startDate);O>=M&&O<=R&&!W.includes(A)&&(W.push(A),K.push(`Milestone: ${A.name}`))}const q=B.filter(A=>p.has(A.id)),U=Dc(_,H,N,B,q),C=kc(_,H,N,P,B,q,W,c,e),$=`Week ${E+1} (${Xo(M)}–${Xo(R)})`;T.push({weekLabel:$,headline:U,body:C,metrics:{started:_.length,completed:H.length,delayed:N.length,onTrack:P.length},events:K})}const f=n.length,y=n.filter(E=>E.isCompleted||E.progress!==void 0&&E.progress>=1).length,v=n.filter(E=>!E.isCompleted&&E.progress!==void 0&&E.progress>0&&E.progress<1).length,m=f-y-v,S=f>0?Math.round(y/f*100):0,k=S>=75?"strong":S>=50?"moderate":S>=25?"early-stage":"just getting started",w=`This project spans ${l} days across ${g.length} weeks with ${f} tasks. Progress is ${k} at ${S}% completion (${y} done, ${v} in progress, ${m} not started).`,D=Cc(n,p,c,h,i,a,u);return{title:"Project Narrative",generatedAt:Date.now(),summary:w,chapters:T,insights:D}}function Dc(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function kc(e,t,n,s,o,i,a,l,u){const c=[];if(e.length>0)if(e.length<=3){const r=e.map(d=>d.name).join(", ");c.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(d=>d.name).join(", ");c.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(d=>d.name).join(", ");c.push(`${r} ${t.length===1?"was":"were"} completed.`)}else c.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&c.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(d=>d.name).join(", ");c.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const d=n.map(g=>g.name).join(", ");c.push(`${d} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else c.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const d of n){const g=l.get(d.id);if(g)for(const b of g){const T=u.get(b);T&&!r.includes(T.name)&&r.push(T.name)}}if(r.length>0){const d=r.slice(0,3).join(", ");c.push(`This puts downstream work at risk, including ${d}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&c.length<4){const r=i.slice(0,2).map(d=>d.name).join(" and ");c.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const p=Array.from(h.entries()).sort((r,d)=>d[1]-r[1]);return p.length>0&&p[0][1]>=3&&c.push(`${p[0][0]} is carrying a heavy load with ${p[0][1]} concurrent tasks.`),c.length===0&&c.push("No significant activity scheduled for this week."),c.join(" ")}function Cc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const T=e.filter(v=>t.has(v.id)),f=T.slice(0,4).map(v=>v.name).join(", "),y=T.length>4?` and ${T.length-4} more`:"";l.push(`The critical path runs through ${f}${y} — any delay here pushes the project finish.`)}const u=new Map;for(const T of e)T.assignee&&!T.isCompleted&&u.set(T.assignee,(u.get(T.assignee)||0)+1);const c=Array.from(u.entries()).sort((T,f)=>f[1]-T[1]);c.length>0&&c[0][1]>=2&&l.push(`${c[0][0]} is carrying the heaviest load with ${c[0][1]} concurrent tasks.`);const h=e.filter(T=>T.isCompleted?!1:Ue(T.startDate)<a&&(T.progress===void 0||T.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const p=Fn(o,i),r=Fn(o,a);if(r>0&&p>0){const T=Math.round(r/p*100),f=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,y=Math.round(f/e.length*100),v=y-T;Math.abs(v)>=5?v>0?l.push(`Project is running ahead: ${y}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is running behind: only ${y}% of tasks completed with ${T}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${y}% complete at ${T}% of elapsed time.`)}const d=e.filter(T=>{if(T.isCompleted||T.progress!==void 0&&T.progress>0)return!1;const f=s.get(T.id);return!f||f.length===0});d.length>0&&d.length<=e.length*.5&&l.push(`${d.length} task${d.length>1?"s are":" is"} unblocked and ready to start.`);let g=0,b="";for(const T of e){const f=n.get(T.id);f&&f.length>g&&(g=f.length,b=T.name)}return g>=3&&l.push(`"${b}" is a bottleneck with ${g} downstream tasks depending on it.`),l}function Ic(e,t){const n=new Map;for(const d of e)n.set(d.id,d);const s=new Map,o=new Map;for(const d of e)s.set(d.id,[]),o.set(d.id,0);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||(s.get(d.source).push({target:d.target,lag:d.lag||0}),o.set(d.target,(o.get(d.target)||0)+1)));const i=new Map,a=[];for(const d of e)o.get(d.id)===0&&a.push(d.id);for(const d of e){const g=Ue(d.endDate).getTime();i.set(d.id,g)}const l=new Map(o);for(;a.length>0;){const d=a.shift(),g=i.get(d);for(const b of s.get(d)){const T=n.get(b.target),f=Ue(T.endDate).getTime()-Ue(T.startDate).getTime(),y=g+b.lag*tn+f;y>i.get(b.target)&&i.set(b.target,y);const v=l.get(b.target)-1;l.set(b.target,v),v===0&&a.push(b.target)}}let u=-1/0,c="";for(const[d,g]of i)g>u&&(u=g,c=d);if(!c)return new Set;const h=new Set,p=new Map;for(const d of e)p.set(d.id,[]);for(const d of t.values())(d.type||"FS")==="FS"&&(!n.has(d.source)||!n.has(d.target)||p.get(d.target).push({source:d.source,lag:d.lag||0}));let r=c;for(;r;){h.add(r);const d=p.get(r);if(!d||d.length===0)break;let g="",b=-1/0;for(const T of d){const f=i.get(T.source)||0;f>b&&(b=f,g=T.source)}if(!g||h.has(g))break;r=g}return h}const Mc=`
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
    transition: opacity ${Wo}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Uo}px;
    width: ${Uo}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${Wo}ms ease;
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
`;function Ac(){if(typeof document>"u"||document.getElementById(Bn))return;const e=document.createElement("style");e.id=Bn,e.textContent=Mc,document.head.appendChild(e)}function Lc(){if(typeof document>"u")return;const e=document.getElementById(Bn);e&&e.remove()}function Rc(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Pc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=Ec(r.tasks,r.dependencies)}function u(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function c(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const d=document.createElement("div");d.className="ng-narrative-header-left";const g=document.createElement("span");g.textContent="📖",d.appendChild(g);const b=document.createElement("span");b.textContent="Project Story",d.appendChild(b),r.appendChild(d);const T=document.createElement("div");T.style.display="flex",T.style.alignItems="center",T.style.gap="4px";const f=document.createElement("button");f.className="ng-narrative-refresh",f.innerHTML="↻",f.title="Regenerate",f.addEventListener("click",()=>{l(),h()}),T.appendChild(f);const y=document.createElement("button");y.className="ng-narrative-close",y.innerHTML="×",y.addEventListener("click",c),T.appendChild(y),r.appendChild(T),a.appendChild(r);const v=document.createElement("div");if(v.className="ng-narrative-summary",v.textContent=t.summary,a.appendChild(v),t.chapters.length===0){const k=document.createElement("div");k.className="ng-narrative-empty",k.textContent="No weekly chapters to display.",a.appendChild(k)}else for(const k of t.chapters){const w=document.createElement("div");w.className="ng-narrative-chapter";const D=Rc(k),E=document.createElement("div");E.className=`ng-narrative-chapter-header ng-${D}`;const I=document.createElement("div");I.className="ng-narrative-week-label",I.textContent=k.weekLabel,E.appendChild(I);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=k.headline,E.appendChild(M),w.appendChild(E);const R=document.createElement("div");if(R.className="ng-narrative-metrics",k.metrics.started>0&&R.appendChild(p("started",`${k.metrics.started} started`)),k.metrics.completed>0&&R.appendChild(p("completed",`${k.metrics.completed} done`)),k.metrics.delayed>0&&R.appendChild(p("delayed",`${k.metrics.delayed} delayed`)),k.metrics.onTrack>0&&R.appendChild(p("ontrack",`${k.metrics.onTrack} on track`)),R.children.length>0&&w.appendChild(R),k.body){const _=document.createElement("div");_.className="ng-narrative-body",_.textContent=k.body,w.appendChild(_)}a.appendChild(w)}if(t.insights.length>0){const k=document.createElement("div");k.className="ng-narrative-insights";const w=document.createElement("div");w.className="ng-narrative-insights-title",w.innerHTML="<span>💡</span> Key Insights",k.appendChild(w);for(const D of t.insights){const E=document.createElement("div");E.className="ng-narrative-insight";const I=document.createElement("span");I.className="ng-narrative-insight-icon",I.textContent="•",E.appendChild(I);const M=document.createElement("span");M.textContent=D,E.appendChild(M),k.appendChild(E)}a.appendChild(k)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const S=new Date(t.generatedAt);m.textContent=`Generated ${S.toLocaleString()}`,a.appendChild(m)}function p(r,d){const g=document.createElement("span");return g.className=`ng-narrative-badge ng-${r}`,g.textContent=d,g}return{name:"NarrativePlugin",install(r){e=r,Ac(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>u()),r.on("narrative:hide",()=>c()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,d){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?c():u()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",c),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),Lc(),e=null,t=null,n=!1}}}const _c=864e5,$c=10,Yn="nimbus-gantt-whatif-styles",Vo=.25,Oc=.6,nn=6,Ko="#38A169",jo="#E53E3E",qo="#A0AEC0",Un=36,Nc="#F6AD55",Zo="#1a202c",xc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Un}px;
    background: ${Nc};
    color: ${Zo};
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
    color: ${Zo};
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
    top: ${Un}px;
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
    top: ${Un+8}px;
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
    color: ${Ko};
  }
  .ng-whatif-summary-value--worsened {
    color: ${jo};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${qo};
  }
`;function We(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Jo(e){const t=We(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function sn(e,t){return Math.round((t.getTime()-e.getTime())/_c)}function Qo(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function Hc(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function Bc(e){return{...e}}function Fc(){if(typeof document>"u"||document.getElementById(Yn))return;const e=document.createElement("style");e.id=Yn,e.textContent=xc,document.head.appendChild(e)}function Yc(){if(typeof document>"u")return;const e=document.getElementById(Yn);e&&e.remove()}function Uc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,Hc(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,Bc(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function ei(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function Wc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let u=null,c=null,h=null,p=null,r=null,d=null,g=null;function b(){t||!e||(o=Uc(e.getState()),i=[],t=!0,n=!1,D())}function T(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],D(),M(),_())}function f(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,E(),M())}function y(C){if(!t||!e||!o)return;a.length>=$c&&a.shift();const $=e.getState(),A=ei($.tasks),O=We(o.projectFinish),F=We(A),Q=sn(O,F);let Z=0;for(const[ge,me]of o.tasks){const Y=$.tasks.get(ge);if(!Y){Z++;continue}(Y.startDate!==me.startDate||Y.endDate!==me.endDate||Y.assignee!==me.assignee)&&Z++}for(const ge of $.tasks.keys())o.tasks.has(ge)||Z++;const re={id:Qo(),name:C,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:Q,tasksAffected:Z}};a.push(re),B()}function v(C){if(!e||!o)return;const $=a.find(A=>A.id===C);if($){t||b(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of $.changes)S(A);i=[...$.changes],E()}}function m(C){a=a.filter($=>$.id!==C),B()}function S(C){if(e)switch(C.type){case"move":case"resize":C.taskId&&C.after&&C.after.startDate&&C.after.endDate&&e.dispatch({type:C.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:C.taskId,startDate:C.after.startDate,endDate:C.after.endDate});break;case"add":C.after&&e.dispatch({type:"ADD_TASK",task:C.after});break;case"remove":C.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:C.taskId});break;case"reassign":C.taskId&&C.after&&e.dispatch({type:"UPDATE_TASK",taskId:C.taskId,changes:C.after});break;case"add-dependency":C.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:C.dependencyId||Qo(),source:C.dependency.source,target:C.dependency.target,type:C.dependency.type||"FS"}});break;case"remove-dependency":C.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:C.dependencyId});break}}function k(){t&&(n=!n,n?I():M())}function w(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const C=e.getState(),$=ei(C.tasks),A=We(o.projectFinish),O=We($),F=sn(A,O);let Q=0;for(const[Z,re]of o.tasks){const ge=C.tasks.get(Z);if(!ge){Q++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&Q++}for(const Z of C.tasks.keys())o.tasks.has(Z)||Q++;return{baselineFinish:o.projectFinish,sandboxFinish:$,deltaDays:F,tasksAffected:Q}}function D(){u&&u.classList.toggle("ng-hidden",!t)}function E(){p&&(p.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function I(){if(!h)return;const C=w();let $="ng-whatif-summary-value--unchanged",A="No change";C.deltaDays<0?($="ng-whatif-summary-value--improved",A=`${Math.abs(C.deltaDays)} day${Math.abs(C.deltaDays)!==1?"s":""} earlier`):C.deltaDays>0&&($="ng-whatif-summary-value--worsened",A=`${C.deltaDays} day${C.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${Jo(C.baselineFinish)} &rarr; ${Jo(C.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${$}">${A}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${C.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function R(){s=!s,c&&c.classList.toggle("ng-open",s),s&&B()}function _(){s=!1,c&&c.classList.remove("ng-open")}function H(){r&&(r.classList.add("ng-active"),d==null||d.focus())}function N(){r&&r.classList.remove("ng-active"),d&&(d.value="")}function P(){if(!d)return;const C=d.value.trim();C&&(y(C),N())}function B(){if(g){if(a.length===0){g.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}g.innerHTML=a.map(C=>{var F;const $=new Date(C.createdAt).toLocaleDateString(),A=((F=C.result)==null?void 0:F.criticalPathDelta)??0;let O="No impact";return A<0?O=`${Math.abs(A)}d earlier`:A>0&&(O=`${A}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${C.id}">
            <div class="ng-whatif-scenario-name">${W(C.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${$}</span>
              <span>${C.changes.length} changes</span>
              <span>${O}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${C.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${C.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${C.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(C){const $=document.createElement("div");return $.textContent=C,$.innerHTML}function K(C){const $=C.target,A=$.getAttribute("data-action"),O=$.getAttribute("data-id");if(!(!A||!O))switch(A){case"load":v(O),_();break;case"compare":v(O),n=!0,I(),_();break;case"delete":m(O);break}}function q(C,$){switch(C.type){case"TASK_MOVE":{const A=$.tasks.get(C.taskId);A&&i.push({type:"move",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"TASK_RESIZE":{const A=$.tasks.get(C.taskId);A&&i.push({type:"resize",taskId:C.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:C.startDate,endDate:C.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:C.task.id,after:{...C.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:C.taskId,before:$.tasks.get(C.taskId)?{...$.tasks.get(C.taskId)}:void 0});break;case"UPDATE_TASK":{const A=$.tasks.get(C.taskId);A&&i.push({type:"reassign",taskId:C.taskId,before:{...A},after:C.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:C.dependency.id,dependency:{source:C.dependency.source,target:C.dependency.target,type:C.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:C.dependencyId});break}E()}function U(C,$,A,O,F,Q){const Z=Math.min(Q,O/2,F/2);C.beginPath(),C.moveTo($+Z,A),C.lineTo($+O-Z,A),C.arcTo($+O,A,$+O,A+Z,Z),C.lineTo($+O,A+F-Z),C.arcTo($+O,A+F,$+O-Z,A+F,Z),C.lineTo($+Z,A+F),C.arcTo($,A+F,$,A+F-Z,Z),C.lineTo($,A+Z),C.arcTo($,A,$+Z,A,Z),C.closePath()}return{name:"WhatIfPlugin",install(C){e=C,Fc(),l.push(C.on("whatif:enter",()=>b())),l.push(C.on("whatif:exit",()=>T())),l.push(C.on("whatif:compare",()=>k())),l.push(C.on("whatif:discard",()=>f())),l.push(C.on("whatif:save",(...$)=>{const A=typeof $[0]=="string"?$[0]:void 0;A?y(A):H()})),l.push(C.on("whatif:load",(...$)=>{const A=typeof $[0]=="string"?$[0]:void 0;A?v(A):R()})),l.push(C.on("whatif:list-scenarios",(...$)=>{const A=typeof $[0]=="function"?$[0]:void 0;A?A([...a]):R()})),l.push(C.on("whatif:delete-scenario",(...$)=>{const A=typeof $[0]=="string"?$[0]:void 0;A&&m(A)}))},middleware(C,$){if(!t){$(C);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(C.type)&&e){const O=e.getState();q(C,O)}$(C)},renderCanvas(C,$,A){if(!t||!e)return;const{theme:O,headerHeight:F,barHeight:Q}=$.config,Z=$.scrollX,re=$.scrollY,ge=F,me=e.getTimeScale(),Y=O.barBorderRadius;if(C.save(),C.beginPath(),C.rect(0,ge,C.canvas.width,C.canvas.height-ge),C.clip(),C.translate(-Z,0),o){const ee=new Set;for(const j of A){const J=o.tasks.get(j.taskId),se=$.tasks.get(j.taskId);(!J&&se||J&&se&&(J.startDate!==se.startDate||J.endDate!==se.endDate||J.assignee!==se.assignee))&&ee.add(j.taskId)}for(const j of A){if(!ee.has(j.taskId))continue;const J=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>C.canvas.height||(C.save(),C.setLineDash([4,3]),C.strokeStyle="#F6AD55",C.lineWidth=2,U(C,J,se,de,ie,Y),C.stroke(),C.restore())}}if(n&&o){const ee=Q*Oc;for(const j of A){if(j.isMilestone)continue;const J=o.tasks.get(j.taskId);if(!J)continue;const se=$.tasks.get(j.taskId);if(!se)continue;const de=We(J.startDate),ie=We(J.endDate),fe=We(se.startDate),ce=We(se.endDate),ye=sn(de,fe),Te=sn(ie,ce);if(ye===0&&Te===0)continue;let X=qo;Te<0?X=Ko:Te>0&&(X=jo);const L=me.dateToX(de),x=me.dateToX(ie),z=Math.max(x-L,2),G=j.barY-re,V=G+Q+2;C.save(),C.globalAlpha=Vo,C.fillStyle=X,U(C,L,V,z,ee,Y),C.fill(),C.globalAlpha=Vo*2,C.strokeStyle=X,C.lineWidth=1,C.stroke(),C.restore();const te=L+z/2,oe=V+ee/2,ae=j.x+j.width/2,le=G+Q/2;C.save(),C.globalAlpha=.6,C.strokeStyle=X,C.lineWidth=1.5,C.setLineDash([3,2]),C.beginPath(),C.moveTo(te,oe),C.lineTo(ae,le),C.stroke();const pe=Math.atan2(le-oe,ae-te),be=ae,Ce=le;C.setLineDash([]),C.beginPath(),C.moveTo(be,Ce),C.lineTo(be-nn*Math.cos(pe-Math.PI/6),Ce-nn*Math.sin(pe-Math.PI/6)),C.lineTo(be-nn*Math.cos(pe+Math.PI/6),Ce-nn*Math.sin(pe+Math.PI/6)),C.closePath(),C.fillStyle=X,C.fill(),C.restore()}}C.restore()},renderDOM(C,$){if(!u){u=document.createElement("div"),u.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const O=document.createElement("span");O.className="ng-whatif-badge",O.textContent="What-If Mode",A.appendChild(O);const F=document.createElement("span");F.textContent="Changes are hypothetical",F.style.fontSize="12px",F.style.opacity="0.7",A.appendChild(F);const Q=document.createElement("span");Q.textContent="·",Q.style.opacity="0.4",A.appendChild(Q),p=document.createElement("span"),p.className="ng-whatif-change-count",p.textContent="0 changes made",A.appendChild(p),u.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",d=document.createElement("input"),d.type="text",d.placeholder="Scenario name...",d.addEventListener("keydown",se=>{se.key==="Enter"&&P(),se.key==="Escape"&&N()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",P);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>N()),r.appendChild(d),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const me=document.createElement("button");me.className="ng-whatif-btn",me.textContent="Scenarios",me.addEventListener("click",()=>R()),Z.appendChild(me);const Y=document.createElement("button");Y.className="ng-whatif-btn ng-whatif-btn--primary",Y.textContent="Compare with Baseline",Y.addEventListener("click",()=>k()),Z.appendChild(Y);const ee=document.createElement("button");ee.className="ng-whatif-btn",ee.textContent="Save Scenario",ee.addEventListener("click",()=>H()),Z.appendChild(ee);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>f()),Z.appendChild(j);const J=document.createElement("button");J.className="ng-whatif-btn ng-whatif-btn--danger",J.textContent="Exit",J.addEventListener("click",()=>T()),Z.appendChild(J),u.appendChild(Z),C.appendChild(u)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",C.appendChild(h)),!c){c=document.createElement("div"),c.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const O=document.createElement("span");O.textContent="Saved Scenarios",A.appendChild(O);const F=document.createElement("button");F.className="ng-whatif-panel-close",F.textContent="×",F.addEventListener("click",()=>_()),A.appendChild(F),c.appendChild(A),g=document.createElement("div"),g.addEventListener("click",K),c.appendChild(g),C.appendChild(c),B()}D(),n&&I()},destroy(){for(const C of l)C();l.length=0,u&&(u.remove(),u=null),c&&(c.remove(),c=null),h&&(h.remove(),h=null),p=null,r=null,d=null,g=null,Yc(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Wn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},Xc=261.63;function zc(e){return Xc*Math.pow(2,e/12)}function Gc(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return zc(n?a+12:a)}const Xn="nimbus-gantt-sonification-styles",zn=64,on=64,ti=.05,Vc=.1,Kc=.7,ni=.2,Gn="#F6AD55",jc=2,qc="rgba(246, 173, 85, 0.35)",si=12,Zc=`
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
    height: ${zn}px;
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
`;function Vn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Jc(){if(typeof document>"u"||document.getElementById(Xn))return;const e=document.createElement("style");e.id=Xn,e.textContent=Zc,document.head.appendChild(e)}function Qc(){if(typeof document>"u")return;const e=document.getElementById(Xn);e&&e.remove()}function ed(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,u=null,c=null,h=null;const p=new Map;let r="stopped",d=0,g=0,b=0,T=0,f=0,y=0,v=0,m=null,S=null,k=null,w=null,D=null,E=null;const I=[];let M=[],R=[];function _(){if(l)return;const Y=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;Y&&(l=new Y,u=l.createGain(),u.gain.value=i,c=l.createAnalyser(),c.fftSize=256,h=new Uint8Array(c.frequencyBinCount),u.connect(c),c.connect(l.destination))}function H(){l&&l.state==="suspended"&&l.resume()}function N(){if(!a)return;const Y=a.getState(),ee=Date.now();let j=1/0,J=-1/0;const se=[],de=new Set,ie=Y.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,ye]of Y.tasks){const Te=Vn(ye.startDate).getTime(),X=Vn(ye.endDate).getTime();Te<j&&(j=Te),X>J&&(J=X);const L=ye.groupId||"__default__";de.add(L);const x=fe.get(ce)??0,z=!ye.isCompleted&&X<ee&&(ye.progress??0)<1;se.push({id:ce,startMs:Te,endMs:X,rowIndex:x,progress:ye.progress??0,groupId:L,isCritical:!1,isOverdue:z})}M=se,R=Array.from(de),f=j===1/0?0:j,y=J===-1/0?0:J,v=Math.max(y-f,1)}function P(Y){if(!l||!u||p.has(Y.id))return;const ee=Wn[n]||Wn.major,j=Gc(Y.rowIndex,ee,Y.isCritical),J=l.createOscillator();J.type=s,J.frequency.value=j,Y.isOverdue&&(J.detune.value=25);const se=.3+Y.progress*.7,de=Y.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+ti),fe.gain.linearRampToValueAtTime(ie*Kc,l.currentTime+ti+Vc);const ce=l.createStereoPanner();if(R.length<=1)ce.pan.value=0;else{const ye=R.indexOf(Y.groupId);ce.pan.value=R.length>1?ye/(R.length-1)*2-1:0}J.connect(fe),fe.connect(ce),ce.connect(u),J.start(),p.set(Y.id,{taskId:Y.id,oscillator:J,gainNode:fe,panNode:ce})}function B(Y){const ee=p.get(Y);if(!ee||!l)return;const j=l.currentTime;ee.gainNode.gain.cancelScheduledValues(j),ee.gainNode.gain.setValueAtTime(ee.gainNode.gain.value,j),ee.gainNode.gain.linearRampToValueAtTime(0,j+ni),ee.oscillator.stop(j+ni+.05),p.delete(Y)}function W(){for(const Y of Array.from(p.keys()))B(Y)}function K(){if(r!=="playing"||!l)return;const Y=l.currentTime-d;if(g=Math.min(Y/o,1),g>=1){C();return}const ee=f+g*v;for(const j of M){const J=ee>=j.startMs&&ee<j.endMs,se=p.has(j.id);J&&!se?P(j):!J&&se&&B(j.id)}Z(),T=requestAnimationFrame(K)}function q(){_(),H(),l&&(N(),r==="paused"?d=l.currentTime-b*o:(d=l.currentTime,g=0),r="playing",O(),F(),T=requestAnimationFrame(K))}function U(){r==="playing"&&(r="paused",b=g,W(),cancelAnimationFrame(T),O())}function C(){r="stopped",g=0,b=0,W(),cancelAnimationFrame(T),O(),Q()}function $(){r==="playing"?U():q()}function A(Y){const ee=Vn(Y).getTime(),j=Math.max(0,Math.min((ee-f)/v,1));r==="playing"&&l?d=l.currentTime-j*o:(b=j,g=j)}function O(){D&&(r==="playing"?(D.innerHTML=ge(),D.classList.add("ng-son-btn--active")):(D.innerHTML=re(),D.classList.remove("ng-son-btn--active")))}function F(){S&&S.classList.remove("ng-hidden")}function Q(){S&&S.classList.add("ng-hidden")}function Z(){if(!c||!h||!w||!k)return;c.getByteFrequencyData(h);const Y=k.width,ee=k.height;w.clearRect(0,0,Y,ee);const j=w.createLinearGradient(0,0,0,ee);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),w.fillStyle=j,w.fillRect(0,0,Y,ee);const J=Y/on*.8,se=Y/on*.2,de=Math.floor(h.length/on);for(let ie=0;ie<on;ie++){let fe=0;for(let z=0;z<de;z++)fe+=h[ie*de+z]??0;const ce=fe/de,ye=ce/255*ee*.85,Te=ie*(J+se),X=ee-ye,L=30+ce/255*15,x=55+ce/255*15;w.fillStyle=`hsl(${L}, 90%, ${x}%)`,w.fillRect(Te,X,J,ye)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function me(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(Y){a=Y,Jc(),I.push(Y.on("sonification:play",()=>q())),I.push(Y.on("sonification:pause",()=>U())),I.push(Y.on("sonification:stop",()=>C())),I.push(Y.on("sonification:scrub",(...ee)=>{const j=typeof ee[0]=="string"?ee[0]:void 0;j&&A(j)})),I.push(Y.on("sonification:configure",(...ee)=>{const j=ee[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,u&&(u.gain.value=i)))}))},renderCanvas(Y,ee,j){if(r==="stopped"||!a)return;const{headerHeight:J}=ee.config,se=ee.scrollX,de=ee.scrollY,ie=J,fe=a.getTimeScale(),ce=f+g*v,ye=new Date(ce),Te=fe.dateToX(ye);Y.save(),Y.beginPath(),Y.rect(0,ie,Y.canvas.width,Y.canvas.height-ie),Y.clip(),Y.translate(-se,0),Y.save(),Y.shadowColor=Gn,Y.shadowBlur=si,Y.strokeStyle=Gn,Y.lineWidth=jc,Y.beginPath(),Y.moveTo(Te,ie),Y.lineTo(Te,Y.canvas.height+de),Y.stroke(),Y.restore();const X=new Map;for(const L of j)X.set(L.taskId,L);for(const L of p.values()){const x=X.get(L.taskId);if(!x)continue;const z=x.x,G=x.barY-de,V=x.width,te=x.barHeight;if(G+te<ie||G>Y.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);Y.save(),Y.globalAlpha=ae,Y.shadowColor=qc,Y.shadowBlur=si,Y.fillStyle=Gn;const le=Math.min(ee.config.theme.barBorderRadius,V/2,te/2);Y.beginPath(),Y.moveTo(z+le,G),Y.lineTo(z+V-le,G),Y.arcTo(z+V,G,z+V,G+le,le),Y.lineTo(z+V,G+te-le),Y.arcTo(z+V,G+te,z+V-le,G+te,le),Y.lineTo(z+le,G+te),Y.arcTo(z,G+te,z,G+te-le,le),Y.lineTo(z,G+le),Y.arcTo(z,G,z+le,G,le),Y.closePath(),Y.fill(),Y.restore()}Y.restore()},renderDOM(Y,ee){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=re(),D.title="Play / Pause",D.addEventListener("click",()=>$()),m.appendChild(D),E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=me(),E.title="Stop",E.addEventListener("click",()=>C()),m.appendChild(E);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const J=document.createElement("div");J.style.display="flex",J.style.flexDirection="column",J.style.alignItems="center",J.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",J.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),J.appendChild(de),m.appendChild(J);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const x of Object.keys(Wn)){const z=document.createElement("option");z.value=x,z.textContent=x.charAt(0).toUpperCase()+x.slice(1),x===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const ye=document.createElement("div");ye.className="ng-son-sep",m.appendChild(ye);const Te=document.createElement("div");Te.style.display="flex",Te.style.flexDirection="column",Te.style.alignItems="center",Te.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",Te.appendChild(X);const L=document.createElement("input");L.type="range",L.className="ng-son-slider",L.min="0",L.max="100",L.value=String(Math.round(i*100)),L.addEventListener("input",()=>{i=Number(L.value)/100,u&&(u.gain.value=i)}),Te.appendChild(L),m.appendChild(Te),Y.appendChild(m)}if(!S){S=document.createElement("div"),S.className="ng-sonification-waveform ng-hidden",k=document.createElement("canvas"),w=k.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,J=Y.getBoundingClientRect();k.width=J.width*j,k.height=zn*j,k.style.width="100%",k.style.height=zn+"px",w&&w.scale(j,j),S.appendChild(k),Y.appendChild(S)}},destroy(){for(const Y of I)Y();I.length=0,C(),W(),l&&(l.close(),l=null),u=null,c=null,h=null,m&&(m.remove(),m=null),S&&(S.remove(),S=null),k=null,w=null,D=null,E=null,Qc(),a=null,M=[],R=[]}}}return ne.BaselinePlugin=ba,ne.CLOUD_NIMBUS_PRIORITY_BUCKETS=na,ne.ConfigPanelPlugin=gl,ne.CriticalPathPlugin=ca,ne.DARK_THEME=gs,ne.DarkThemePlugin=$a,ne.DependencyRenderer=cs,ne.EventBus=Zn,ne.ExportPlugin=Ia,ne.GroupingPlugin=Ji,ne.HeatmapViewPlugin=El,ne.HitTest=as,ne.KeyboardPlugin=$i,ne.LIGHT_THEME=cn,ne.LayoutEngine=ns,ne.MSProjectPlugin=Za,ne.MilestonePlugin=Yi,ne.MiniMapPlugin=Ol,ne.MonteCarloPlugin=Sc,ne.MotionControlPlugin=za,ne.NarrativePlugin=Pc,ne.NetworkGraphPlugin=al,ne.NimbusGantt=Ai,ne.PriorityGroupingPlugin=ta,ne.ResourceLevelingPlugin=mr,ne.RiskAnalysisPlugin=Ur,ne.SonificationPlugin=ed,ne.SplitTaskPlugin=rr,ne.TelemetryPlugin=Ua,ne.TimeScale=es,ne.TimeTravelPlugin=cc,ne.TimelineNotesPlugin=Jl,ne.TooltipManager=us,ne.UndoRedoPlugin=Pi,ne.VirtualScrollPlugin=Ea,ne.WhatIfPlugin=Wc,ne.WorkCalendarPlugin=Ba,ne.computeCPM=hn,ne.exportMSProjectXML=Sn,ne.getAllParentIds=ps,ne.getDescendantIds=ms,ne.hoursWeightedProgress=sa,ne.importMSProjectXML=wn,ne.parseDate=ht,ne.resolveConfig=hs,ne.rollupHoursDeduped=Li,Object.defineProperty(ne,Symbol.toStringTag,{value:"Module"}),ne})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
