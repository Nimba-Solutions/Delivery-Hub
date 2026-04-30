var NimbusGantt=(function(J){"use strict";function Be(e,t){const n=new Map;for(const l of e.values()){const d=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let u=n.get(d);u||(u=[],n.set(d,u)),u.push(l)}const s=[];function o(l,d){const u=l.sortOrder??Number.MAX_SAFE_INTEGER,h=d.sortOrder??Number.MAX_SAFE_INTEGER;return u!==h?u-h:l.name.localeCompare(d.name)}function i(l,d,u){const h=n.get(l);return h?(h.sort(o),h.map(y=>{const c=n.has(y.id)&&t.has(y.id),f=u,v={task:y,children:[],depth:d,expanded:c,visible:f,rowIndex:-1};return f&&(v.rowIndex=s.length,s.push(y.id)),v.children=i(y.id,d+1,f&&c),v})):[]}return{tree:i(void 0,0,!0),flatIds:s}}function ft(e,t=7){let n=1/0,s=-1/0;for(const i of e.values()){if(i.startDate){const a=new Date(i.startDate).getTime();a<n&&(n=a)}if(i.endDate){const a=new Date(i.endDate).getTime();a>s&&(s=a)}}const o=864e5;if(n===1/0||s===-1/0){const i=new Date;return i.setHours(0,0,0,0),{start:new Date(i.getTime()-30*o),end:new Date(i.getTime()+30*o)}}return{start:new Date(n-t*o),end:new Date(s+t*o)}}class ln{constructor(t,n=[]){this.listeners=new Set,this.state=t,this.middlewares=n}getState(){return this.state}subscribe(t){return this.listeners.add(t),()=>{this.listeners.delete(t)}}dispatch(t){if(this.middlewares.length===0){this.applyAction(t);return}this.middlewares.reduceRight((s,o)=>i=>o(i,()=>this.state,s),s=>this.applyAction(s))(t)}applyAction(t){const n=gi(this.state,t);n!==this.state&&(this.state=n,this.notify())}notify(){for(const t of this.listeners)t()}}function gi(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const l of t.tasks)n.set(l.id,l);const s=new Map;if(t.dependencies)for(const l of t.dependencies)s.set(l.id,l);const{tree:o,flatIds:i}=Be(n,e.expandedIds),a=ft(n);return{...e,tasks:n,dependencies:s,tree:o,flatVisibleIds:i,dateRange:a}}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const s={...n,...t.changes},o=new Map(e.tasks);if(o.set(t.taskId,s),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:a,flatIds:l}=Be(o,e.expandedIds);return{...e,tasks:o,tree:a,flatVisibleIds:l}}return{...e,tasks:o}}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:s,flatIds:o}=Be(n,e.expandedIds),i=ft(n);return{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i}}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:s,flatIds:o}=Be(n,e.expandedIds),i=ft(n),a=new Set(e.selectedIds);return a.delete(t.taskId),{...e,tasks:n,tree:s,flatVisibleIds:o,dateRange:i,selectedIds:a}}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:s,flatIds:o}=Be(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"EXPAND_ALL":{const n=new Set,s=new Set;for(const a of e.tasks.values())a.parentId&&e.tasks.has(a.parentId)&&s.add(a.parentId);for(const a of s)n.add(a);const{tree:o,flatIds:i}=Be(e.tasks,n);return{...e,expandedIds:n,tree:o,flatVisibleIds:i}}case"COLLAPSE_ALL":{const n=new Set,{tree:s,flatIds:o}=Be(e.tasks,n);return{...e,expandedIds:n,tree:s,flatVisibleIds:o}}case"SET_ZOOM":return{...e,zoomLevel:t.level};case"SET_SCROLL":return{...e,scrollX:t.x,scrollY:t.y};case"SET_SCROLL_X":return{...e,scrollX:t.x};case"SET_SCROLL_Y":return{...e,scrollY:t.y};case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),{...e,selectedIds:n}}case"DESELECT_ALL":return{...e,selectedIds:new Set};case"DRAG_START":return{...e,dragState:t.drag};case"DRAG_UPDATE":{if(!e.dragState)return e;const n={...e.dragState,currentX:t.currentX,currentY:t.currentY};return{...e,dragState:n}}case"DRAG_END":return{...e,dragState:null};case"DRAG_CANCEL":return{...e,dragState:null};case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const s=new Map(e.tasks);s.set(t.taskId,{...n,startDate:t.startDate,endDate:t.endDate});const o=ft(s);return{...e,tasks:s,dateRange:o}}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),{...e,dependencies:n}}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),{...e,dependencies:n}}case"SET_DATE_RANGE":return{...e,dateRange:{start:t.start,end:t.end}};case"SET_TIME_CURSOR":return{...e,timeCursorDate:t.date};default:return e}}function Jn(e,t){if(!t||t.version!==1)return[];switch(t.kind){case"task.upsert":{const n=[];for(const s of t.tasks)if(!(!s||typeof s.id!="string"))if(e.tasks.has(s.id)){const{id:o,...i}=s;n.push({type:"UPDATE_TASK",taskId:o,changes:i})}else s.name&&s.startDate&&s.endDate&&n.push({type:"ADD_TASK",task:s});return n}case"task.delete":{const n=[];for(const s of t.ids)typeof s=="string"&&n.push({type:"REMOVE_TASK",taskId:s});return n}case"bulk.replace":return[{type:"SET_DATA",tasks:t.tasks,dependencies:t.deps}];default:return[]}}class Qn{constructor(){this.listeners=new Map}on(t,n){let s=this.listeners.get(t);return s||(s=new Set,this.listeners.set(t,s)),s.add(n),()=>{this.off(t,n)}}off(t,n){const s=this.listeners.get(t);s&&(s.delete(n),s.size===0&&this.listeners.delete(t))}emit(t,...n){const s=this.listeners.get(t);if(s)for(const o of[...s])o(...n)}}const cn=864e5,hi=cn*7,fi={day:40,week:120,month:180,quarter:200},es=["January","February","March","April","May","June","July","August","September","October","November","December"],ts=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];class ns{constructor(t,n,s){this.zoomLevel=t,this.rangeStart=n.start,this.rangeEnd=n.end,this.viewportWidth=s,this.columnWidth=fi[t],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(t){const n=t.getTime()-this.rangeStart.getTime(),s=this.getTotalWidth();return n/this.totalMs*s}xToDate(t){const n=this.getTotalWidth(),s=t/n*this.totalMs;return new Date(this.rangeStart.getTime()+s)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(n=>n.x).filter(n=>n>0)}countDays(){return Math.round(this.totalMs/cn)}countWeeks(){return Math.ceil(this.totalMs/hi)}countMonths(){const t=this.rangeStart.getUTCFullYear(),n=this.rangeStart.getUTCMonth(),s=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(s-t)*12+(o-n)}countQuarters(){const t=this.rangeStart.getUTCFullYear(),n=Math.floor(this.rangeStart.getUTCMonth()/3),s=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(s-t)*4+(o-n)}headersDay(){const t=[],n=[],s=this.getTotalWidth();let o=new Date(this.rangeStart);for(let a=0;a<this.countDays();a++){const l=a*this.columnWidth;n.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=ss(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const a=dn(i),l=this.dateToX(i),d=a.getTime()>=this.rangeEnd.getTime()?s:this.dateToX(a);t.push({label:`${es[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:d-l,date:new Date(i)}),i=a}return[t,n]}headersWeek(){const t=[],n=[];this.getTotalWidth();const s=this.countWeeks();for(let i=0;i<s;i++){const a=ss(this.rangeStart,i*7),l=i*this.columnWidth;n.push({label:`${ts[a.getUTCMonth()]} ${a.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(a)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=dn(o),a=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,d=this.dateToX(a),u=this.dateToX(l);t.push({label:`${es[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:d,width:u-d,date:new Date(a)}),o=i}return[t,n]}headersMonth(){const t=[],n=[];this.getTotalWidth();const s=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let a=0;a<s;a++){const l=a*this.columnWidth;n.push({label:ts[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=dn(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,d=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,u=this.dateToX(l),h=this.dateToX(d);t.push({label:String(i.getUTCFullYear()),x:u,width:h-u,date:new Date(l)}),i=a}return[t,n]}headersQuarter(){const t=[],n=[];this.getTotalWidth();const s=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let a=0;a<s;a++){const l=Math.floor(o.getUTCMonth()/3)+1,d=a*this.columnWidth;n.push({label:`Q${l}`,x:d,width:this.columnWidth,date:new Date(o)}),o=pi(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const a=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,d=a.getTime()>this.rangeEnd.getTime()?this.rangeEnd:a,u=this.dateToX(l),h=this.dateToX(d);t.push({label:String(i.getUTCFullYear()),x:u,width:h-u,date:new Date(l)}),i=a}return[t,n]}}function ss(e,t){return new Date(e.getTime()+t*cn)}function pi(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function dn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}class os{computeLayouts(t,n,s,o){const i=[];for(let a=0;a<t.length;a++){const l=t[a],d=n.get(l);if(!d)continue;const u=pt(d.startDate),h=pt(d.endDate),y=s.dateToX(u),r=s.dateToX(h)-y,c=Math.max(r,o.minBarWidth),f=a*o.rowHeight,v=f+(o.rowHeight-o.barHeight)/2,b=c*(d.progress||0),g=d.color||o.colorMap[d.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:a,x:y,y:f,width:c,barY:v,barHeight:o.barHeight,progressWidth:b,color:g,textColor:o.theme.barTextColor,label:d.status==="group-header"?d.name:(d.hoursLabel||(d.hours!=null?`${d.hours}h`:""))+(d.hoursLabel||d.hours!=null?" · ":"")+((d.progress||0)>0?`${Math.round((d.progress||0)*100)}% · `:"")+(d.title||d.name),isMilestone:d.isMilestone||!1})}return i}}function pt(e){const[t,n,s]=e.split("-"),o=Number(t),i=Number(n)-1,a=Number(s);return new Date(Date.UTC(o,i,a))}const Lt=864e5,is=1,mi=2,yi=.5,Ti=2,as=8,bi=6,un=2;class vi{constructor(t){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",t.appendChild(this.canvas);const n=this.canvas.getContext("2d");if(!n)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=n,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(t,n){this.displayWidth=t,this.displayHeight=n,this.canvas.width=Math.round(t*this.dpr),this.canvas.height=Math.round(n*this.dpr),this.canvas.style.width=`${t}px`,this.canvas.style.height=`${n}px`}render(t,n,s){const{ctx:o,displayWidth:i,displayHeight:a,dpr:l}=this,{config:d}=t,{theme:u}=d,h=t.scrollX,y=t.scrollY;o.setTransform(l,0,0,l,0,0);const c=d.headerHeight,f=a-c;this.fillRect(0,0,i,a,u.timelineBg),o.save(),o.beginPath(),o.rect(0,c,i,f),o.clip(),o.translate(-h,0),d.showWeekends&&this.renderWeekendShading(t,s,c,f,u),this.renderGridLines(s,c,f,u,h),this.renderAltRows(t,n,c,u,h,y);const v=this.getTodayX(t,d,s);d.showToday&&v!==null&&this.renderTodayBackground(v,s,c,f,u),this.renderGroupRowBgs(t,n,d,h,y,c,f),this.renderTaskBars(t,n,d,u,h,y,c,f),this.renderDragSnapGuide(t,n,s,c,f,u),d.showToday&&v!==null&&this.renderTodayLine(v,c,f,u),o.restore(),this.renderHeader(s,d,u,h)}destroy(){this.canvas.remove()}renderWeekendShading(t,n,s,o,i){const{start:a,end:l}=t.dateRange,d=new Date(a);d.setUTCHours(0,0,0,0);const u=l.getTime();for(;d.getTime()<=u;){const h=d.getUTCDay();if(h===0||h===6){const y=n.dateToX(d),r=new Date(d.getTime()+Lt),f=n.dateToX(r)-y;this.fillRect(y,s,f,o,i.timelineWeekendBg)}d.setTime(d.getTime()+Lt)}}renderGridLines(t,n,s,o,i){const{ctx:a}=this,l=t.getGridLines();a.beginPath(),a.strokeStyle=o.timelineGridColor,a.lineWidth=yi;for(const d of l){const u=this.snapToPixel(d);a.moveTo(u,n),a.lineTo(u,n+s)}a.stroke()}renderAltRows(t,n,s,o,i,a){const{ctx:l,displayWidth:d}=this,u=t.config.rowHeight,h=t.flatVisibleIds.length;for(let y=0;y<h;y++)if(y%2===1){const r=s+y*u-a;if(r+u<s||r>s+this.displayHeight)continue;this.fillRect(i,r,d+i,u,o.gridAltRowBg)}}getTodayX(t,n,s){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:a}=t.dateRange;return o.getTime()<i.getTime()||o.getTime()>a.getTime()?null:s.dateToX(o)}renderTodayBackground(t,n,s,o,i){const a=new Date;a.setHours(0,0,0,0);const l=new Date(a.getTime()+Lt),d=n.dateToX(l)-n.dateToX(a);this.fillRect(t,s,d,o,i.todayBg)}renderGroupRowBgs(t,n,s,o,i,a,l){const{ctx:d,displayWidth:u}=this,h=s.rowHeight;for(const y of n){const r=t.tasks.get(y.taskId);if(!r||!r.groupBg)continue;const c=y.y-i+a;c+h<a||c>a+l||(d.save(),d.fillStyle=r.groupBg,d.fillRect(o,c,u,h),r.groupColor&&(d.fillStyle=r.groupColor,d.fillRect(o,c,u,2)),d.restore())}}renderDragSnapGuide(t,n,s,o,i,a){const l=t.dragState;if(!l||l.type!=="move"&&l.type!=="resize-left"&&l.type!=="resize-right")return;const d=n.find(b=>b.taskId===l.taskId);if(!d)return;const u=new Date;u.setHours(0,0,0,0);const h=new Date(u.getTime()+Lt),y=s.dateToX(h)-s.dateToX(u);if(y<=0)return;const r=l.currentX-l.startX;let c;l.type==="move"||l.type==="resize-left"?c=d.x+r:c=d.x+d.width+r;const f=Math.round(c/y)*y,{ctx:v}=this;v.save(),v.strokeStyle=a.barSelectedBorder||"#3b82f6",v.lineWidth=1,v.setLineDash([4,3]),v.globalAlpha=.85,v.beginPath(),v.moveTo(f+.5,o),v.lineTo(f+.5,o+i),v.stroke(),v.restore()}renderTaskBars(t,n,s,o,i,a,l,d){const{ctx:u}=this,h=o.barBorderRadius,y=t.dragState,r=y?y.currentX-y.startX:0,c=4;for(const f of n){let v=f.x;const b=f.barY-a+l;let g=f.width;const p=f.barHeight;if(b+p<l||b>l+d)continue;const w=y&&y.taskId===f.taskId;if(w){if(y.type==="move")v+=r;else if(y.type==="resize-left"){const k=v+r,E=g-r;E>=c&&(v=k,g=E)}else if(y.type==="resize-right"){const k=g+r;k>=c&&(g=k)}}if(f.isMilestone){this.renderMilestone(v,b,p,f.color,o,t.selectedIds.has(f.taskId));continue}const m=t.tasks.get(f.taskId),T=m&&m.status!=="group-header"&&m.style?m.style:null,S=T?this.resolveFillOpacity(T):1;if(S<1?(u.save(),u.globalAlpha=S,this.fillRoundedRect(v,b,g,p,h,f.color),u.restore()):this.fillRoundedRect(v,b,g,p,h,f.color),s.showProgress&&f.progressWidth>0){const k=this.darkenColor(f.color,.2);u.save(),u.beginPath(),this.roundedRectPath(v,b,g,p,h),u.clip(),u.fillStyle=k,u.fillRect(v,b,f.progressWidth,p),u.restore()}t.selectedIds.has(f.taskId)&&this.strokeRoundedRect(v,b,g,p,h,o.barSelectedBorder,un),w&&this.strokeRoundedRect(v,b,g,p,h,o.barSelectedBorder,un),T&&T.borderStyle&&T.borderStyle!=="none"&&this.renderDecoratorBorder(T,v,b,g,p,h,f.color),this.renderBarLabel(f,v,b,g,p,o),T&&T.badge&&T.badge.text&&this.renderDecoratorBadge(T.badge,v,b,g,p,f.color,o)}}resolveFillOpacity(t){return typeof t.fillOpacity=="number"?Math.max(0,Math.min(1,t.fillOpacity)):t.fillStyle==="muted"?.55:1}renderDecoratorBorder(t,n,s,o,i,a,l){const{ctx:d}=this,u=t.borderWidth??2,h=t.borderColor??this.darkenColor(l,.3),y=t.borderStyle??"solid";let r;switch(y){case"dashed":r=[6,4];break;case"dotted":r=[2,3];break;default:r=[]}if(d.save(),d.setLineDash(r),d.strokeStyle=h,d.lineWidth=u,this.roundedRectPath(n,s,o,i,a),d.stroke(),y==="double"){const c=u+1,f=Math.max(0,a-c);d.lineWidth=u,this.roundedRectPath(n+c,s+c,Math.max(0,o-c*2),Math.max(0,i-c*2),f),d.stroke()}d.restore()}renderDecoratorBadge(t,n,s,o,i,a,l){const{ctx:d}=this,u=t.text,h=t.placement??"end",y=Math.max(14,i*.65),r=6;d.save();const c=`${Math.round(l.fontSize*.85)}px ${l.fontFamily}`;d.font=c,d.textBaseline="middle";const v=d.measureText(u).width+r*2,b=s+(i-y)/2,g=h==="start"?n+2:n+o-v-2;d.shadowColor="rgba(0,0,0,0.25)",d.shadowBlur=3,d.shadowOffsetY=1;const p=t.color??"#ffffff";d.fillStyle=p,this.roundedRectPath(g,b,v,y,y/2),d.fill(),d.shadowColor="transparent",d.shadowBlur=0,d.shadowOffsetY=0,d.fillStyle=t.color?"#ffffff":this.darkenColor(a,.4),d.textAlign="center",d.fillText(u,g+v/2,b+y/2),d.restore()}renderMilestone(t,n,s,o,i,a){const{ctx:l}=this,d=(s-Ti*2)/2,u=n+s/2;l.save(),l.beginPath(),l.moveTo(t,u-d),l.lineTo(t+d,u),l.lineTo(t,u+d),l.lineTo(t-d,u),l.closePath(),l.fillStyle=o,l.fill(),a&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=un,l.stroke()),l.restore()}renderBarLabel(t,n,s,o,i,a){const{ctx:l}=this;if(!t.label)return;l.save();const d=`${a.fontSize}px ${a.fontFamily}`;l.font=d,l.textBaseline="middle";const u=l.measureText(t.label).width,h=s+i/2;u+as*2<=o?(l.beginPath(),l.rect(n,s,o,i),l.clip(),l.fillStyle=t.textColor,l.textAlign="left",l.fillText(t.label,n+as,h)):(l.fillStyle=a.gridTextColor,l.textAlign="left",l.fillText(t.label,n+o+bi,h)),l.restore()}renderTodayLine(t,n,s,o){const{ctx:i}=this,a=this.snapToPixel(t);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=mi,i.moveTo(a,n),i.lineTo(a,n+s),i.stroke()}renderHeader(t,n,s,o){const{ctx:i,displayWidth:a}=this,l=n.headerHeight,d=t.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,a,l,s.timelineHeaderBg);const u=d.length||2,h=l/u,y=`${s.fontSize}px ${s.fontFamily}`;i.font=y,i.textBaseline="middle",i.fillStyle=s.timelineHeaderText;for(let c=0;c<d.length;c++){const f=d[c],v=c*h;for(const b of f){const g=b.x-o,p=b.width;if(g+p<0||g>a)continue;i.beginPath(),i.strokeStyle=s.timelineGridColor,i.lineWidth=is;const w=this.snapToPixelRaw(g+p);i.moveTo(w,v),i.lineTo(w,v+h),i.stroke(),i.save(),i.beginPath(),i.rect(g,v,p,h),i.clip(),i.fillStyle=s.timelineHeaderText,i.font=c===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,i.textAlign="center",i.fillText(b.label,g+p/2,v+h/2),i.restore()}}const r=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=s.gridBorderColor,i.lineWidth=is,i.moveTo(0,r),i.lineTo(a,r),i.stroke()}fillRect(t,n,s,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(t,n,s,o)}roundedRectPath(t,n,s,o,i){const{ctx:a}=this,l=Math.min(i,s/2,o/2);a.moveTo(t+l,n),a.lineTo(t+s-l,n),a.arcTo(t+s,n,t+s,n+l,l),a.lineTo(t+s,n+o-l),a.arcTo(t+s,n+o,t+s-l,n+o,l),a.lineTo(t+l,n+o),a.arcTo(t,n+o,t,n+o-l,l),a.lineTo(t,n+l),a.arcTo(t,n,t+l,n,l),a.closePath()}fillRoundedRect(t,n,s,o,i,a){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(t,n,s,o,i),l.fillStyle=a,l.fill()}strokeRoundedRect(t,n,s,o,i,a,l){const{ctx:d}=this;d.beginPath(),this.roundedRectPath(t,n,s,o,i),d.strokeStyle=a,d.lineWidth=l,d.stroke()}snapToPixel(t){return Math.round(t)+.5}snapToPixelRaw(t){return Math.round(t)+.5}darkenColor(t,n){let s,o,i;const a=t.replace("#","");a.length===3?(s=parseInt(a[0]+a[0],16),o=parseInt(a[1]+a[1],16),i=parseInt(a[2]+a[2],16)):(s=parseInt(a.substring(0,2),16),o=parseInt(a.substring(2,4),16),i=parseInt(a.substring(4,6),16)),s=Math.round(s*(1-n)),o=Math.round(o*(1-n)),i=Math.round(i*(1-n));const l=d=>d.toString(16).padStart(2,"0");return`#${l(s)}${l(o)}${l(i)}`}}const rs="ng-tree-grid-styles";function wi(e,t){const n=e.querySelector(`#${rs}`);n&&n.remove();const s=document.createElement("style");s.id=rs,s.textContent=`
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
  `,e.insertBefore(s,e.firstChild)}function Si(e){const t=[];function n(s){for(const o of s)o.visible&&t.push(o),o.expanded&&o.children.length>0&&n(o.children)}return n(e),t}function Rt(e,t){var s;if(t.renderer)return t.renderer(e,t.field);const n=e[t.field]??((s=e.metadata)==null?void 0:s[t.field])??"";return n==null?"":String(n)}class ki{constructor(t){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=t,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const n=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),n.appendChild(this.headerColgroup);const s=document.createElement("thead");n.appendChild(s),this.headerEl.appendChild(n),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(t,n){const{config:s}=t,{columns:o,rowHeight:i}=s,a=s.theme;wi(this.rootEl,a),this.columns=o,this.columnWidths=o.map(u=>u.width??120),this.headerEl.style.height=`${s.headerHeight}px`,this.headerEl.style.lineHeight=`${s.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,s.headerHeight);const l=Si(n),d=l.map(u=>u.task.id);this.updateRows(l,d,t),this.currentVisibleIds=d}setScrollY(t){this.bodyInner.style.transform=`translateY(${-t}px)`}onRowClick(t){this.clickHandler=t}onRowDblClick(t){this.dblClickHandler=t}onExpandToggle(t){this.expandHandler=t}onResizeColumn(t){this.resizeHandler=t}highlight(t){const n=this.rows.get(t);n&&n.classList.add("ng-row-selected")}clearHighlight(){for(const t of this.rows.values())t.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const t of this.columnWidths){const n=document.createElement("col");n.style.width=`${t}px`,this.headerColgroup.appendChild(n);const s=document.createElement("col");s.style.width=`${t}px`,this.bodyColgroup.appendChild(s)}}rebuildHeader(t,n){const s=this.headerEl.querySelector("thead"),o=s.querySelector("tr");if(o&&o.children.length===t.length){for(let a=0;a<t.length;a++){const l=o.children[a],d=l.querySelector(".ng-th-text");d&&d.textContent!==t[a].header&&(d.textContent=t[a].header),l.setAttribute("data-field",t[a].field)}return}s.innerHTML="";const i=document.createElement("tr");i.style.height=`${n}px`,t.forEach((a,l)=>{const d=document.createElement("th");d.className="ng-grid-th",d.setAttribute("data-field",a.field);const u=document.createElement("span");u.className="ng-th-text",u.textContent=a.header,d.appendChild(u);const h=document.createElement("span");h.className="ng-resize-handle",d.appendChild(h),this.attachResizeListener(h,l),i.appendChild(d)}),s.appendChild(i)}attachResizeListener(t,n){t.addEventListener("mousedown",s=>{s.preventDefault(),s.stopPropagation();const o=s.clientX,i=this.columnWidths[n],a=this.columns[n].minWidth??40,l=u=>{const h=u.clientX-o,y=Math.max(a,i+h);this.columnWidths[n]=y;const r=this.headerColgroup.children,c=this.bodyColgroup.children;r[n]&&(r[n].style.width=`${y}px`),c[n]&&(c[n].style.width=`${y}px`)},d=()=>{document.removeEventListener("mousemove",l),document.removeEventListener("mouseup",d),this.resizeHandler&&this.resizeHandler(this.columns[n].field,this.columnWidths[n])};document.addEventListener("mousemove",l),document.addEventListener("mouseup",d)})}updateRows(t,n,s){const{config:o}=s,{rowHeight:i}=o,a=new Set(n),l=new Map;for(const u of t)l.set(u.task.id,u);for(const[u,h]of this.rows)a.has(u)||(h.remove(),this.rows.delete(u));let d=null;for(let u=0;u<t.length;u++){const h=t[u],y=h.task.id;let r=this.rows.get(y);r?this.updateRowContent(r,h,u,s):(r=this.createRow(h,u,s),this.rows.set(y,r)),r.style.height=`${i}px`,d?d.nextSibling!==r&&this.tbody.insertBefore(r,d.nextSibling):this.tbody.firstChild!==r&&this.tbody.insertBefore(r,this.tbody.firstChild),d=r}}createRow(t,n,s){const{config:o}=s,{columns:i,rowHeight:a}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",t.task.id),l.style.height=`${a}px`,t.task.status==="group-header"?(l.classList.add("ng-group-row"),t.task.groupBg&&(l.style.background=t.task.groupBg)):n%2===1&&l.classList.add("ng-row-alt"),s.selectedIds.has(t.task.id)&&l.classList.add("ng-row-selected");for(const d of i){const u=this.createCell(t,d,s);l.appendChild(u)}return l}createCell(t,n,s){var i;const o=document.createElement("td");if(o.className="ng-grid-cell",o.setAttribute("data-field",n.field),n.align==="center"?o.style.textAlign="center":n.align==="right"&&(o.style.textAlign="right"),n.tree){o.classList.add("ng-tree-cell");const a=t.depth*20+8;if(o.style.paddingLeft=`${a}px`,t.children.length>0){const u=document.createElement("span");u.className="ng-expand-icon",t.expanded&&u.classList.add("ng-expanded"),u.innerHTML="&#9654;",u.setAttribute("data-expand",t.task.id),o.appendChild(u)}else{const u=document.createElement("span");u.className="ng-expand-spacer",o.appendChild(u)}if(t.children.length===0&&!t.task.groupBg){const u=document.createElement("span");u.className="ng-drag-handle",u.innerHTML="&#9776;",o.appendChild(u)}const l=t.task.color||((i=s.config.colorMap)==null?void 0:i[t.task.status??""])||"";if(l&&t.children.length===0){const u=document.createElement("span");u.className="ng-status-dot",u.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${l};margin-right:5px;flex-shrink:0;vertical-align:middle;`,o.appendChild(u)}const d=document.createElement("span");d.className="ng-grid-cell-text",d.textContent=Rt(t.task,n),o.appendChild(d)}else if(n.field==="_drag"&&t.children.length===0&&!t.task.groupBg){const a=document.createElement("span");a.className="ng-drag-handle",a.innerHTML="&#9776;",o.appendChild(a)}else o.textContent=Rt(t.task,n);return o}updateRowContent(t,n,s,o){var d;const{config:i}=o,{columns:a}=i;n.task.status==="group-header"?(t.classList.add("ng-group-row"),n.task.groupBg&&(t.style.background=n.task.groupBg),t.classList.remove("ng-row-alt")):(t.classList.remove("ng-group-row"),t.style.background="",s%2===1?t.classList.add("ng-row-alt"):t.classList.remove("ng-row-alt")),o.selectedIds.has(n.task.id)?t.classList.add("ng-row-selected"):t.classList.remove("ng-row-selected");const l=t.querySelectorAll("td.ng-grid-cell");for(let u=0;u<a.length;u++){const h=a[u],y=l[u];if(!y){const r=this.createCell(n,h,o);t.appendChild(r);continue}if(h.tree){const c=`${n.depth*20+8}px`;y.style.paddingLeft!==c&&(y.style.paddingLeft=c);const f=y.querySelector(".ng-expand-icon"),v=y.querySelector(".ng-expand-spacer");if(n.children.length>0)if(f)n.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{v&&v.remove();const m=document.createElement("span");m.className="ng-expand-icon",n.expanded&&m.classList.add("ng-expanded"),m.innerHTML="&#9654;",m.setAttribute("data-expand",n.task.id),y.insertBefore(m,y.firstChild)}else if(f){f.remove();const m=document.createElement("span");m.className="ng-expand-spacer",y.insertBefore(m,y.firstChild)}const b=y.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!b){const m=document.createElement("span");m.className="ng-drag-handle",m.innerHTML="&#9776;";const T=y.querySelector(".ng-status-dot")||y.querySelector(".ng-grid-cell-text");T?y.insertBefore(m,T):y.appendChild(m)}}else b&&b.remove();const g=y.querySelector(".ng-status-dot"),p=n.task.color||((d=o.config.colorMap)==null?void 0:d[n.task.status??""])||"";if(p&&n.children.length===0)if(g)g.style.background=p;else{const m=document.createElement("span");m.className="ng-status-dot",m.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${p};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const T=y.querySelector(".ng-grid-cell-text");T?y.insertBefore(m,T):y.appendChild(m)}else g&&g.remove();const w=y.querySelector(".ng-grid-cell-text");if(w){const m=Rt(n.task,h);w.textContent!==m&&(w.textContent=m)}}else if(h.field==="_drag"){const r=y.querySelector(".ng-drag-handle");if(n.children.length===0&&!n.task.groupBg){if(!r){y.textContent="";const c=document.createElement("span");c.className="ng-drag-handle",c.innerHTML="&#9776;",y.appendChild(c)}}else r&&(y.textContent="")}else{const r=Rt(n.task,h);y.textContent!==r&&(y.textContent=r)}}for(;t.children.length>a.length;)t.removeChild(t.lastChild)}findTaskId(t){let n=t;for(;n&&n!==this.bodyEl;){if(n.hasAttribute("data-task-id"))return n.getAttribute("data-task-id");n=n.parentElement}return null}handleBodyClick(t){const n=t.target;if(n.hasAttribute("data-expand")||n.closest(".ng-expand-icon")){const o=n.hasAttribute("data-expand")?n:n.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){t.stopPropagation(),this.expandHandler(i);return}}}const s=this.findTaskId(t.target);s&&this.clickHandler&&this.clickHandler(s,t)}handleBodyDblClick(t){const n=this.findTaskId(t.target);n&&this.dblClickHandler&&this.dblClickHandler(n,t)}}class Ei{constructor(t,n){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=n,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";t.firstChild;){const s=t.firstChild;s.style&&(s.style.position="sticky",s.style.top="0",s.style.left="0",s.style.zIndex="1"),this.content.appendChild(s)}this.wrapper.appendChild(this.content),t.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(t,n){this.wrapper.scrollLeft=t,this.wrapper.scrollTop=n}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(t,n){this.content.style.width=`${t}px`,this.content.style.height=`${n}px`}setViewportSize(t,n){this.wrapper.style.width=`${t}px`,this.wrapper.style.height=`${n}px`}scrollToX(t){this.wrapper.scrollLeft=t}scrollToY(t){this.wrapper.scrollTop=t}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}}class ls{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(t,n,s,o){for(let i=s.length-1;i>=0;i--){const a=s[i],l=this.testLayout(t,n,a,o);if(l!==null)return{type:l,taskId:a.taskId,layout:a}}return null}getCursor(t,n){if(!t)return"default";switch(t.type){case"bar":return n?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";case"none":default:return"default"}}testLayout(t,n,s,o){return s.isMilestone?this.testMilestone(t,n,s):this.testBar(t,n,s,o)}testBar(t,n,s,o){const{x:i,barY:a,width:l,barHeight:d}=s;if(t<i||t>i+l||n<a||n>a+d)return null;if(t<=i+this.edgeThreshold)return"bar-left-edge";if(t>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&s.progressWidth>0){const u=i+s.progressWidth;if(Math.abs(t-u)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(t,n,s){const o=s.x,i=s.barY+s.barHeight/2,a=s.barHeight/2;return Math.abs(t-o)<=a&&Math.abs(n-i)<=a?"bar":null}}const cs=864e5;function Pt(e,t){const n=t.xToDate(0),s=t.xToDate(e);return Math.round((s.getTime()-n.getTime())/cs)}function mt(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function $e(e,t){const n=mt(e),s=new Date(n.getTime()+t*cs),o=s.getUTCFullYear(),i=String(s.getUTCMonth()+1).padStart(2,"0"),a=String(s.getUTCDate()).padStart(2,"0");return`${o}-${i}-${a}`}function ds(e,t,n){return Math.max(t,Math.min(n,e))}const Di=3,Ci=300;class Ii{constructor(t,n){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.panning=!1,this.panStartClientX=0,this.panStartClientY=0,this.panOrigScrollX=0,this.panOrigScrollY=0,this.lastClickTaskId=null,this.lastClickTime=0,this.gestureLabelEl=null,this.canvas=t,this.options=n,this.hitTest=new ls,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}toCanvasCoords(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handleClick_native(t){const{canvasX:n,canvasY:s}=this.toCanvasCoordsFromMouse(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);a&&a.type!=="none"&&(t.preventDefault(),t.stopPropagation())}toCanvasCoordsFromMouse(t){const n=this.canvas.getBoundingClientRect(),s=this.options.getState(),o=t.clientX-n.left,i=t.clientY-n.top,a=o+s.scrollX,l=i+s.scrollY-s.config.headerHeight;return{canvasX:a,canvasY:l}}handlePointerMove(t){if(this.panning){t.preventDefault();const l=t.clientX-this.panStartClientX,d=t.clientY-this.panStartClientY,u=this.options.scrollManager;if(u){const h=Math.max(0,this.panOrigScrollX-l),y=Math.max(0,this.panOrigScrollY-d);u.setScrollPosition(h,y)}return}if(this.dragging){this.handleDragMove(t);return}const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(a,this.options.readOnly),this.options.onHover)if(a&&a.type!=="none"){const l=o.tasks.get(a.taskId);if(l){const d=this.canvas.getBoundingClientRect();this.options.onHover(l,t.clientX-d.left,t.clientY-d.top,a.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(t){if(t.button!==0)return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t),o=this.options.getState(),i=this.options.getLayouts(),a=this.hitTest.test(n,s,i,o.config);if(!a||a.type==="none"){if(!this.options.scrollManager)return;t.preventDefault(),t.stopPropagation(),this.panning=!0,this.panStartClientX=t.clientX,this.panStartClientY=t.clientY;const d=this.options.scrollManager.getScrollPosition();this.panOrigScrollX=d.x,this.panOrigScrollY=d.y;try{this.canvas.setPointerCapture(t.pointerId)}catch{}this.dragPointerId=t.pointerId,this.canvas.style.cursor="grabbing";return}t.preventDefault(),t.stopPropagation(),this.dragHit=a,this.dragStartX=t.clientX,this.dragStartY=t.clientY;const l=o.tasks.get(a.taskId);if(l){this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate;try{this.canvas.setPointerCapture(t.pointerId)}catch{}if(this.dragPointerId=t.pointerId,this.dragging=!0,!this.options.readOnly){const d=Mi(a.type);d&&this.options.dispatch({type:"DRAG_START",drag:{type:d,taskId:a.taskId,startX:n,startY:s,currentX:n,currentY:s,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}}handleDragMove(t){if(!this.dragHit||(t.preventDefault(),this.options.readOnly))return;const{canvasX:n,canvasY:s}=this.toCanvasCoords(t);this.options.dispatch({type:"DRAG_UPDATE",currentX:n,currentY:s}),this.updateGestureLabel(t)}updateGestureLabel(t){if(!this.dragHit||!this.options.getState().tasks.get(this.dragHit.taskId))return;const o=this.options.getTimeScale(),i=t.clientX-this.dragStartX,a=Pt(i,o);let l="";if(this.dragHit.type==="bar"){const c=$e(this.dragOriginalStartDate,a),f=$e(this.dragOriginalEndDate,a);l=`${c} → ${f}`}else if(this.dragHit.type==="bar-left-edge")l=`Start → ${$e(this.dragOriginalStartDate,a)}`;else if(this.dragHit.type==="bar-right-edge")l=`End → ${$e(this.dragOriginalEndDate,a)}`;else if(this.dragHit.type==="progress-handle"){const c=this.dragHit.layout,{canvasX:f}=this.toCanvasCoords(t),v=f-c.x;l=`${Math.round(ds(v/c.width,0,1)*100)}%`}if(!l)return;if(!this.gestureLabelEl){const c=document.createElement("div");c.setAttribute("data-nga-gesture-label","1"),c.style.cssText=["position:fixed","z-index:9999","pointer-events:none","padding:4px 8px","font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif","font-size:11px","font-weight:600","color:#ffffff","background:rgba(30,41,59,0.92)","border-radius:4px","box-shadow:0 2px 8px rgba(0,0,0,0.18)","white-space:nowrap","transition:opacity 80ms ease","opacity:0"].join(";"),document.body.appendChild(c),this.gestureLabelEl=c,requestAnimationFrame(()=>{this.gestureLabelEl&&(this.gestureLabelEl.style.opacity="1")})}this.gestureLabelEl.textContent=l;const d=12,u=window.innerWidth||document.documentElement.clientWidth,h=this.gestureLabelEl.offsetWidth,y=Math.min(t.clientX+d,u-h-4),r=t.clientY+d;this.gestureLabelEl.style.left=`${y}px`,this.gestureLabelEl.style.top=`${r}px`}removeGestureLabel(){if(this.gestureLabelEl){try{this.gestureLabelEl.remove()}catch{}this.gestureLabelEl=null}}handlePointerUp(t){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch{}this.dragPointerId=null}if(this.panning){this.panning=!1,this.canvas.style.cursor="";return}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const n=Math.abs(t.clientX-this.dragStartX),s=Math.abs(t.clientY-this.dragStartY),o=Math.sqrt(n*n+s*s),i=this.dragHit,l=this.options.getState().tasks.get(i.taskId);o<Di?(this.options.dispatch({type:"DRAG_END"}),l&&this.handleClick(l)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(t),this.dragging=!1,this.dragHit=null,this.removeGestureLabel()}handleClick(t){var s,o,i,a;const n=Date.now();if(this.lastClickTaskId===t.id&&n-this.lastClickTime<Ci){this.lastClickTaskId=null,this.lastClickTime=0,(o=(s=this.options).onTaskDblClick)==null||o.call(s,t);return}this.lastClickTaskId=t.id,this.lastClickTime=n,this.options.dispatch({type:"SELECT_TASK",taskId:t.id}),(a=(i=this.options).onTaskClick)==null||a.call(i,t)}completeDrag(t){var d,u,h,y,r,c,f,v,b,g;if(!this.dragHit)return;const n=this.options.getState(),s=n.tasks.get(this.dragHit.taskId);if(!s){this.options.dispatch({type:"DRAG_END"});return}const o=this.options.getTimeScale(),i=n.config,a=this.dragHit.type,l=t.clientX-this.dragStartX;switch(a){case"bar":{const p=t.clientY-this.dragStartY,w=Math.abs(l),m=Math.abs(p),T=!!this.options.isBarReprioritizeEnabled&&this.options.isBarReprioritizeEnabled(),S=m>w*1.5&&m>12;if(T&&S){const C=this.options.getLayouts(),M=Math.max(0,Math.floor(this.toCanvasCoords(t).canvasY/i.rowHeight)),L=C.find(_=>_.rowIndex===M),R=L?L.taskId:null;let x=null;const $=C.slice().sort((_,H)=>_.rowIndex-H.rowIndex);for(const _ of $){if(_.rowIndex>M)break;const H=_.taskId;typeof H=="string"&&H.indexOf("__bucket_header__")===0&&(x=H.slice(17))}try{console.log("[NG engine] drag commit bar-reorder",s.id,"→ row=",M,"target=",R,"bucket=",x)}catch{}(u=(d=this.options).onBarReorderDrag)==null||u.call(d,s,R,M,x);break}const k=Pt(l,o),E=$e(this.dragOriginalStartDate,k),D=$e(this.dragOriginalEndDate,k);this.options.dispatch({type:"TASK_MOVE",taskId:s.id,startDate:E,endDate:D});try{console.log("[NG engine] drag commit move",s.id,E,D,"hasCb=",!!this.options.onTaskMove)}catch{}(y=(h=this.options).onTaskMove)==null||y.call(h,s,E,D);break}case"bar-left-edge":{const p=Pt(l,o),w=$e(this.dragOriginalStartDate,p),m=mt(this.dragOriginalEndDate),S=mt(w).getTime()>=m.getTime()?$e(this.dragOriginalEndDate,-1):w;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:S,endDate:this.dragOriginalEndDate});try{console.log("[NG engine] drag commit resize-left",s.id,S,this.dragOriginalEndDate,"hasCb=",!!this.options.onTaskResize)}catch{}(c=(r=this.options).onTaskResize)==null||c.call(r,s,S,this.dragOriginalEndDate);break}case"bar-right-edge":{const p=Pt(l,o),w=$e(this.dragOriginalEndDate,p),m=mt(this.dragOriginalStartDate),S=mt(w).getTime()<=m.getTime()?$e(this.dragOriginalStartDate,1):w;this.options.dispatch({type:"TASK_RESIZE",taskId:s.id,startDate:this.dragOriginalStartDate,endDate:S});try{console.log("[NG engine] drag commit resize-right",s.id,this.dragOriginalStartDate,S,"hasCb=",!!this.options.onTaskResize)}catch{}(v=(f=this.options).onTaskResize)==null||v.call(f,s,this.dragOriginalStartDate,S);break}case"progress-handle":{const p=this.dragHit.layout,{canvasX:w}=this.toCanvasCoords(t),m=w-p.x,T=ds(m/p.width,0,1),S=Math.round(T*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:s.id,changes:{progress:S}}),(g=(b=this.options).onTaskProgressChange)==null||g.call(b,s,S);break}}this.options.dispatch({type:"DRAG_END"})}}function Mi(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}const Oe=12,yt=6,_t=4,Ai=3;class us{render(t,n,s,o,i,a,l){const{dependencies:d}=n;if(d.size===0)return;const u=new Map;for(const r of s)u.set(r.taskId,r);const h=t.canvas.width/(window.devicePixelRatio||1),y=t.canvas.height/(window.devicePixelRatio||1);t.save(),t.beginPath(),t.rect(0,l,h,y-l),t.clip(),t.translate(-i,0);for(const r of d.values()){const c=u.get(r.source),f=u.get(r.target);if(!c||!f)continue;const v=r.type||"FS",{sourceX:b,sourceY:g,targetX:p,targetY:w}=this.getConnectionPoints(v,c,f,a,l);this.drawRoutedPath(t,v,b,g,p,w,o),this.drawArrowhead(t,v,p,w,o),this.drawConnectionDot(t,b,g,o),this.drawConnectionDot(t,p,w,o)}t.restore()}hitTest(t,n,s,o,i,a,l=8){const{dependencies:d}=s;if(d.size===0||n<a)return null;const u=new Map;for(const y of o)u.set(y.taskId,y);let h=null;for(const y of d.values()){const r=u.get(y.source),c=u.get(y.target);if(!r||!c)continue;const f=y.type||"FS",{sourceX:v,sourceY:b,targetX:g,targetY:p}=this.getConnectionPoints(f,r,c,i,a),w=t-g,m=n-p,T=Math.sqrt(w*w+m*m);if(T<=l+yt){(!h||T<h.dist)&&(h={depId:y.id,dist:T});continue}const S=f==="FS"||f==="SS"?g-Oe:g+Oe,k=Math.min(S,g),E=Math.max(S,g);if(t>=k-l&&t<=E+l&&Math.abs(n-p)<=l){const L=Math.abs(n-p);(!h||L<h.dist)&&(h={depId:y.id,dist:L})}const D=f==="FS"||f==="FF"?v+Oe:v-Oe,C=Math.min(v,D),M=Math.max(v,D);if(t>=C-l&&t<=M+l&&Math.abs(n-b)<=l){const L=Math.abs(n-b);(!h||L<h.dist)&&(h={depId:y.id,dist:L})}}return(h==null?void 0:h.depId)??null}getConnectionPoints(t,n,s,o,i){const a=n.barY+n.barHeight/2-o+i,l=s.barY+s.barHeight/2-o+i;switch(t){case"FS":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x,targetY:l};case"SS":return{sourceX:n.x,sourceY:a,targetX:s.x,targetY:l};case"FF":return{sourceX:n.x+n.width,sourceY:a,targetX:s.x+s.width,targetY:l};case"SF":return{sourceX:n.x,sourceY:a,targetX:s.x+s.width,targetY:l}}}drawRoutedPath(t,n,s,o,i,a,l){t.beginPath(),t.strokeStyle=l.dependencyColor,t.lineWidth=l.dependencyWidth,t.moveTo(s,o);const d=n==="FS"||n==="FF",u=n==="FS"||n==="SS",h=d?s+Oe:s-Oe,y=u?i-Oe:i+Oe;if(d?u?y>=h:i+Oe>=h:u?i-Oe<=h:y<=h)t.lineTo(h,o),t.lineTo(h,a),t.lineTo(i,a);else{const c=(o+a)/2;t.lineTo(h,o),t.lineTo(h,c),t.lineTo(y,c),t.lineTo(y,a),t.lineTo(i,a)}t.stroke()}drawArrowhead(t,n,s,o,i){const a=n==="FS"||n==="SS";t.beginPath(),a?(t.moveTo(s,o),t.lineTo(s-yt,o-_t),t.lineTo(s-yt,o+_t)):(t.moveTo(s,o),t.lineTo(s+yt,o-_t),t.lineTo(s+yt,o+_t)),t.closePath(),t.fillStyle=i.dependencyColor,t.fill()}drawConnectionDot(t,n,s,o){t.beginPath(),t.arc(n,s,Ai,0,Math.PI*2),t.fillStyle=o.dependencyColor,t.fill()}}const $t=12,Li=100,Ri=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Pi=`
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
`;function rt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function gs(e){const t=e.split("-");if(t.length!==3)return rt(e);const n=parseInt(t[1],10)-1,s=parseInt(t[2],10);return n<0||n>11||isNaN(s)?rt(e):`${Ri[n]} ${s}`}function Tt(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${rt(e)}</span><span class="ng-tooltip-value">${rt(t)}</span></div>`}function _i(e,t){var a,l;const n=Math.round((e.progress??0)*100),s=(a=e.metadata)==null?void 0:a.estimatedHours,o=(l=e.metadata)==null?void 0:l.loggedHours;let i="";return i+=Tt("Status",e.status||"None"),i+=Tt("Assignee",e.assignee||"Unassigned"),i+=Tt("Dates",`${gs(e.startDate)} → ${gs(e.endDate)}`),n>0&&(i+=Tt("Progress",`${n}%`)),s!=null&&(i+=Tt("Hours",`${o??0} / ${s}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${rt(t)}"><span class="ng-tooltip-name">${rt(e.name)}</span></div><div class="ng-tooltip-body">${i}</div>`}class hs{constructor(t,n){this.visible=!1,this.hideTimeout=null,this.container=t,this.customRenderer=n,this.styleEl=document.createElement("style"),this.styleEl.textContent=Pi,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(t,n,s,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const u=this.customRenderer(t);typeof u=="string"?this.tooltipEl.innerHTML=u:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(u))}else this.tooltipEl.innerHTML=_i(t,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),a=this.container.getBoundingClientRect();let l=n+$t,d=s+$t;l+i.width>a.width&&(l=n-$t-i.width),d+i.height>a.height&&(d=s-$t-i.height),l=Math.max(0,l),d=Math.max(0,d),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${d}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const t=()=>{this.tooltipEl.removeEventListener("transitionend",t),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",t),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},Li))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}}const gn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},fs={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},$i=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function ps(e){const t=Oi(e.theme);return{columns:e.columns??$i,zoomLevel:e.zoomLevel??"week",rowHeight:e.rowHeight??36,barHeight:e.barHeight??24,headerHeight:e.headerHeight??56,gridWidth:e.gridWidth??300,minBarWidth:e.minBarWidth??8,readOnly:e.readOnly??!1,fitToView:e.fitToView??!0,showToday:e.showToday??!0,showWeekends:e.showWeekends??!0,showProgress:e.showProgress??!0,snapToDays:e.snapToDays??!0,colorMap:e.colorMap??{},theme:t}}function Oi(e){return!e||e==="light"?{...gn}:e==="dark"?{...fs}:{...gn,...e}}function lt(e,t){if(typeof window>"u")return;const n=window,s=n.__nga_diag;if(!Array.isArray(s))return;const i={t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}};if(s.push(i),n.NGA_DIAG_VERBOSE===!0)try{console.log("[nga-diag]",e,t??{})}catch{}}const ms="nimbus-gantt-root-styles";function Ni(){if(typeof document>"u"||document.getElementById(ms))return;const e=document.createElement("style");e.id=ms,e.textContent=`
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
  `,document.head.appendChild(e)}class Hi{constructor(t,n){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.resizeObserver=null,this.renderScheduled=!1,this.destroyed=!1,this.lastAppliedTs=new Map,this.replayProvider=null,this.agent={getSnapshot:()=>{const h=this.getDisplayState();return{cursorDate:h.timeCursorDate?h.timeCursorDate.toISOString():null,zoomLevel:h.zoomLevel,tasks:Array.from(h.tasks.values()),dependencies:Array.from(h.dependencies.values()),selectedIds:Array.from(h.selectedIds),expandedIds:Array.from(h.expandedIds),flatVisibleIds:h.flatVisibleIds.slice()}},updateTask:(h,y)=>{this.store.dispatch({type:"UPDATE_TASK",taskId:h,changes:y})},addTask:h=>{this.store.dispatch({type:"ADD_TASK",task:h})},removeTask:h=>{this.store.dispatch({type:"REMOVE_TASK",taskId:h})},moveTask:(h,y,r)=>{this.store.dispatch({type:"TASK_MOVE",taskId:h,startDate:y,endDate:r})},addDependency:h=>{this.store.dispatch({type:"ADD_DEPENDENCY",dependency:h})},removeDependency:h=>{this.store.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:h})},setSelection:h=>{this.store.dispatch({type:"DESELECT_ALL"});for(const y of h)this.store.dispatch({type:"SELECT_TASK",taskId:y,multi:!0})},setZoom:h=>{this.store.dispatch({type:"SET_ZOOM",level:h})},scrubTo:h=>{this.store.dispatch({type:"SET_TIME_CURSOR",date:h?new Date(h):null})},history:()=>{const h=this.history;return h?{entries:h.entries().map(y=>({ts:y.ts,wallTs:y.wallTs,actionType:y.action.type,source:y.source,actor:y.actor})),annotations:h.annotations().slice(),lastWallTs:h.lastWallTs()}:null},appendAnnotation:(h,y,r)=>{const c=this.history;return c?(c.appendAnnotation({kind:h,taskId:y,payload:r}),!0):!1}},this.container=t,this.config=ps(n),Ni(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const s=new Map;for(const h of n.tasks)s.set(h.id,h);const o=new Map;if(n.dependencies)for(const h of n.dependencies)o.set(h.id,h);const i=new Set,{tree:a,flatIds:l}=Be(s,i),d=ft(s),u={tasks:s,dependencies:o,tree:a,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:d,dragState:null,config:this.config};if(this.eventBus=new Qn,this.store=new ln(u),this.layoutEngine=new os,this.timeScale=this.createTimeScale(u),this.canvasRenderer=new vi(this.timelinePanel),this.treeGrid=new ki(this.gridPanel),this.scrollManager=new Ei(this.timelinePanel,(h,y)=>{this.store.dispatch({type:"SET_SCROLL",x:h,y})}),this.dependencyRenderer=new us,this.tooltipManager=new hs(this.timelinePanel,n.tooltipRenderer),!this.config.readOnly){const h=this.timelinePanel.querySelector("canvas");h&&(this.dragManager=new Ii(h,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:y=>this.timeScale.dateToX(y),xToDate:y=>this.timeScale.xToDate(y),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:y=>this.store.dispatch(y),onTaskMove:n.onTaskMove,onTaskResize:n.onTaskResize,onTaskProgressChange:n.onTaskProgressChange,isBarReprioritizeEnabled:n.isBarReprioritizeEnabled,onBarReorderDrag:n.onBarReorderDrag,onTaskClick:y=>{this.eventBus.emit("taskClick",y)},onTaskDblClick:y=>{this.eventBus.emit("taskDblClick",y)},onHover:(y,r,c,f)=>{var v;y?this.tooltipManager.show(y,r,c,f):this.tooltipManager.hide();try{(v=n.onHover)==null||v.call(n,y,r,c,f)}catch{}},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight,scrollManager:{getScrollPosition:()=>this.scrollManager.getScrollPosition(),setScrollPosition:(y,r)=>this.scrollManager.setScrollPosition(y,r)}}))}if(this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((h,y)=>{this.store.dispatch({type:"SELECT_TASK",taskId:h,multi:y.ctrlKey||y.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(h))}),this.treeGrid.onRowDblClick(h=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(h))}),this.treeGrid.onExpandToggle(h=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:h})}),this.wireCallbacks(n),typeof ResizeObserver=="function")this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container);else{const h=()=>{this.destroyed||this.resize()};window.addEventListener("resize",h),this._fallbackResizeHandler=h}this.resize(),this.render()}setData(t,n){this.store.dispatch({type:"SET_DATA",tasks:t,dependencies:n})}pushRemoteEvent(t){if(this.destroyed)return;if(!t||typeof t!="object"){lt("remote:dropped-malformed",{reason:"not-object"});return}if(t.version!==1){lt("remote:dropped-malformed",{reason:"bad-version",version:t.version});return}if(lt("remote:received",{kind:t.kind,source:t.source,ts:t.ts}),t.kind==="bulk.replace"){this.lastAppliedTs.clear();const d=Jn(this.store.getState(),t);for(const u of d)this.store.dispatch(u);lt("remote:applied",{kind:"bulk.replace",taskCount:t.tasks.length});return}const n=Jn(this.store.getState(),t),s=t.ts;let o=0,i=0,a=0,l=0;for(const d of n){let u=null;if(d.type==="UPDATE_TASK"?u=d.taskId:d.type==="ADD_TASK"?u=d.task.id:d.type==="REMOVE_TASK"&&(u=d.taskId),u&&typeof s=="number"){const h=this.lastAppliedTs.get(u);if(h!==void 0&&s<h){l++;continue}}this.store.dispatch(d),u&&typeof s=="number"&&this.lastAppliedTs.set(u,s),d.type==="UPDATE_TASK"?o++:d.type==="ADD_TASK"?i++:d.type==="REMOVE_TASK"&&a++}l>0&&lt("remote:dropped-stale",{kind:t.kind,count:l}),o+i+a>0&&lt("remote:applied",{kind:t.kind,...o>0?{merged:o}:{},...i>0?{added:i}:{},...a>0?{removed:a}:{}})}getDisplayState(){const t=this.store.getState(),n=t.timeCursorDate;return!n||!this.replayProvider?t:this.replayProvider.snapshotAt(n)??t}registerReplayProvider(t){return this.replayProvider=t,()=>{this.replayProvider===t&&(this.replayProvider=null)}}setTimeCursor(t){this.store.dispatch({type:"SET_TIME_CURSOR",date:t})}getTimeCursor(){return this.store.getState().timeCursorDate??null}getState(){return this.store.getState()}hitTestAt(t,n){const s=this.rootEl.getBoundingClientRect();if(!(t>=s.left&&t<=s.right&&n>=s.top&&n<=s.bottom))return{zone:"outside"};const i=this.getDisplayState(),{config:a,scrollX:l,scrollY:d,flatVisibleIds:u,tasks:h}=i,{headerHeight:y,rowHeight:r}=a,c=this.gridPanel.getBoundingClientRect(),f=this.timelinePanel.getBoundingClientRect(),v=t>=c.left&&t<=c.right&&n>=c.top&&n<=c.bottom&&c.width>0,b=t>=f.left&&t<=f.right&&n>=f.top&&n<=f.bottom;if(b&&n-f.top<y){const S=t-f.left+l;let k;try{k=this.timeScale.xToDate(S)}catch{k=new Date}const E=n-f.top,D=(()=>{try{return this.timeScale.getHeaderRows()}catch{return[]}})(),C=Math.max(1,D.length),M=y/C,L=Math.min(C-1,Math.max(0,Math.floor(E/M))),R=xi(i.zoomLevel,C,L);return{zone:"date-header",date:k,level:R}}const g=y,p=(b?n-f.top:n-c.top)-g;if(p<0)return{zone:"outside"};const w=Math.floor((p+d)/r),T=(S=>S<0||S>=u.length?null:h.get(u[S])??null)(w);if(b&&T){if(T.status==="group-header")return{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:w};const S=this.layouts.find(k=>k.taskId===T.id)??null;if(S){const k=t-f.left+l;if(k>=S.x&&k<=S.x+S.width){const C=k<=S.x+6?"left-edge":k>=S.x+S.width-6?"right-edge":"body";return{zone:"bar",task:T,rowIndex:w,barType:C}}}}if(v&&T)return T.status==="group-header"?{zone:"bucket-header",bucketTask:T,bucketId:T.groupId??null,rowIndex:w}:{zone:"row-label",task:T,rowIndex:w};if(b){const S=t-f.left+l,k=n-f.top;try{const E=this.dependencyRenderer.hitTest(S,k,i,this.layouts,d,y);if(E)return{zone:"dependency",depId:E}}catch{}}if(w>=u.length){let S;try{S=this.timeScale.xToDate(t-f.left+l)}catch{S=new Date}return{zone:"below-rows",date:S}}if(b){let S;try{S=this.timeScale.xToDate(t-f.left+l)}catch{S=new Date}const k=Bi(i,w);return{zone:"canvas-empty",date:S,rowIndex:w,nearestTask:T,bucketId:k}}return{zone:"outside"}}capabilities(){const t=this;return{version:"0.187.0",pushRemoteEvent:typeof this.pushRemoteEvent=="function",timeCursor:!0,history:!!t.history,replayProvider:!!this.replayProvider,pluginsInstalled:this.plugins.map(n=>n.name).join(",")}}getLastAppliedTs(t="default"){if(this.lastAppliedTs.size===0)return null;let n=-1/0;for(const s of this.lastAppliedTs.values())s>n&&(n=s);return Number.isFinite(n)?n:null}updateTask(t,n){this.store.dispatch({type:"UPDATE_TASK",taskId:t,changes:n})}addTask(t){this.store.dispatch({type:"ADD_TASK",task:t})}removeTask(t){this.store.dispatch({type:"REMOVE_TASK",taskId:t})}setZoom(t){this.store.dispatch({type:"SET_ZOOM",level:t}),this.eventBus.emit("viewChange",t)}scrollToDate(t){const n=typeof t=="string"?new Date(t):t,s=this.timeScale.dateToX(n),o=this.timelinePanel.clientWidth,i=Math.max(0,s-o/2);this.scrollManager.scrollToX(i)}scrollToTask(t){const n=this.store.getState(),s=n.flatVisibleIds.indexOf(t);if(s===-1)return;const{rowHeight:o,headerHeight:i}=n.config,a=this.timelinePanel.clientHeight-i,l=Math.max(0,s*o-a/2+o/2);this.scrollManager.scrollToY(l);const d=n.tasks.get(t);d&&this.scrollToDate(d.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(t){this.store.getState().expandedIds.has(t)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}collapseTask(t){this.store.getState().expandedIds.has(t)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:t})}getVisibleDateRange(){const t=this.store.getState();return{start:t.dateRange.start.toISOString().split("T")[0],end:t.dateRange.end.toISOString().split("T")[0]}}use(t){const n=this.createPluginHost();if(t.install(n),t.middleware){const s=(o,i,a)=>{t.middleware(o,a)};this.pluginMiddlewares.push(s),this.rebuildStoreWithMiddleware()}this.plugins.push(t)}render(){if(this.destroyed)return;this.renderScheduled=!1;const t=this.getDisplayState(),n=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(t,n),this.layouts=this.layoutEngine.computeLayouts(t.flatVisibleIds,t.tasks,this.timeScale,t.config);const s=this.timeScale.getTotalWidth(),o=t.config.headerHeight+t.flatVisibleIds.length*t.config.rowHeight;this.scrollManager.setContentSize(s,o);const i=this.timelinePanel.clientWidth,a=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,a),this.canvasRenderer.render(t,this.layouts,this.timeScale),t.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const d=l.getContext("2d");d&&this.dependencyRenderer.render(d,t,this.layouts,t.config.theme,t.scrollX,t.scrollY,t.config.headerHeight)}}this.treeGrid.render(t,t.tree),this.treeGrid.setScrollY(t.scrollY),this.treeGrid.clearHighlight();for(const l of t.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const d=this.timelinePanel.querySelector("canvas");if(d){const u=d.getContext("2d");u&&l.renderCanvas(u,t,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,t)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){if(this.destroyed=!0,this.resizeObserver)this.resizeObserver.disconnect();else{const t=this._fallbackResizeHandler;t&&window.removeEventListener("resize",t)}this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const t of this.plugins)t.destroy&&t.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(t,n){const s=n??(this.timelinePanel.clientWidth||800);return new ns(t.zoomLevel,t.dateRange,s)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(t){t.onTaskClick&&this.eventBus.on("taskClick",(...n)=>{const s=n[0];s&&t.onTaskClick(s)}),t.onTaskDblClick&&this.eventBus.on("taskDblClick",(...n)=>{const s=n[0];s&&t.onTaskDblClick(s)}),t.onTaskMove&&this.eventBus.on("taskMove",(...n)=>{t.onTaskMove(n[0],n[1],n[2])}),t.onTaskResize&&this.eventBus.on("taskResize",(...n)=>{t.onTaskResize(n[0],n[1],n[2])}),t.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...n)=>{t.onTaskProgressChange(n[0],n[1])}),t.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...n)=>{t.onDependencyCreate(n[0],n[1],n[2])}),t.onDependencyClick&&this.eventBus.on("dependencyClick",(...n)=>{t.onDependencyClick(n[0])}),t.onViewChange&&this.eventBus.on("viewChange",(...n)=>{const s=this.store.getState();t.onViewChange(n[0],s.dateRange.start.toISOString().split("T")[0],s.dateRange.end.toISOString().split("T")[0])}),t.onTaskSelect&&this.store.subscribe(()=>{const n=this.store.getState();t.onTaskSelect(Array.from(n.selectedIds))})}createPluginHost(){const t=this,n={getState:()=>this.store.getState(),dispatch:s=>this.store.dispatch(s),on:(s,o)=>this.eventBus.on(s,o),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:s=>this.timeScale.dateToX(s),xToDate:s=>this.timeScale.xToDate(s),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const s=this.store.getState(),{tree:o,flatIds:i}=Be(s.tasks,s.expandedIds);s.tree=o,s.flatVisibleIds.length=0;for(const a of i)s.flatVisibleIds.push(a)}};return n.__gantt=t,n}rebuildStoreWithMiddleware(){const t=this.store.getState();this.unsubscribeStore(),this.store=new ln(t,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}}function xi(e,t,n){if(t===2){if(e==="day")return n===0?"month":"day";if(e==="week")return n===0?"month":"week";if(e==="month")return n===0?"year":"month";if(e==="quarter")return n===0?"year":"quarter"}return e}function Bi(e,t){if(t<0||t>=e.flatVisibleIds.length)return null;let n=e.tasks.get(e.flatVisibleIds[t]);for(;n;){if(n.status==="group-header")return n.groupId??n.id;if(!n.parentId)break;n=e.tasks.get(n.parentId)}const s=e.tasks.get(e.flatVisibleIds[t]);return(s==null?void 0:s.groupId)??null}function ys(e){const t=[],n=new Set;e.parentId&&(t.push(e.parentId),n.add(e.parentId));for(const s of e.additionalParentIds??[])n.has(s)||(n.add(s),t.push(s));return t}function Ts(e,t){const n=t instanceof Map?Array.from(t.values()):t,s=new Map;for(const a of n)for(const l of ys(a)){let d=s.get(l);d||(d=[],s.set(l,d)),d.push(a.id)}const o=new Set,i=[e];for(;i.length>0;){const a=i.pop(),l=s.get(a);if(l)for(const d of l)o.has(d)||(o.add(d),i.push(d))}return o}function Fi(e,t){const n=Ts(e,t),s=t instanceof Map?t:new Map(t.map(i=>[i.id,i]));let o=0;for(const i of n){const a=s.get(i);a&&typeof a.hours=="number"&&(o+=a.hours)}return o}const Ui=new Set(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function hn(e){return{tasks:Array.from(e.tasks.values()).map(t=>({...t})),dependencies:Array.from(e.dependencies.values()).map(t=>({...t}))}}function Yi(e){const t=(e==null?void 0:e.depth)??20;let n=null,s=[],o=[],i=!1,a=null,l=null,d=null;function u(c){s.push(c),s.length>t&&s.shift()}function h(){if(!n||s.length===0)return;const c=hn(n.getState()),f=s.pop();o.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function y(){if(!n||o.length===0)return;const c=hn(n.getState()),f=o.pop();s.push(c),i=!0,n.dispatch({type:"SET_DATA",tasks:f.tasks,dependencies:f.dependencies}),i=!1}function r(c){(c.ctrlKey||c.metaKey)&&(c.key==="z"||c.key==="Z")&&(c.shiftKey?(c.preventDefault(),y()):(c.preventDefault(),h()))}return{name:"UndoRedoPlugin",install(c){n=c,d=c.on("render",()=>{if(l)return;const f=document.querySelector(".nimbus-gantt");f&&(l=f.parentElement??f,l.getAttribute("tabindex")||l.setAttribute("tabindex","-1"),a=r,l.addEventListener("keydown",a))})},middleware(c,f){if(i){f(c);return}if(Ui.has(c.type)&&n){const v=hn(n.getState());u(v),o=[]}f(c)},destroy(){a&&l&&l.removeEventListener("keydown",a),d&&d(),n=null,l=null,a=null,s=[],o=[]}}}const bt=["day","week","month","quarter"];function Wi(e){return e.selectedIds.size===0?null:e.selectedIds.values().next().value??null}function fn(e,t){for(const n of t.tasks.values())if(n.parentId===e)return!0;return!1}function Xi(){let e=null,t=null,n=null,s=null;function o(i){if(!e)return;const a=e.getState(),{flatVisibleIds:l}=a,d=Wi(a);switch(i.key){case"ArrowUp":{if(i.preventDefault(),l.length===0)return;if(!d)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const u=l.indexOf(d);u>0&&e.dispatch({type:"SELECT_TASK",taskId:l[u-1]})}break}case"ArrowDown":{if(i.preventDefault(),l.length===0)return;if(!d)e.dispatch({type:"SELECT_TASK",taskId:l[0]});else{const u=l.indexOf(d);u<l.length-1&&e.dispatch({type:"SELECT_TASK",taskId:l[u+1]})}break}case"ArrowRight":{if(d)if(fn(d,a))if(!a.expandedIds.has(d))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d});else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:a.scrollX+u})}break}case"ArrowLeft":{if(d)if(fn(d,a))if(a.expandedIds.has(d))i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d});else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}else{const u=e.getTimeScale().getColumnWidth();e.dispatch({type:"SET_SCROLL_X",x:Math.max(0,a.scrollX-u)})}break}case"Enter":{if(!d)return;i.preventDefault();const u=a.tasks.get(d);if(u&&n){const h=new CustomEvent("nimbus-gantt:taskDblClick",{detail:u,bubbles:!0});n.dispatchEvent(h)}break}case"Escape":{i.preventDefault(),e.dispatch({type:"DESELECT_ALL"});break}case"Delete":case"Backspace":{if(!d)return;const u=i.target;if(u.tagName==="INPUT"||u.tagName==="TEXTAREA")return;i.preventDefault();const h=a.tasks.get(d);if(h&&n){const y=new CustomEvent("nimbus-gantt:taskDelete",{detail:h,bubbles:!0});n.dispatchEvent(y)}break}case"Home":{i.preventDefault(),e.dispatch({type:"SET_SCROLL",x:0,y:0}),l.length>0&&e.dispatch({type:"SELECT_TASK",taskId:l[0]});break}case"End":{if(i.preventDefault(),l.length>0){const u=l[l.length-1],h=(l.length-1)*a.config.rowHeight;e.dispatch({type:"SET_SCROLL_Y",y:Math.max(0,h-a.config.rowHeight*2)}),e.dispatch({type:"SELECT_TASK",taskId:u})}break}case"+":case"=":{i.preventDefault();const u=bt.indexOf(a.zoomLevel);u>0&&e.dispatch({type:"SET_ZOOM",level:bt[u-1]});break}case"-":{if(i.ctrlKey||i.metaKey)return;i.preventDefault();const u=bt.indexOf(a.zoomLevel);u<bt.length-1&&e.dispatch({type:"SET_ZOOM",level:bt[u+1]});break}case" ":{if(!d)return;const u=i.target;if(u.tagName==="INPUT"||u.tagName==="TEXTAREA"||u.tagName==="BUTTON")return;fn(d,a)&&(i.preventDefault(),e.dispatch({type:"TOGGLE_EXPAND",taskId:d}));break}}}return{name:"KeyboardPlugin",install(i){e=i,s=i.on("render",()=>{if(n)return;const a=document.querySelector(".nimbus-gantt");a&&(n=a.parentElement??a,n.getAttribute("tabindex")||n.setAttribute("tabindex","0"),t=o,n.addEventListener("keydown",t))})},destroy(){t&&n&&n.removeEventListener("keydown",t),s&&s(),e=null,n=null,t=null}}}const bs="#D4A017",zi="rgba(212, 160, 23, 0.25)",Gi=[6,4],Vi=1,Ki=2,ji=4,vs=8,ws=10,Ss=16,qi=6;function Zi(){let e=null;return{name:"MilestonePlugin",install(t){e=t},renderCanvas(t,n,s){if(!e)return;const{config:o,scrollX:i,scrollY:a}=n,{theme:l}=o,d=o.headerHeight,u=s.filter(r=>r.isMilestone);if(u.length===0)return;t.save();const h=d,y=t.canvas.height/(window.devicePixelRatio||1)-h;t.beginPath(),t.rect(0,h,t.canvas.width/(window.devicePixelRatio||1),y),t.clip(),t.translate(-i,0);for(const r of u){const c=r.x,f=r.barY-a,v=r.barHeight,b=f+v/2,g=r.color===l.barDefaultColor?bs:r.color||bs;t.save(),t.beginPath(),t.strokeStyle=zi,t.lineWidth=Vi,t.setLineDash(Gi),t.moveTo(c,h),t.lineTo(c,h+y),t.stroke(),t.setLineDash([]),t.restore();const p=(v-Ki*2)/2;t.save(),t.beginPath(),t.moveTo(c,b-p),t.lineTo(c+p,b),t.lineTo(c,b+p),t.lineTo(c-p,b),t.closePath(),t.fillStyle=g,t.fill(),t.strokeStyle=ks(g,.25),t.lineWidth=1,t.stroke(),t.restore();const w=c+p+ji,m=b-Ss/2;if(t.save(),t.beginPath(),t.strokeStyle=ks(g,.15),t.lineWidth=1.5,t.moveTo(w,m),t.lineTo(w,m+Ss),t.stroke(),t.beginPath(),t.moveTo(w,m),t.lineTo(w+vs,m+ws/2),t.lineTo(w,m+ws),t.closePath(),t.fillStyle=g,t.fill(),t.restore(),r.label){const T=w+vs+qi,S=b;t.save(),t.font=`600 ${l.fontSize}px ${l.fontFamily}`,t.textBaseline="middle",t.textAlign="left",t.fillStyle=l.gridTextColor,t.fillText(r.label,T,S),t.restore()}}t.restore()},destroy(){e=null}}}function ks(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}const Ji="rgba(100, 116, 139, 0.12)",Qi="rgba(100, 116, 139, 0.25)",Es="#334155",ea="rgba(100, 116, 139, 0.2)",ta="#475569",na=8,sa=6,oa=2,Ve=5,ia=12,aa=28,ra=8;function la(){let e=null;const t=new Set;let n=[],s=new Map,o=[],i=null,a=null,l=null;function d(h){const y=new Map,r=[];for(const c of h.flatVisibleIds){const f=h.tasks.get(c);if(f)if(f.groupId){let v=y.get(f.groupId);v||(v={groupId:f.groupId,groupName:f.groupName||f.groupId,taskIds:[],collapsed:t.has(f.groupId)},y.set(f.groupId,v)),v.taskIds.push(c)}else r.push(c)}n=Array.from(y.values()),o=[],s=new Map;for(const c of r)o.push(c);for(const c of n){const f=o.length,v=`__group_header__${c.groupId}`;if(o.push(v),s.set(f,c),!c.collapsed)for(const b of c.taskIds)o.push(b)}}function u(h){if(t.has(h)?t.delete(h):t.add(h),e){const y=e.getState();e.dispatch({type:"SET_SCROLL",x:y.scrollX,y:y.scrollY})}}return{name:"GroupingPlugin",install(h){e=h,l=h.on("render",()=>{if(a)return;const y=document.querySelector(".nimbus-gantt");y&&(a=y.parentElement??y,i=r=>{if(!e)return;const c=e.getState(),f=y.querySelector(".ng-timeline-panel");if(!f)return;const v=f.getBoundingClientRect(),b=r.clientY-v.top,g=c.config.headerHeight;if(b<g)return;const p=b-g+c.scrollY,w=Math.floor(p/c.config.rowHeight),m=s.get(w);m&&(r.preventDefault(),r.stopPropagation(),u(m.groupId))},a.addEventListener("click",i))})},middleware(h,y){if(y(h),!e)return;const r=e.getState();let c=!1;for(const f of r.tasks.values())if(f.groupId){c=!0;break}if(!c){n=[],s=new Map,o=[...r.flatVisibleIds];return}if(d(r),t.size>0){const f=new Set;for(const v of n)if(v.collapsed)for(const b of v.taskIds)f.add(b);if(f.size>0){const v=r.flatVisibleIds.filter(b=>!f.has(b));if(v.length!==r.flatVisibleIds.length){r.flatVisibleIds.length=0;for(const b of v)r.flatVisibleIds.push(b)}}}},renderCanvas(h,y,r){if(!e||n.length===0)return;const{config:c,scrollX:f,scrollY:v}=y,{theme:b}=c,g=c.headerHeight,p=c.rowHeight,w=h.canvas.width/(window.devicePixelRatio||1),m=h.canvas.height/(window.devicePixelRatio||1)-g;h.save(),h.beginPath(),h.rect(0,g,w,m),h.clip();let T=0;const S=[];for(const k of y.flatVisibleIds){const E=y.tasks.get(k);E&&!E.groupId&&S.push(k)}T=S.length;for(const k of n){const E=g+T*p-v;if(E+p>=g&&E<g+m){h.fillStyle=Ji,h.fillRect(0,E,w,p),h.beginPath(),h.strokeStyle=Qi,h.lineWidth=1,h.moveTo(0,Math.round(E+p)+.5),h.lineTo(w,Math.round(E+p)+.5),h.stroke();const D=ia,C=E+p/2;h.save(),h.beginPath(),h.fillStyle=Es,k.collapsed?(h.moveTo(D,C-Ve),h.lineTo(D+Ve,C),h.lineTo(D,C+Ve)):(h.moveTo(D-Ve/2,C-Ve/2),h.lineTo(D+Ve/2,C-Ve/2),h.lineTo(D,C+Ve/2)),h.closePath(),h.fill(),h.restore(),h.save(),h.font=`600 ${b.fontSize}px ${b.fontFamily}`,h.textBaseline="middle",h.textAlign="left",h.fillStyle=Es;const M=aa,L=E+p/2;h.fillText(k.groupName,M,L);const R=h.measureText(k.groupName).width;h.restore();const x=`${k.taskIds.length}`;h.save(),h.font=`${b.fontSize-1}px ${b.fontFamily}`;const _=h.measureText(x).width+sa*2,H=b.fontSize+oa*2,W=M+R+ra,K=L-H/2;h.beginPath();const q=na;h.moveTo(W+q,K),h.lineTo(W+_-q,K),h.arcTo(W+_,K,W+_,K+q,q),h.lineTo(W+_,K+H-q),h.arcTo(W+_,K+H,W+_-q,K+H,q),h.lineTo(W+q,K+H),h.arcTo(W,K+H,W,K+H-q,q),h.lineTo(W,K+q),h.arcTo(W,K,W+q,K,q),h.closePath(),h.fillStyle=ea,h.fill(),h.fillStyle=ta,h.textBaseline="middle",h.textAlign="center",h.fillText(x,W+_/2,L),h.restore()}T+=1,k.collapsed||(T+=k.taskIds.length)}h.restore()},destroy(){i&&a&&a.removeEventListener("click",i),l&&l(),e=null,a=null,i=null,t.clear(),n=[],s=new Map,o=[]}}}const ct="__bucket_header__";function Ds(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function ca(e){return e.groupId??null}function da(e){if(e.length===0)return 0;let t=0;for(const n of e)t+=n.progress??0;return t/e.length}function ua(e){const t=[...e.buckets].sort((r,c)=>r.order-c.order),n=new Map;t.forEach((r,c)=>n.set(r.id,c));const s=e.getBucket??ca,o=e.getBucketProgress??da,i=new Set;if(e.startCollapsed)for(const r of t)i.add(r.id);let a=null,l=[],d=null;function u(r,c){l=t.map(f=>({config:f,taskIds:[],allTaskIds:[],collapsed:i.has(f.id),progress:0,startDate:null,endDate:null,totalHours:0,totalLogged:0}));for(const f of c){const v=r.tasks.get(f);if(!v)continue;const b=s(v);if(!b)continue;const g=n.get(b);g!==void 0&&l[g].taskIds.push(f)}for(const[f,v]of r.tasks){if(f.startsWith(ct))continue;const b=s(v);if(!b)continue;const g=n.get(b);g!==void 0&&l[g].allTaskIds.push(f)}for(const f of l){if(f.allTaskIds.length===0){f.progress=0,f.startDate=null,f.endDate=null,f.totalHours=0,f.totalLogged=0;continue}const v=[];let b=1/0,g=-1/0,p=0,w=0;for(const m of f.allTaskIds){const T=r.tasks.get(m);if(!T)continue;if(v.push(T),T.startDate){const k=pt(T.startDate).getTime();!isNaN(k)&&k<b&&(b=k)}if(T.endDate){const k=pt(T.endDate).getTime();!isNaN(k)&&k>g&&(g=k)}const S=T.metadata;typeof(S==null?void 0:S.hoursHigh)=="number"&&(p+=S.hoursHigh),typeof(S==null?void 0:S.hoursLogged)=="number"&&(w+=S.hoursLogged)}f.startDate=isFinite(b)?new Date(b):null,f.endDate=isFinite(g)?new Date(g):null,f.totalHours=p,f.totalLogged=w,f.progress=Math.max(0,Math.min(1,o(v)))}}function h(r){if(!r.startDate||!r.endDate)return null;const c=r.totalHours>0&&r.totalLogged>=r.totalHours,f=r.totalHours>0?Math.round(r.totalLogged/r.totalHours*100):Math.round(r.progress*100),v=r.totalHours>0?`${r.totalHours}h (${f}% budget)`:`${r.allTaskIds.length} items`;return{id:`${ct}${r.config.id}`,name:v,startDate:Ds(r.startDate),endDate:Ds(r.endDate),progress:r.progress,color:c?"#f59e0b":r.config.color,status:"group-header",groupBg:r.config.bgTint||void 0,groupColor:r.config.color,groupId:r.config.id,groupName:r.config.label,title:r.config.label,hours:r.totalHours,hoursLabel:`${r.allTaskIds.length} · ${r.totalHours}h`,assignee:"",sortOrder:r.config.order,metadata:{__bucketHeader:!0,bucketId:r.config.id,hoursHigh:r.totalHours,taskCount:r.allTaskIds.length}}}function y(r){if(i.has(r)?i.delete(r):i.add(r),a){const c=a.getState();a.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}}return{name:"PriorityGroupingPlugin",install(r){a=r,d=r.on("taskClick",((...c)=>{const f=c[0];let v=null;typeof f=="string"?v=f:f&&typeof f=="object"&&"id"in f&&(v=String(f.id)),v&&v.startsWith(ct)&&y(v.substring(ct.length))}))},middleware(r,c){if(c(r),!a)return;const f=a.getState(),v=[];for(const p of f.tasks.keys())p.startsWith(ct)&&v.push(p);for(const p of v)f.tasks.delete(p);const b=f.flatVisibleIds.filter(p=>!p.startsWith(ct));let g=!1;for(const p of f.tasks.values())if(s(p)!=null){g=!0;break}if(!g){if(l=[],b.length!==f.flatVisibleIds.length){f.flatVisibleIds.length=0;for(const p of b)f.flatVisibleIds.push(p)}return}u(f,b);for(const p of l){if(p.allTaskIds.length===0)continue;const w=h(p);if(w){f.tasks.set(w.id,w);for(const m of p.allTaskIds){const T=f.tasks.get(m);T&&(T.parentId=w.id)}p.collapsed?f.expandedIds.delete(w.id):f.expandedIds.add(w.id)}}a.rebuildTree()},destroy(){d&&d(),a=null,l=[],d=null,i.clear()}}}const ga=[{id:"top-priority",label:"NOW",color:"#dc2626",bgTint:"#fef2f2",order:0},{id:"active",label:"NEXT",color:"#d97706",bgTint:"#fffbeb",order:1},{id:"follow-on",label:"PLANNED",color:"#059669",bgTint:"#ecfdf5",order:2},{id:"proposed",label:"PROPOSED",color:"#2563eb",bgTint:"#eff6ff",order:3},{id:"deferred",label:"HOLD",color:"#94a3b8",bgTint:"#f8fafc",order:4}];function ha(e){let t=0,n=0,s=!1;for(const o of e){const i=o.metadata,a=typeof(i==null?void 0:i.hoursHigh)=="number"?i.hoursHigh:0,l=typeof(i==null?void 0:i.hoursLogged)=="number"?i.hoursLogged:0;a>0&&(t+=a,n+=l,s=!0)}if(!s){if(e.length===0)return 0;let o=0;for(const i of e)o+=i.progress??0;return o/e.length}return t>0?Math.min(n/t,1):0}const Cs=864e5,fa=6,pa=2,ma=2,ya=.18,Ta=.4;function Is(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function pn(e,t){return Math.round((t.getTime()-e.getTime())/Cs)}function dt(e,t){return new Date(e.getTime()+t*Cs)}function mn(e,t){const n=Array.from(e.keys());if(n.length===0)return{criticalTaskIds:new Set,criticalDependencyIds:new Set,taskAnalysis:new Map,projectDuration:0};const s=new Map,o=new Map,i=new Map;for(const D of n)s.set(D,[]),o.set(D,[]),i.set(D,0);for(const D of t.values()){if((D.type||"FS")!=="FS"||!e.has(D.source)||!e.has(D.target))continue;const M=D.lag||0;s.get(D.source).push({target:D.target,lag:M,depId:D.id}),o.get(D.target).push({source:D.source,lag:M,depId:D.id}),i.set(D.target,(i.get(D.target)||0)+1)}const a=new Map,l=new Map,d=new Map;for(const[D,C]of e){const M=Is(C.startDate),L=Is(C.endDate);l.set(D,M),d.set(D,L),a.set(D,Math.max(pn(M,L),0))}const u=new Map,h=new Map,y=[],r=[],c=new Map(i);for(const D of n)c.get(D)===0&&(r.push(D),u.set(D,l.get(D)),h.set(D,d.get(D)));for(;r.length>0;){const D=r.shift();y.push(D),u.get(D);const C=h.get(D);for(const M of s.get(D)){const{target:L,lag:R}=M,x=dt(C,R),$=u.get(L);(!$||x.getTime()>$.getTime())&&(u.set(L,x),h.set(L,dt(x,a.get(L))));const _=c.get(L)-1;c.set(L,_),_===0&&r.push(L)}}for(const D of n)u.has(D)||(u.set(D,l.get(D)),h.set(D,d.get(D)),y.push(D));let f=-1/0;for(const D of h.values())D.getTime()>f&&(f=D.getTime());const v=new Date(f);let b=1/0;for(const D of u.values())D.getTime()<b&&(b=D.getTime());const g=new Date(b),p=pn(g,v),w=new Map,m=new Map;for(const D of n)s.get(D).length===0&&(m.set(D,v),w.set(D,dt(v,-a.get(D))));for(let D=y.length-1;D>=0;D--){const C=y[D];if(!m.has(C)){let M=1/0;for(const L of s.get(C)){const R=w.get(L.target);if(R){const x=dt(R,-L.lag);x.getTime()<M&&(M=x.getTime())}}M===1/0?m.set(C,v):m.set(C,new Date(M)),w.set(C,dt(m.get(C),-a.get(C)))}}for(const D of n)m.has(D)||(m.set(D,v),w.set(D,dt(v,-a.get(D))));const T=.5,S=new Set,k=new Map;for(const D of n){const C=u.get(D),M=h.get(D),L=w.get(D),R=m.get(D),x=pn(C,L),$=Math.abs(x)<T;$&&S.add(D),k.set(D,{earlyStart:C,earlyFinish:M,lateStart:L,lateFinish:R,totalFloat:x,isCritical:$})}const E=new Set;for(const D of t.values())(D.type||"FS")==="FS"&&S.has(D.source)&&S.has(D.target)&&E.add(D.id);return{criticalTaskIds:S,criticalDependencyIds:E,taskAnalysis:k,projectDuration:p}}function ba(){let e,t=null,n=[];function s(){const o=e.getState();t=mn(o.tasks,o.dependencies)}return{name:"CriticalPathPlugin",install(o){e=o,s(),n.push(e.on("stateChange",()=>{s()}))},middleware(o,i){i(o),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(o.type)&&s()},renderCanvas(o,i,a){if(!t||t.criticalTaskIds.size===0)return;const{theme:l,headerHeight:d,rowHeight:u,barHeight:h}=i.config,y=l.criticalPathColor||"#E53E3E",r=i.scrollX,c=i.scrollY,f=d,v=e.getTimeScale(),b=new Map;for(const m of a)b.set(m.taskId,m);o.save(),o.beginPath(),o.rect(0,f,o.canvas.width,o.canvas.height-f),o.clip(),o.translate(-r,0);for(const m of a){const T=t.taskAnalysis.get(m.taskId);if(!T||T.isCritical||T.totalFloat<=0)continue;const S=m.barY-c,k=h*Ta,E=m.x+m.width,C=v.dateToX(T.lateFinish)-E;C>1&&(o.fillStyle=m.color,o.globalAlpha=ya,o.fillRect(E,S+h-k,C,k),o.globalAlpha=1)}for(const m of a){if(!t.criticalTaskIds.has(m.taskId))continue;const T=m.x,S=m.barY-c,k=m.width,E=m.barHeight;if(!(S+E<f||S>o.canvas.height)){o.save(),o.shadowColor=y,o.shadowBlur=fa;for(let D=0;D<pa;D++){o.strokeStyle=y,o.lineWidth=ma,o.beginPath();const C=l.barBorderRadius,M=Math.min(C,k/2,E/2);o.moveTo(T+M,S),o.lineTo(T+k-M,S),o.arcTo(T+k,S,T+k,S+M,M),o.lineTo(T+k,S+E-M),o.arcTo(T+k,S+E,T+k-M,S+E,M),o.lineTo(T+M,S+E),o.arcTo(T,S+E,T,S+E-M,M),o.lineTo(T,S+M),o.arcTo(T,S,T+M,S,M),o.closePath(),o.stroke()}o.restore()}}const g=6,p=4,w=12;for(const m of i.dependencies.values()){if(!t.criticalDependencyIds.has(m.id))continue;const T=b.get(m.source),S=b.get(m.target);if(!T||!S)continue;const k=T.x+T.width,E=T.barY+T.barHeight/2-c,D=S.x,C=S.barY+S.barHeight/2-c;o.beginPath(),o.strokeStyle=y,o.lineWidth=l.dependencyWidth+1;const M=k+w,L=D-w;if(o.moveTo(k,E),L>=M)o.lineTo(M,E),o.lineTo(M,C),o.lineTo(D,C);else{const R=(E+C)/2;o.lineTo(M,E),o.lineTo(M,R),o.lineTo(L,R),o.lineTo(L,C),o.lineTo(D,C)}o.stroke(),o.beginPath(),o.moveTo(D,C),o.lineTo(D-g,C-p),o.lineTo(D-g,C+p),o.closePath(),o.fillStyle=y,o.fill()}o.restore()},destroy(){for(const o of n)o();n=[],t=null}}}const va=864e5,wa=.6,Ms=.25,Sa="#38A169",ka="#E53E3E",Ea="#A0AEC0",Da=10,Ca=4,Ke=16,Ia=3;function Ot(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ma(e,t){return Math.round((t.getTime()-e.getTime())/va)}function Aa(e){const t=new Map;for(const s of e.baselineTasks)t.set(s.id,{start:Ot(s.startDate),end:Ot(s.endDate)});let n;return{name:"BaselinePlugin",install(s){n=s},renderCanvas(s,o,i){var v,b;if(t.size===0)return;const{theme:a,headerHeight:l,barHeight:d}=o.config,u=o.scrollX,h=o.scrollY,y=l,r=n.getTimeScale(),c=a.barBorderRadius;s.save(),s.beginPath(),s.rect(0,y,s.canvas.width,s.canvas.height-y),s.clip(),s.translate(-u,0);const f=d*wa;for(const g of i){if(g.isMilestone)continue;const p=t.get(g.taskId);if(!p)continue;const w=g.barY-h;if(w+d+f<y||w>s.canvas.height)continue;const m=r.dateToX(p.start),T=r.dateToX(p.end),S=Math.max(T-m,2),k=w+d+1;Ot(((v=o.tasks.get(g.taskId))==null?void 0:v.startDate)||"");const E=Ot(((b=o.tasks.get(g.taskId))==null?void 0:b.endDate)||""),D=Ma(p.end,E);let C;D<0?C=Sa:D>0?C=ka:C=Ea,s.save(),s.globalAlpha=Ms,s.fillStyle=C;const M=Math.min(c,S/2,f/2);if(s.beginPath(),s.moveTo(m+M,k),s.lineTo(m+S-M,k),s.arcTo(m+S,k,m+S,k+M,M),s.lineTo(m+S,k+f-M),s.arcTo(m+S,k+f,m+S-M,k+f,M),s.lineTo(m+M,k+f),s.arcTo(m,k+f,m,k+f-M,M),s.lineTo(m,k+M),s.arcTo(m,k,m+M,k,M),s.closePath(),s.fill(),s.globalAlpha=Ms*2,s.strokeStyle=C,s.lineWidth=1,s.stroke(),s.restore(),D!==0){const L=D>0?`+${D}d`:`${D}d`;s.save(),s.font=`600 ${Da}px ${a.fontFamily}`;const $=s.measureText(L).width+Ca*2,_=g.x+g.width+4,H=k+(f-Ke)/2;s.globalAlpha=.85,s.fillStyle=C;const W=Ia;s.beginPath(),s.moveTo(_+W,H),s.lineTo(_+$-W,H),s.arcTo(_+$,H,_+$,H+W,W),s.lineTo(_+$,H+Ke-W),s.arcTo(_+$,H+Ke,_+$-W,H+Ke,W),s.lineTo(_+W,H+Ke),s.arcTo(_,H+Ke,_,H+Ke-W,W),s.lineTo(_,H+W),s.arcTo(_,H,_+W,H,W),s.closePath(),s.fill(),s.globalAlpha=1,s.fillStyle="#FFFFFF",s.textAlign="center",s.textBaseline="middle",s.fillText(L,_+$/2,H+Ke/2),s.restore()}}s.restore()},destroy(){}}}const As=5,La=5,Ra=.3,Pa=15;function _a(){let e,t=null,n=0,s=0;const o=[];function i(u){const{rowHeight:h,headerHeight:y}=u.config,r=u.scrollY,c=u.flatVisibleIds.length,f=a(u),v=Math.floor(r/h),b=Math.ceil((r+f)/h);let g=Math.max(0,v-As),p=Math.min(c,b+As);if(Math.abs(s)>0){const m=Math.min(Pa,Math.ceil(Math.abs(s*Ra)/h));s>0?p=Math.min(c,p+m):g=Math.max(0,g-m)}const w=new Set;for(let m=g;m<p&&m<u.flatVisibleIds.length;m++)w.add(u.flatVisibleIds[m]);return{startRow:g,endRow:p,totalRows:c,visibleTaskIds:w}}function a(u){const y=u.flatVisibleIds.length*u.config.rowHeight-u.scrollY;return Math.min(800,Math.max(y,200))}function l(u){const h=performance.now();for(o.push({y:u,time:h});o.length>La;)o.shift();if(o.length>=2){const y=o[0],r=o[o.length-1],c=(r.time-y.time)/1e3;c>0&&(s=(r.y-y.y)/c)}n=u}const d={getVisibleRange(){if(!e)return{startRow:0,endRow:0,totalRows:0,visibleTaskIds:new Set};const u=e.getState();return(!t||u.scrollY!==n)&&(l(u.scrollY),t=i(u)),t},filterLayouts(u){const h=d.getVisibleRange();return h.totalRows===0?[]:u.filter(y=>h.visibleTaskIds.has(y.taskId))},isVisible(u){return d.getVisibleRange().visibleTaskIds.has(u)},getContentHeight(){if(!e)return 0;const u=e.getState();return u.flatVisibleIds.length*u.config.rowHeight+u.config.headerHeight}};return{name:"VirtualScrollPlugin",install(u){e=u},middleware(u,h){if(h(u),["SET_DATA","SET_SCROLL","SET_SCROLL_Y","ADD_TASK","REMOVE_TASK","TOGGLE_EXPAND","EXPAND_ALL","COLLAPSE_ALL"].includes(u.type)&&(t=null,u.type==="SET_SCROLL"||u.type==="SET_SCROLL_Y")){const r=e.getState();l(r.scrollY)}},destroy(){t=null,o.length=0,s=0},api:d}}const Fe=864e5,yn=1,Ls=2,Rs=.5,Ps=2,Nt=8,_s=6,$s=2,Ht=1e4;function Tn(e,t){const n=URL.createObjectURL(e),s=document.createElement("a");s.href=n,s.download=t,document.body.appendChild(s),s.click(),document.body.removeChild(s),URL.revokeObjectURL(n)}function Os(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function st(e){return Math.round(e)+.5}function Ns(e,t){var s;const n=e[t]??((s=e.metadata)==null?void 0:s[t])??"";return n==null?"":String(n)}function Hs(e,t,n,s){const{config:o}=t,i=o.theme,a=o.columns,l=o.rowHeight,d=o.headerHeight;e.fillStyle=i.gridBg,e.fillRect(0,0,n,s),e.fillStyle=i.gridHeaderBg,e.fillRect(0,0,n,d),e.font=`600 ${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridHeaderText,e.textBaseline="middle";let u=0;for(const y of a){const r=y.width??120;e.save(),e.beginPath(),e.rect(u,0,r,d),e.clip(),e.textAlign=y.align==="right"?"right":y.align==="center"?"center":"left";const c=y.align==="right"?u+r-8:y.align==="center"?u+r/2:u+8;e.fillText(y.header,c,d/2),e.restore(),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(u+r,0),e.lineTo(u+r,s),e.stroke(),u+=r}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(0,d),e.lineTo(n,d),e.stroke(),e.font=`${i.fontSize}px ${i.fontFamily}`,e.fillStyle=i.gridTextColor;const h=t.flatVisibleIds;for(let y=0;y<h.length;y++){const r=t.tasks.get(h[y]);if(!r)continue;const c=d+y*l;y%2===1&&(e.fillStyle=i.gridAltRowBg,e.fillRect(0,c,n,l)),e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=.5,e.moveTo(0,c+l),e.lineTo(n,c+l),e.stroke();let f=0;e.fillStyle=i.gridTextColor;for(const v of a){const b=v.width??120,g=Ns(r,v.field);e.save(),e.beginPath(),e.rect(f,c,b,l),e.clip(),e.textBaseline="middle";const p=v.tree?8:0;e.textAlign=v.align==="right"?"right":v.align==="center"?"center":"left";const w=v.align==="right"?f+b-8:v.align==="center"?f+b/2:f+8+p;e.fillText(g,w,c+l/2),e.restore(),f+=b}}e.beginPath(),e.strokeStyle=i.gridBorderColor,e.lineWidth=1,e.moveTo(n-.5,0),e.lineTo(n-.5,s),e.stroke()}function xs(e,t,n,s,o){const{config:i}=t,a=i.theme,l=i.headerHeight,d=i.rowHeight,u=s.getTotalWidth(),h=t.flatVisibleIds.length*d,y=l+h;if(e.fillStyle=a.timelineBg,e.fillRect(o,0,u,y),i.showWeekends){const{start:f,end:v}=t.dateRange,b=new Date(f);b.setUTCHours(0,0,0,0);const g=v.getTime();for(;b.getTime()<=g;){const p=b.getUTCDay();if(p===0||p===6){const w=o+s.dateToX(b),m=new Date(b.getTime()+Fe),T=o+s.dateToX(m);e.fillStyle=a.timelineWeekendBg,e.fillRect(w,l,T-w,h)}b.setTime(b.getTime()+Fe)}}const r=s.getGridLines();e.beginPath(),e.strokeStyle=a.timelineGridColor,e.lineWidth=Rs;for(const f of r){const v=st(o+f);e.moveTo(v,l),e.lineTo(v,y)}e.stroke();for(let f=0;f<t.flatVisibleIds.length;f++)f%2===1&&(e.fillStyle=a.gridAltRowBg,e.fillRect(o,l+f*d,u,d));if(i.showToday){const f=new Date;f.setHours(0,0,0,0);const{start:v,end:b}=t.dateRange;if(f.getTime()>=v.getTime()&&f.getTime()<=b.getTime()){const g=o+s.dateToX(f),p=s.getColumnWidth();e.fillStyle=a.todayBg,e.fillRect(g,l,p,h),e.beginPath(),e.strokeStyle=a.todayLineColor,e.lineWidth=Ls,e.moveTo(st(g),l),e.lineTo(st(g),y),e.stroke()}}const c=a.barBorderRadius;for(const f of n){const v=o+f.x,b=f.barY,g=f.width,p=f.barHeight;if(f.isMilestone){const w=(p-Ps*2)/2,m=b+p/2;e.beginPath(),e.moveTo(v,m-w),e.lineTo(v+w,m),e.lineTo(v,m+w),e.lineTo(v-w,m),e.closePath(),e.fillStyle=f.color,e.fill();continue}if(bn(e,v,b,g,p,c),e.fillStyle=f.color,e.fill(),i.showProgress&&f.progressWidth>0){const w=Os(f.color,.2);e.save(),e.beginPath(),bn(e,v,b,g,p,c),e.clip(),e.fillStyle=w,e.fillRect(v,b,f.progressWidth,p),e.restore()}if(t.selectedIds.has(f.taskId)&&(e.beginPath(),bn(e,v,b,g,p,c),e.strokeStyle=a.barSelectedBorder,e.lineWidth=$s,e.stroke()),f.label){e.save(),e.font=`${a.fontSize}px ${a.fontFamily}`,e.textBaseline="middle";const w=e.measureText(f.label).width,m=b+p/2;w+Nt*2<=g?(e.beginPath(),e.rect(v,b,g,p),e.clip(),e.fillStyle=f.textColor,e.textAlign="left",e.fillText(f.label,v+Nt,m)):(e.fillStyle=a.gridTextColor,e.textAlign="left",e.fillText(f.label,v+g+_s,m)),e.restore()}}$a(e,t,n,a,o),Oa(e,s,i,a,o)}function $a(e,t,n,s,o){if(t.dependencies.size===0)return;const i=new Map;for(const u of n)i.set(u.taskId,u);const a=12,l=6,d=4;e.save();for(const u of t.dependencies.values()){const h=i.get(u.source),y=i.get(u.target);if(!h||!y)continue;const r=u.type||"FS",c=h.barY+h.barHeight/2,f=y.barY+y.barHeight/2;let v,b;const g=r==="FS"||r==="FF",p=r==="FS"||r==="SS";switch(r){case"FS":v=o+h.x+h.width,b=o+y.x;break;case"SS":v=o+h.x,b=o+y.x;break;case"FF":v=o+h.x+h.width,b=o+y.x+y.width;break;case"SF":v=o+h.x,b=o+y.x+y.width;break}const w=g?v+a:v-a,m=p?b-a:b+a,T=g?p?m>=w:b+a>=w:p?b-a<=w:m<=w;if(e.beginPath(),e.strokeStyle=s.dependencyColor,e.lineWidth=s.dependencyWidth,e.moveTo(v,c),T)e.lineTo(w,c),e.lineTo(w,f),e.lineTo(b,f);else{const S=(c+f)/2;e.lineTo(w,c),e.lineTo(w,S),e.lineTo(m,S),e.lineTo(m,f),e.lineTo(b,f)}e.stroke(),e.beginPath(),p?(e.moveTo(b,f),e.lineTo(b-l,f-d),e.lineTo(b-l,f+d)):(e.moveTo(b,f),e.lineTo(b+l,f-d),e.lineTo(b+l,f+d)),e.closePath(),e.fillStyle=s.dependencyColor,e.fill()}e.restore()}function Oa(e,t,n,s,o){const i=n.headerHeight,a=t.getHeaderRows();e.fillStyle=s.timelineHeaderBg,e.fillRect(o,0,t.getTotalWidth(),i);const l=a.length||2,d=i/l;e.textBaseline="middle";for(let u=0;u<a.length;u++){const h=a[u],y=u*d;for(const r of h){const c=o+r.x,f=r.width;e.beginPath(),e.strokeStyle=s.timelineGridColor,e.lineWidth=yn,e.moveTo(st(c+f),y),e.lineTo(st(c+f),y+d),e.stroke(),e.save(),e.beginPath(),e.rect(c,y,f,d),e.clip(),e.fillStyle=s.timelineHeaderText,e.font=u===0?`600 ${s.fontSize}px ${s.fontFamily}`:`${s.fontSize}px ${s.fontFamily}`,e.textAlign="center",e.fillText(r.label,c+f/2,y+d/2),e.restore()}}e.beginPath(),e.strokeStyle=s.gridBorderColor,e.lineWidth=yn,e.moveTo(o,st(i)),e.lineTo(o+t.getTotalWidth(),st(i)),e.stroke()}function bn(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function vt(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function Na(e,t,n,s){const{config:o}=e,i=o.theme,a=o.headerHeight,l=o.rowHeight,d=n.getTotalWidth(),u=s+d,h=e.flatVisibleIds.length*l,y=a+h,r=i.barBorderRadius,c=[];c.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${u}" height="${y}" viewBox="0 0 ${u} ${y}">`),c.push(`<style>text { font-family: ${vt(i.fontFamily)}; font-size: ${i.fontSize}px; }</style>`),c.push(`<rect x="0" y="0" width="${s}" height="${y}" fill="${i.gridBg}" />`),c.push(`<rect x="0" y="0" width="${s}" height="${a}" fill="${i.gridHeaderBg}" />`);let f=0;for(const m of o.columns){const T=m.width??120;c.push(`<text x="${f+8}" y="${a/2}" dominant-baseline="central" font-weight="600" fill="${i.gridHeaderText}">${vt(m.header)}</text>`),c.push(`<line x1="${f+T}" y1="0" x2="${f+T}" y2="${y}" stroke="${i.gridBorderColor}" stroke-width="1" />`),f+=T}for(let m=0;m<e.flatVisibleIds.length;m++){const T=e.tasks.get(e.flatVisibleIds[m]);if(!T)continue;const S=a+m*l;m%2===1&&c.push(`<rect x="0" y="${S}" width="${s}" height="${l}" fill="${i.gridAltRowBg}" />`);let k=0;for(const E of o.columns){const D=E.width??120,C=Ns(T,E.field),M=E.tree?8:0;c.push(`<text x="${k+8+M}" y="${S+l/2}" dominant-baseline="central" fill="${i.gridTextColor}"><![CDATA[${C}]]></text>`),k+=D}c.push(`<line x1="0" y1="${S+l}" x2="${s}" y2="${S+l}" stroke="${i.gridBorderColor}" stroke-width="0.5" />`)}c.push(`<line x1="${s}" y1="0" x2="${s}" y2="${y}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<line x1="0" y1="${a}" x2="${u}" y2="${a}" stroke="${i.gridBorderColor}" stroke-width="1" />`),c.push(`<rect x="${s}" y="0" width="${d}" height="${y}" fill="${i.timelineBg}" />`),c.push(`<rect x="${s}" y="0" width="${d}" height="${a}" fill="${i.timelineHeaderBg}" />`);const v=n.getHeaderRows(),b=v.length||2,g=a/b;for(let m=0;m<v.length;m++){const T=v[m],S=m*g;for(const k of T){const E=s+k.x+k.width/2,D=S+g/2,C=m===0?' font-weight="600"':"";c.push(`<text x="${E}" y="${D}" text-anchor="middle" dominant-baseline="central"${C} fill="${i.timelineHeaderText}">${vt(k.label)}</text>`),c.push(`<line x1="${s+k.x+k.width}" y1="${S}" x2="${s+k.x+k.width}" y2="${S+g}" stroke="${i.timelineGridColor}" stroke-width="${yn}" />`)}}const p=n.getGridLines();for(const m of p)c.push(`<line x1="${s+m}" y1="${a}" x2="${s+m}" y2="${y}" stroke="${i.timelineGridColor}" stroke-width="${Rs}" />`);for(let m=0;m<e.flatVisibleIds.length;m++)m%2===1&&c.push(`<rect x="${s}" y="${a+m*l}" width="${d}" height="${l}" fill="${i.gridAltRowBg}" />`);if(o.showWeekends){const{start:m,end:T}=e.dateRange,S=new Date(m);for(S.setUTCHours(0,0,0,0);S.getTime()<=T.getTime();){if(S.getUTCDay()===0||S.getUTCDay()===6){const k=s+n.dateToX(S),E=new Date(S.getTime()+Fe),D=s+n.dateToX(E);c.push(`<rect x="${k}" y="${a}" width="${D-k}" height="${h}" fill="${i.timelineWeekendBg}" />`)}S.setTime(S.getTime()+Fe)}}if(o.showToday){const m=new Date;m.setHours(0,0,0,0);const{start:T,end:S}=e.dateRange;if(m.getTime()>=T.getTime()&&m.getTime()<=S.getTime()){const k=s+n.dateToX(m),E=n.getColumnWidth();c.push(`<rect x="${k}" y="${a}" width="${E}" height="${h}" fill="${i.todayBg}" />`),c.push(`<line x1="${k}" y1="${a}" x2="${k}" y2="${y}" stroke="${i.todayLineColor}" stroke-width="${Ls}" />`)}}for(const m of t){const T=s+m.x,S=m.barY,k=m.width,E=m.barHeight;if(m.isMilestone){const D=(E-Ps*2)/2,C=S+E/2;c.push(`<polygon points="${T},${C-D} ${T+D},${C} ${T},${C+D} ${T-D},${C}" fill="${m.color}" />`);continue}if(c.push(`<rect x="${T}" y="${S}" width="${k}" height="${E}" rx="${r}" ry="${r}" fill="${m.color}" />`),o.showProgress&&m.progressWidth>0){const D=Os(m.color,.2);c.push(`<clipPath id="clip-${m.taskId}"><rect x="${T}" y="${S}" width="${k}" height="${E}" rx="${r}" ry="${r}" /></clipPath>`),c.push(`<rect x="${T}" y="${S}" width="${m.progressWidth}" height="${E}" fill="${D}" clip-path="url(#clip-${m.taskId})" />`)}if(e.selectedIds.has(m.taskId)&&c.push(`<rect x="${T}" y="${S}" width="${k}" height="${E}" rx="${r}" ry="${r}" fill="none" stroke="${i.barSelectedBorder}" stroke-width="${$s}" />`),m.label){const D=S+E/2;i.fontSize*.6*m.label.length+Nt*2<=k?c.push(`<text x="${T+Nt}" y="${D}" dominant-baseline="central" fill="${m.textColor}">${vt(m.label)}</text>`):c.push(`<text x="${T+k+_s}" y="${D}" dominant-baseline="central" fill="${i.gridTextColor}">${vt(m.label)}</text>`)}}const w=new Map;for(const m of t)w.set(m.taskId,m);for(const m of e.dependencies.values()){const T=w.get(m.source),S=w.get(m.target);if(!T||!S)continue;const k=m.type||"FS",E=T.barY+T.barHeight/2,D=S.barY+S.barHeight/2;let C,M;const L=k==="FS"||k==="FF",R=k==="FS"||k==="SS";switch(k){case"FS":C=s+T.x+T.width,M=s+S.x;break;case"SS":C=s+T.x,M=s+S.x;break;case"FF":C=s+T.x+T.width,M=s+S.x+S.width;break;case"SF":C=s+T.x,M=s+S.x+S.width;break}const x=12,$=6,_=4,H=L?C+x:C-x,W=R?M-x:M+x,K=L?R?W>=H:M+x>=H:R?M-x<=H:W<=H;let q;if(K)q=`M${C},${E} L${H},${E} L${H},${D} L${M},${D}`;else{const F=(E+D)/2;q=`M${C},${E} L${H},${E} L${H},${F} L${W},${F} L${W},${D} L${M},${D}`}c.push(`<path d="${q}" fill="none" stroke="${i.dependencyColor}" stroke-width="${i.dependencyWidth}" />`),R?c.push(`<polygon points="${M},${D} ${M-$},${D-_} ${M-$},${D+_}" fill="${i.dependencyColor}" />`):c.push(`<polygon points="${M},${D} ${M+$},${D-_} ${M+$},${D+_}" fill="${i.dependencyColor}" />`)}return c.push("</svg>"),c.join(`
`)}function Ha(){let e=null;function t(){const a=e,l=a.getState(),d=a.getTimeScale(),{start:u,end:h}=l.dateRange,y=h.getTime()-u.getTime(),r=d.getColumnWidth(),c=l.zoomLevel;let f;switch(c){case"day":f=Math.round(y/Fe);break;case"week":f=Math.ceil(y/(Fe*7));break;case"month":{const b=u.getUTCFullYear(),g=u.getUTCMonth(),p=h.getUTCFullYear(),w=h.getUTCMonth();f=(p-b)*12+(w-g);break}case"quarter":{const b=u.getUTCFullYear(),g=Math.floor(u.getUTCMonth()/3),p=h.getUTCFullYear(),w=Math.floor(h.getUTCMonth()/3);f=(p-b)*4+(w-g);break}}const v=f*r;return{dateToX(b){return(b.getTime()-u.getTime())/y*v},getColumnWidth(){return r},getTotalWidth(){return v},getHeaderRows(){return Fa(c,u,h,r,v)},getGridLines(){return this.getHeaderRows()[1].map(g=>g.x).filter(g=>g>0)}}}function n(){if(!e)return 0;const a=e.getState();if(a.config.gridWidth===0)return 0;let l=0;for(const d of a.config.columns)l+=d.width??120;return l}function s(a){if(!e)return;const l=e.getState(),d=t(),u=e.getLayouts(),h=n(),y=d.getTotalWidth(),r=h+y,c=l.flatVisibleIds.length*l.config.rowHeight,f=l.config.headerHeight+c,v=a??"gantt-export.png";if(r>Ht||f>Ht){o(l,u,d,h,r,f,v);return}const b=document.createElement("canvas");b.width=r,b.height=f;const g=b.getContext("2d");g&&(h>0&&Hs(g,l,h,f),xs(g,l,u,d,h),b.toBlob(p=>{p&&Tn(p,v)},"image/png"))}function o(a,l,d,u,h,y,r){const c=Math.min(1,Ht/h,Ht/y),f=Math.ceil(h*c),v=Math.ceil(y*c),b=document.createElement("canvas");b.width=f,b.height=v;const g=b.getContext("2d");g&&(g.scale(c,c),u>0&&Hs(g,a,u,y),xs(g,a,l,d,u),b.toBlob(p=>{p&&Tn(p,r)},"image/png"))}function i(a){if(!e)return;const l=e.getState(),d=t(),u=e.getLayouts(),h=n(),y=Na(l,u,d,h),r=new Blob([y],{type:"image/svg+xml;charset=utf-8"});Tn(r,a??"gantt-export.svg")}return{name:"ExportPlugin",install(a){e=a,a.on("export:png",(...l)=>{s(l[0])}),a.on("export:svg",(...l)=>{i(l[0])})},destroy(){e=null}}}const Bs=["January","February","March","April","May","June","July","August","September","October","November","December"],Fs=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];function Us(e,t){return new Date(e.getTime()+t*Fe)}function vn(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}function xa(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ba(e,t,n,s){return(e.getTime()-t.getTime())/n*s}function Fa(e,t,n,s,o){const i=n.getTime()-t.getTime(),a=l=>Ba(l,t,i,o);switch(e){case"day":{const l=[],d=[],u=Math.round(i/Fe);let h=new Date(t);for(let r=0;r<u;r++)d.push({label:String(h.getUTCDate()),x:r*s,width:s,date:new Date(h)}),h=Us(h,1);let y=new Date(t);for(;y.getTime()<n.getTime();){const r=vn(y),c=a(y),f=r.getTime()>=n.getTime()?o:a(r);l.push({label:`${Bs[y.getUTCMonth()]} ${y.getUTCFullYear()}`,x:c,width:f-c,date:new Date(y)}),y=r}return[l,d]}case"week":{const l=[],d=[],u=Math.ceil(i/(Fe*7));for(let y=0;y<u;y++){const r=Us(t,y*7);d.push({label:`${Fs[r.getUTCMonth()]} ${r.getUTCDate()}`,x:y*s,width:s,date:new Date(r)})}let h=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth(),1));for(;h.getTime()<n.getTime();){const y=vn(h),r=h.getTime()<t.getTime()?t:h,c=y.getTime()>n.getTime()?n:y;l.push({label:`${Bs[h.getUTCMonth()]} ${h.getUTCFullYear()}`,x:a(r),width:a(c)-a(r),date:new Date(r)}),h=y}return[l,d]}case"month":{const l=[],d=[],u=t.getUTCFullYear(),h=t.getUTCMonth(),y=n.getUTCFullYear(),r=n.getUTCMonth(),c=(y-u)*12+(r-h);let f=new Date(Date.UTC(u,h,1));for(let b=0;b<c;b++)d.push({label:Fs[f.getUTCMonth()],x:b*s,width:s,date:new Date(f)}),f=vn(f);let v=new Date(Date.UTC(u,0,1));for(;v.getTime()<n.getTime();){const b=new Date(Date.UTC(v.getUTCFullYear()+1,0,1)),g=v.getTime()<t.getTime()?t:v,p=b.getTime()>n.getTime()?n:b;l.push({label:String(v.getUTCFullYear()),x:a(g),width:a(p)-a(g),date:new Date(g)}),v=b}return[l,d]}case"quarter":{const l=[],d=[],u=t.getUTCFullYear(),h=Math.floor(t.getUTCMonth()/3),y=n.getUTCFullYear(),r=Math.floor(n.getUTCMonth()/3),c=(y-u)*4+(r-h);let f=new Date(Date.UTC(u,h*3,1));for(let b=0;b<c;b++){const g=Math.floor(f.getUTCMonth()/3)+1;d.push({label:`Q${g}`,x:b*s,width:s,date:new Date(f)}),f=xa(f,3)}let v=new Date(Date.UTC(u,0,1));for(;v.getTime()<n.getTime();){const b=new Date(Date.UTC(v.getUTCFullYear()+1,0,1)),g=v.getTime()<t.getTime()?t:v,p=b.getTime()>n.getTime()?n:b;l.push({label:String(v.getUTCFullYear()),x:a(g),width:a(p)-a(g),date:new Date(g)}),v=b}return[l,d]}default:return[[],[]]}}const Ua={timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"},wn="nimbus-gantt-dark-theme-transition";function Ya(){if(typeof document>"u"||document.getElementById(wn))return;const e=document.createElement("style");e.id=wn,e.textContent=`
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
  `,document.head.appendChild(e)}function Wa(){if(typeof document>"u")return;const e=document.getElementById(wn);e&&e.remove()}function Xa(e){const t=(e==null?void 0:e.auto)!==!1;let n=null,s=!1,o=null,i=null,a=null,l=null;function d(){if(!n||s)return;const c=n.getState();o={...c.config.theme};const f={...c.config.theme,...Ua};Object.assign(c.config.theme,f),s=!0,y()}function u(){if(!n||!s||!o)return;const c=n.getState();Object.assign(c.config.theme,o),s=!1,y()}function h(){s?u():d()}function y(){if(!n)return;const c=n.getState();n.dispatch({type:"SET_SCROLL",x:c.scrollX,y:c.scrollY})}function r(c){c.matches?d():u()}return{name:"DarkThemePlugin",install(c){n=c,Ya(),c.on("theme:toggle",()=>{h()}),c.on("theme:dark",()=>{d()}),c.on("theme:light",()=>{u()}),t&&typeof window<"u"&&window.matchMedia&&(i=window.matchMedia("(prefers-color-scheme: dark)"),i.matches&&(l=c.on("render",()=>{l&&(l(),l=null),i&&i.matches&&!s&&d()})),a=r,i.addEventListener("change",a))},destroy(){if(i&&a&&i.removeEventListener("change",a),l&&l(),s&&n&&o){const c=n.getState();Object.assign(c.config.theme,o)}Wa(),n=null,o=null,i=null,a=null,s=!1}}}const Le=864e5,za=[1,2,3,4,5],Ga="rgba(128, 128, 128, 0.06)",Va="rgba(128, 128, 128, 0.04)",Ka="#f87171",wt=4;function St(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Ne(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ja(e){const t=new Set((e==null?void 0:e.workDays)??za),n=new Set((e==null?void 0:e.holidays)??[]);e==null||e.hoursPerDay;let s=null;function o(r){if(n.has(r))return!1;const c=Ne(r);return t.has(c.getUTCDay())}function i(r){const c=St(r);return n.has(c)?!1:t.has(r.getUTCDay())}function a(r){let c=Ne(r);for(c=new Date(c.getTime()+Le);!i(c);)c=new Date(c.getTime()+Le);return St(c)}function l(r,c){if(c===0)return r;let f=Ne(r);const v=c>0?1:-1;let b=Math.abs(c);if(!i(f))for(f=new Date(f.getTime()+v*Le);!i(f);)f=new Date(f.getTime()+v*Le);for(;b>0;)f=new Date(f.getTime()+v*Le),i(f)&&b--;return St(f)}function d(r,c){const f=Ne(r),v=Ne(c);if(f.getTime()>v.getTime())return-d(c,r);let b=0,g=new Date(f.getTime());for(;g.getTime()<v.getTime();)i(g)&&b++,g=new Date(g.getTime()+Le);return b}function u(r,c="forward"){if(o(r))return r;let f=Ne(r);const v=c==="forward"?Le:-Le;for(let b=0;b<30;b++)if(f=new Date(f.getTime()+v),i(f))return St(f);return r}function h(r,c){if(r.type==="TASK_MOVE"){const f=u(r.startDate,"forward"),v=u(r.endDate,"backward"),b=Ne(v).getTime()<Ne(f).getTime()?f:v;c({...r,startDate:f,endDate:b});return}if(r.type==="TASK_RESIZE"){const f=u(r.startDate,"forward"),v=u(r.endDate,"backward"),b=Ne(v).getTime()<Ne(f).getTime()?f:v;c({...r,startDate:f,endDate:b});return}c(r)}function y(r,c,f){const{config:v}=c,b=v.headerHeight,g=c.flatVisibleIds.length*v.rowHeight,p=s==null?void 0:s.getTimeScale();if(!p||g===0)return;const{start:w,end:m}=c.dateRange,T=c.scrollX,S=c.scrollY;r.save();const k=typeof window<"u"&&window.devicePixelRatio||1;r.setTransform(k,0,0,k,0,0),r.beginPath(),r.rect(0,b,r.canvas.width/k,g),r.clip(),r.translate(-T,0);const E=new Date(w);E.setUTCHours(0,0,0,0);const D=m.getTime();for(p.getColumnWidth();E.getTime()<=D;){const C=St(E),M=n.has(C),L=!t.has(E.getUTCDay());if(M||L){const R=p.dateToX(E),x=new Date(E.getTime()+Le),_=p.dateToX(x)-R;if(r.fillStyle=Ga,r.fillRect(R,b-S,_,g+S),L&&!M){r.save(),r.beginPath(),r.rect(R,b,_,g),r.clip(),r.strokeStyle=Va,r.lineWidth=1;const H=8,W=g;for(let K=-W;K<_+W;K+=H)r.beginPath(),r.moveTo(R+K,b),r.lineTo(R+K+W,b+W),r.stroke();r.restore()}}if(M){const R=p.dateToX(E),x=new Date(E.getTime()+Le),$=p.dateToX(x),_=(R+$)/2;r.save(),r.setTransform(k,0,0,k,0,0),r.translate(-T,0);const H=b-wt-3;r.beginPath(),r.moveTo(_,H-wt),r.lineTo(_+wt,H),r.lineTo(_,H+wt),r.lineTo(_-wt,H),r.closePath(),r.fillStyle=Ka,r.fill(),r.restore()}E.setTime(E.getTime()+Le)}r.restore()}return{name:"WorkCalendarPlugin",install(r){s=r,r.on("calendar:addWorkDays",(...c)=>{const f=c[0],v=c[1],b=c[2],g=l(f,v);b&&b(g)}),r.on("calendar:workDaysBetween",(...c)=>{const f=c[0],v=c[1],b=c[2],g=d(f,v);b&&b(g)}),r.on("calendar:isWorkDay",(...c)=>{const f=c[0],v=c[1],b=o(f);v&&v(b)}),r.on("calendar:nextWorkDay",(...c)=>{const f=c[0],v=c[1],b=a(f);v&&v(b)})},middleware:h,renderCanvas:y,destroy(){s=null}}}function qa(){return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,e=>{const t=Math.random()*16|0;return(e==="x"?t:t&3|8).toString(16)})}function Za(e,t){let n=null;return(...s)=>{n!==null&&clearTimeout(n),n=setTimeout(()=>{n=null,e(...s)},t)}}function Ja(e){const t=e.endpoint,n=e.userId??"anonymous",s=e.batchInterval??3e4,o=e.onEvent,i=qa(),a=[],l=Date.now();let d=null,u=null,h=!1,y=[];const r=[];function c(m,T){if(h)return;const S={type:m,timestamp:Date.now(),sessionId:i,userId:n,data:T};a.push(S),o&&o(S)}function f(){if(a.length===0)return;if(!t){a.length=0;return}const m=a.splice(0,a.length);try{fetch(t,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(m),keepalive:!0}).catch(()=>{})}catch{}}function v(){u===null&&(u=setInterval(()=>{f()},s))}function b(){u!==null&&(clearInterval(u),u=null)}const g=Za(()=>{if(!d)return;const m=d.getState();c("gantt.scroll",{scrollX:m.scrollX,scrollY:m.scrollY}),m.scrollX,m.scrollY},1e3);let p=0;function w(m,T){switch(m.type){case"SET_ZOOM":{const S=d?d.getState().zoomLevel:"unknown";T(m),c("gantt.zoom",{oldLevel:S,newLevel:m.level});return}case"TASK_MOVE":{const S=p>0?Date.now()-p:0;T(m),c("gantt.task.move",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate,dragDurationMs:S}),p=0;return}case"TASK_RESIZE":{T(m),c("gantt.task.resize",{taskId:m.taskId,startDate:m.startDate,endDate:m.endDate});return}case"DRAG_START":{p=Date.now(),T(m);return}case"SELECT_TASK":{T(m),c("gantt.task.click",{taskId:m.taskId,multi:m.multi??!1});return}case"SET_SCROLL":case"SET_SCROLL_X":case"SET_SCROLL_Y":{T(m),g();return}case"TOGGLE_EXPAND":{const S=d?d.getState().expandedIds.has(m.taskId):!1;T(m),c(S?"gantt.collapse":"gantt.expand",{taskId:m.taskId});return}case"EXPAND_ALL":{T(m),c("gantt.expand",{all:!0});return}case"COLLAPSE_ALL":{T(m),c("gantt.collapse",{all:!0});return}default:T(m);return}}return{name:"TelemetryPlugin",install(m){d=m,v();const T=m.getState();c("gantt.init",{taskCount:T.tasks.size,dependencyCount:T.dependencies.size,zoomLevel:T.zoomLevel}),setTimeout(()=>{h||c("gantt.feature.used",{plugins:y})},0);const S=m.on("taskClick",(...k)=>{const E=k[0];E&&c("gantt.task.click",{taskId:E.id})});r.push(S)},middleware:w,destroy(){h=!0;const m=Date.now()-l;c("gantt.session.duration",{durationMs:m,durationMinutes:Math.round(m/6e4*10)/10}),f(),b();for(const T of r)T();r.length=0,d=null}}}const Ys=5,Sn=.15,kn=.85,Qa=2,Ws=30,Ue=["day","week","month","quarter"];function Xs(e,t){return Math.abs(e)<t?0:e>0?e-t:e+t}function er(e,t,n){return Math.max(t,Math.min(n,e))}function tr(e){const t=er((e==null?void 0:e.sensitivity)??5,1,10),n=(e==null?void 0:e.enableTilt)!==!1,s=(e==null?void 0:e.enablePan)!==!1,o=(e==null?void 0:e.enableTwist)!==!1,i=(e==null?void 0:e.wsUrl)??null,a=t/5;let l=null,d=!1,u=0,h=0,y=0,r=null,c=null,f=null,v=null,b=null,g=null,p=0,w=0,m=0,T=!1;function S($,_,H){m=$,p=_,w=H,T=!0,r===null&&(r=$)}function k(){return typeof window>"u"||!("DeviceOrientationEvent"in window)?!1:(v=$=>{d||$.alpha==null||$.beta==null||$.gamma==null||S($.alpha,$.beta,$.gamma)},window.addEventListener("deviceorientation",v),!0)}function E(){v&&(window.removeEventListener("deviceorientation",v),v=null)}function D(){return i||(typeof window<"u"&&window.location?`${window.location.protocol==="https:"?"wss:":"ws:"}//${window.location.hostname}:8765`:"ws://localhost:8765")}function C($){try{const _=JSON.parse($);_.type==="orientation"?S(_.alpha,_.beta,_.gamma):_.type==="gesture"&&M(_.gesture)}catch{}}function M($){if(!l)return;const _=l.getState();switch($){case"tap":{_.selectedIds.size===0&&_.flatVisibleIds.length>0&&l.dispatch({type:"SELECT_TASK",taskId:_.flatVisibleIds[0]});break}case"doubletap":{l.dispatch({type:"SET_SCROLL",x:0,y:0}),r=null;break}case"swipe-left":{const H=Ue.indexOf(_.zoomLevel);H<Ue.length-1&&l.dispatch({type:"SET_ZOOM",level:Ue[H+1]});break}case"swipe-right":{const H=Ue.indexOf(_.zoomLevel);H>0&&l.dispatch({type:"SET_ZOOM",level:Ue[H-1]});break}}}function L(){if(d||typeof WebSocket>"u")return;const $=D();try{b=new WebSocket($),b.onmessage=_=>{typeof _.data=="string"&&C(_.data)},b.onclose=()=>{b=null,d||(g=setTimeout(L,3e3))},b.onerror=()=>{b&&b.close()}}catch{d||(g=setTimeout(L,3e3))}}function R(){g!==null&&(clearTimeout(g),g=null),b&&(b.onmessage=null,b.onclose=null,b.onerror=null,b.close(),b=null)}function x(){if(!(d||!l)){if(T){u=u*kn+p*Sn,h=h*kn+w*Sn,y=y*kn+m*Sn;const $=l.getState(),_=Qa*a;if(n){const H=Xs(h,Ys);if(H!==0){const W=H*_,K=Math.max(0,$.scrollX+W);l.dispatch({type:"SET_SCROLL_X",x:K})}}if(s){const H=Xs(u,Ys);if(H!==0){const W=H*_,K=Math.max(0,$.scrollY+W);l.dispatch({type:"SET_SCROLL_Y",y:K})}}if(o&&r!==null){const W=(y-r+540)%360-180,K=Ue.indexOf($.zoomLevel);if(W>Ws&&K>0){const q=Ue[K-1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}else if(W<-Ws&&K<Ue.length-1){const q=Ue[K+1];c!==q&&(l.dispatch({type:"SET_ZOOM",level:q}),c=q,r=m)}}}f=requestAnimationFrame(x)}}return{name:"MotionControlPlugin",install($){l=$,c=$.getState().zoomLevel,(!k()||i)&&L(),f=requestAnimationFrame(x)},destroy(){d=!0,f!==null&&(cancelAnimationFrame(f),f=null),E(),R(),l=null}}}const kt="http://schemas.microsoft.com/project",nr=8,zs=4800,sr={0:"FF",1:"FS",2:"SF",3:"SS"},or={FF:0,FS:1,SF:2,SS:3};function Gs(e){return e?e.substring(0,10):""}function Vs(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Ee(e,t){var s;let n=e.getElementsByTagNameNS(kt,t)[0];return n||(n=e.getElementsByTagName(t)[0]),((s=n==null?void 0:n.textContent)==null?void 0:s.trim())??""}function ir(e,t){let n=0;const s=new Date(e.getTime());for(;s<t;){const o=s.getUTCDay();o!==0&&o!==6&&n++,s.setUTCDate(s.getUTCDate()+1)}return Math.max(n,1)}function ar(e){return`PT${e*nr}H0M0S`}function Et(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;")}function En(e){const n=new DOMParser().parseFromString(e,"application/xml"),s=n.getElementsByTagName("parsererror");if(s.length>0)throw new Error(`MS Project XML parse error: ${s[0].textContent}`);const o=n.documentElement,i=new Map,a=o.getElementsByTagNameNS(kt,"Resource"),l=a.length>0?a:o.getElementsByTagName("Resource");for(let g=0;g<l.length;g++){const p=l[g],w=Ee(p,"UID"),m=Ee(p,"Name");w&&m&&i.set(w,m)}const d=new Map,u=o.getElementsByTagNameNS(kt,"Assignment"),h=u.length>0?u:o.getElementsByTagName("Assignment");for(let g=0;g<h.length;g++){const p=h[g],w=Ee(p,"TaskUID"),m=Ee(p,"ResourceUID");if(w&&m){const T=i.get(m);T&&d.set(w,T)}}const y=[],r=[],c=o.getElementsByTagNameNS(kt,"Task"),f=c.length>0?c:o.getElementsByTagName("Task"),v=[];let b=1;for(let g=0;g<f.length;g++){const p=f[g],w=Ee(p,"UID"),m=Ee(p,"Name"),T=Ee(p,"Start"),S=Ee(p,"Finish"),k=Ee(p,"PercentComplete"),E=Ee(p,"Summary")==="1",D=Ee(p,"Milestone")==="1",C=parseInt(Ee(p,"OutlineLevel")||"0",10);if(w==="0"&&!m)continue;const M=`msp-${w}`,L=Gs(T),R=Gs(S);if(!L&&!D)continue;let x;C>0&&v[C-1]&&(x=v[C-1]),v[C]=M,v.length=C+1;const $={id:M,name:m||`Task ${w}`,startDate:L||R,endDate:R||L,progress:k?parseInt(k,10)/100:0,isMilestone:D,parentId:x,sortOrder:g},_=d.get(w);_&&($.assignee=_),E&&($.metadata={...$.metadata,isSummary:!0}),y.push($);const H=p.getElementsByTagNameNS(kt,"PredecessorLink"),W=H.length>0?H:p.getElementsByTagName("PredecessorLink");for(let K=0;K<W.length;K++){const q=W[K],F=Ee(q,"PredecessorUID"),I=parseInt(Ee(q,"Type")||"1",10),O=Ee(q,"LinkLag"),A=O?parseInt(O,10):0;if(!F||F==="0")continue;const N={id:`msp-dep-${b++}`,source:`msp-${F}`,target:M,type:sr[I]??"FS",lag:A!==0?A/zs:void 0};r.push(N)}}return{tasks:y,dependencies:r}}function Dn(e,t={}){const{projectName:n="Nimbus Gantt Export",author:s="Nimbus Gantt",creationDate:o=new Date().toISOString().substring(0,19),calendarName:i="Standard"}=t,a=Array.from(e.tasks.values()),l=Array.from(e.dependencies.values());function d(w){let m=1,T=w;for(;T!=null&&T.parentId;)m++,T=e.tasks.get(T.parentId);return m}const u=new Map,h=new Map;for(const w of a){const m=w.parentId??"__root__",T=(u.get(m)??0)+1;if(u.set(m,T),!w.parentId)h.set(w.id,String(T));else{const S=h.get(w.parentId)??"0";h.set(w.id,`${S}.${T}`)}}const y=new Set;for(const w of a)w.parentId&&y.add(w.parentId);const r=new Map;a.forEach((w,m)=>{r.set(w.id,m+1)});const c=new Map;for(const w of l){const m=c.get(w.target)??[];m.push(w),c.set(w.target,m)}const f=new Set;for(const w of a)w.assignee&&f.add(w.assignee);const v=Array.from(f),b=new Map;v.forEach((w,m)=>{b.set(w,m+1)});const g=[];g.push('<?xml version="1.0" encoding="UTF-8"?>'),g.push('<Project xmlns="http://schemas.microsoft.com/project">'),g.push(`  <Name>${Et(n)}</Name>`),g.push(`  <Author>${Et(s)}</Author>`),g.push(`  <CreationDate>${o}</CreationDate>`),g.push("  <CalendarUID>1</CalendarUID>"),g.push("  <Calendars>"),g.push("    <Calendar>"),g.push("      <UID>1</UID>"),g.push(`      <Name>${Et(i)}</Name>`),g.push("      <IsBaseCalendar>1</IsBaseCalendar>"),g.push("    </Calendar>"),g.push("  </Calendars>"),g.push("  <Tasks>");for(const w of a){const m=r.get(w.id)??0,T=d(w),S=h.get(w.id)??"1",k=y.has(w.id),E=w.isMilestone??!1,D=Vs(w.startDate),C=Vs(w.endDate),M=ir(D,C),L=ar(M),R=Math.round((w.progress??0)*100);g.push("    <Task>"),g.push(`      <UID>${m}</UID>`),g.push(`      <ID>${m}</ID>`),g.push(`      <Name>${Et(w.name)}</Name>`),g.push(`      <Start>${w.startDate}T08:00:00</Start>`),g.push(`      <Finish>${w.endDate}T17:00:00</Finish>`),g.push(`      <Duration>${L}</Duration>`),g.push(`      <PercentComplete>${R}</PercentComplete>`),g.push(`      <Summary>${k?"1":"0"}</Summary>`),g.push(`      <Milestone>${E?"1":"0"}</Milestone>`),g.push(`      <OutlineLevel>${T}</OutlineLevel>`),g.push(`      <OutlineNumber>${S}</OutlineNumber>`);const x=c.get(w.id);if(x)for(const $ of x){const _=r.get($.source)??0;if(_===0)continue;const H=or[$.type??"FS"]??1,W=Math.round(($.lag??0)*zs);g.push("      <PredecessorLink>"),g.push(`        <PredecessorUID>${_}</PredecessorUID>`),g.push(`        <Type>${H}</Type>`),g.push(`        <LinkLag>${W}</LinkLag>`),g.push("      </PredecessorLink>")}g.push("    </Task>")}g.push("  </Tasks>"),g.push("  <Resources>");for(const w of v){const m=b.get(w)??0;g.push("    <Resource>"),g.push(`      <UID>${m}</UID>`),g.push(`      <Name>${Et(w)}</Name>`),g.push("    </Resource>")}g.push("  </Resources>"),g.push("  <Assignments>");let p=1;for(const w of a){if(!w.assignee)continue;const m=r.get(w.id)??0,T=b.get(w.assignee)??0;m===0||T===0||(g.push("    <Assignment>"),g.push(`      <UID>${p++}</UID>`),g.push(`      <TaskUID>${m}</TaskUID>`),g.push(`      <ResourceUID>${T}</ResourceUID>`),g.push("    </Assignment>"))}return g.push("  </Assignments>"),g.push("</Project>"),g.join(`
`)}function rr(){let e=null,t=null;const n=[];function s(){e&&(t||(t=document.createElement("input"),t.type="file",t.accept=".xml",t.style.display="none",document.body.appendChild(t),t.addEventListener("change",()=>{var a;const o=(a=t==null?void 0:t.files)==null?void 0:a[0];if(!o||!e)return;const i=new FileReader;i.onload=l=>{var u;const d=(u=l.target)==null?void 0:u.result;if(!(!d||!e))try{const h=En(d);e.dispatch({type:"SET_DATA",tasks:h.tasks,dependencies:h.dependencies})}catch(h){console.error("[MSProjectPlugin] Import failed:",h)}},i.readAsText(o),t&&(t.value="")})),t.click())}return{name:"MSProjectPlugin",install(o){e=o,n.push(o.on("msproject:import",(...i)=>{const a=i[0];if(!a||typeof a!="string"){console.error("[MSProjectPlugin] msproject:import requires an XML string argument");return}try{const l=En(a);o.dispatch({type:"SET_DATA",tasks:l.tasks,dependencies:l.dependencies})}catch(l){console.error("[MSProjectPlugin] Import failed:",l)}})),n.push(o.on("msproject:export",(...i)=>{const a=i[0]??{},l=i[1],d=o.getState(),u=Dn(d,a);l&&l(u)})),n.push(o.on("msproject:upload",()=>{s()})),n.push(o.on("msproject:download",(...i)=>{const a=i[0]??{},l=i[1]??"project-export.xml",d=o.getState(),u=Dn(d,a),h=new Blob([u],{type:"application/xml;charset=utf-8"}),y=URL.createObjectURL(h),r=document.createElement("a");r.href=y,r.download=l,document.body.appendChild(r),r.click(),document.body.removeChild(r),URL.revokeObjectURL(y)}))},destroy(){for(const o of n)o();n.length=0,t&&(t.remove(),t=null),e=null}}}const lr=[4,3],cr=1.5,dr=.5,ur=.06,gr=4,hr=8,fr=.35,pr=1,Ks=.2,Dt=6,js=864e5;function He(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function qs(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Cn(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function In(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function mr(e){let t=0;for(const n of e){const s=He(n.startDate).getTime(),o=He(n.endDate).getTime();t+=Math.max(o-s,js)}return t}function yr(e){const t=new Map;for(const s of e.splits)t.set(s.taskId,s);let n=null;return{name:"SplitTaskPlugin",install(s){n=s},middleware(s,o){if(s.type==="TASK_MOVE"){const i=t.get(s.taskId);if(i&&n){const l=n.getState().tasks.get(s.taskId);if(l){const d=He(l.startDate).getTime(),h=He(s.startDate).getTime()-d,y=i.segments.map(r=>{const c=new Date(He(r.startDate).getTime()+h),f=new Date(He(r.endDate).getTime()+h);return{startDate:qs(c),endDate:qs(f)}});i.segments=y}}}else if(s.type==="TASK_RESIZE"){const i=t.get(s.taskId);if(i&&n&&i.segments.length>0){const l=n.getState().tasks.get(s.taskId);if(l){const d=l.startDate,u=l.endDate;if(s.startDate!==d&&(i.segments[0]={...i.segments[0],startDate:s.startDate}),s.endDate!==u){const h=i.segments.length-1;i.segments[h]={...i.segments[h],endDate:s.endDate}}}}}o(s)},renderCanvas(s,o,i){if(!n||t.size===0)return;const{config:a,scrollX:l,scrollY:d}=o,{theme:u,headerHeight:h,barHeight:y}=a,r=n.getTimeScale(),c=u.barBorderRadius,f=h;s.save(),s.beginPath(),s.rect(0,f,s.canvas.width,s.canvas.height-f),s.clip(),s.translate(-l,0);for(const v of i){if(v.isMilestone)continue;const b=t.get(v.taskId);if(!b||b.segments.length===0)continue;const g=v.barY-d,p=v.barHeight,w=g+p/2;if(g+p<f||g>s.canvas.height)continue;const m=[];for(const C of b.segments){const M=r.dateToX(He(C.startDate)),L=r.dateToX(He(C.endDate)),R=Math.max(L-M,4);m.push({startX:M,endX:M+R,width:R})}s.save(),s.fillStyle=u.timelineBg,s.fillRect(v.x-1,g-1,v.width+2,p+2),s.restore();for(let C=0;C<m.length-1;C++){const M=m[C].endX,L=m[C+1].startX,R=L-M;if(!(R<=0)){s.save(),s.globalAlpha=ur,s.strokeStyle=v.color,s.lineWidth=gr,s.beginPath(),s.rect(M,g,R,p),s.clip();for(let x=M-p;x<L+p;x+=hr)s.beginPath(),s.moveTo(x,g+p),s.lineTo(x+p,g),s.stroke();s.restore()}}for(let C=0;C<m.length-1;C++){const M=m[C].endX,L=m[C+1].startX;s.save(),s.globalAlpha=dr,s.strokeStyle=Cn(v.color,Ks),s.lineWidth=cr,s.setLineDash(lr),s.beginPath(),s.moveTo(M,w),s.lineTo(L,w),s.stroke(),s.setLineDash([]),s.restore()}const T=o.tasks.get(v.taskId),S=(T==null?void 0:T.progress)??0,k=mr(b.segments);let D=S*k;for(let C=0;C<m.length;C++){const M=m[C],L=Math.max(He(b.segments[C].endDate).getTime()-He(b.segments[C].startDate).getTime(),js);if(s.save(),In(s,M.startX,g,M.width,p,c),s.fillStyle=v.color,s.fill(),s.strokeStyle=Cn(v.color,Ks),s.lineWidth=pr,s.stroke(),s.restore(),D>0&&a.showProgress){const R=Math.min(D,L),x=R/L,$=M.width*x;s.save(),In(s,M.startX,g,M.width,p,c),s.clip(),s.globalAlpha=fr,s.fillStyle=Cn(v.color,.3),s.fillRect(M.startX,g,$,p),s.restore(),D-=R}}if(v.label){const C=m[0],M=m[m.length-1],L=M.endX-C.startX;s.save(),s.font=`${u.fontSize}px ${u.fontFamily}`;const x=s.measureText(v.label).width;s.textBaseline="middle",s.textAlign="left",x+Dt*2<=C.width?(s.fillStyle=v.textColor,In(s,C.startX,g,C.width,p,c),s.clip(),s.fillText(v.label,C.startX+Dt,w)):x+Dt<=L?(s.fillStyle=v.textColor,s.fillText(v.label,C.startX+Dt,w)):(s.fillStyle=u.gridTextColor,s.fillText(v.label,M.endX+Dt,w)),s.restore()}}s.restore()},destroy(){n=null}}}const Mn=864e5,Zs=1e3,xt=4,Tr=.6,br="#E53E3E",vr="#48BB78",wr="rgba(0,0,0,0.05)";function he(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ut(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Bt(e,t){return Math.round((t.getTime()-e.getTime())/Mn)}function Js(e,t){return new Date(e.getTime()+t*Mn)}function je(e,t){return ut(Js(he(e),t))}function Ye(e,t){const n=he(e),s=he(t),o=[],i=new Date(n);if(n.getTime()>=s.getTime())return o.push(ut(n)),o;for(;i.getTime()<s.getTime();)o.push(ut(i)),i.setTime(i.getTime()+Mn);return o}class An{constructor(){this.grid=new Map,this.taskGrid=new Map}clear(){this.grid.clear(),this.taskGrid.clear()}allocate(t,n,s,o){this.grid.has(t)||(this.grid.set(t,new Map),this.taskGrid.set(t,new Map));const i=this.grid.get(t),a=this.taskGrid.get(t);for(const l of s)i.set(l,(i.get(l)??0)+o),a.has(l)||a.set(l,new Set),a.get(l).add(n)}deallocate(t,n,s,o){var l,d;const i=this.grid.get(t),a=this.taskGrid.get(t);if(!(!i||!a))for(const u of s){const y=(i.get(u)??0)-o;y<=0?i.delete(u):i.set(u,y),(l=a.get(u))==null||l.delete(n),((d=a.get(u))==null?void 0:d.size)===0&&a.delete(u)}}getLoad(t,n){var s;return((s=this.grid.get(t))==null?void 0:s.get(n))??0}getTasksOnDay(t,n){var s;return((s=this.taskGrid.get(t))==null?void 0:s.get(n))??new Set}getAllDays(t){return this.grid.get(t)??new Map}getResourceIds(){return Array.from(this.grid.keys())}canFit(t,n,s,o,i){var d;if(i===0)return!0;const a=this.grid.get(t),l=this.taskGrid.get(t);for(const u of s){let h=(a==null?void 0:a.get(u))??0;if((d=l==null?void 0:l.get(u))!=null&&d.has(n)&&(h-=o),h+o>i)return!1}return!0}}function Ft(e,t){const n=[];for(const[s,o]of t){if(o.maxUnits===0)continue;const i=e.getAllDays(s);for(const[a,l]of i)if(l>o.maxUnits){const d=Array.from(e.getTasksOnDay(s,a));n.push({resourceId:s,resourceName:o.name,date:a,overAllocation:l-o.maxUnits,taskIds:d})}}return n.sort((s,o)=>s.date.localeCompare(o.date)),n}function Sr(e,t,n){var o;const s=new Map;for(const[i,a]of e){const l=(o=a.metadata)==null?void 0:o[n];let d=1/0;if(typeof l=="number")d=l;else if(typeof l=="string"){const u=parseInt(l,10);isNaN(u)||(d=u)}s.set(i,{taskId:i,isCritical:!1,priority:d,totalFloat:1/0,earlyStart:he(a.startDate)})}return s}function Qs(e,t){if(e.isCritical!==t.isCritical)return e.isCritical?-1:1;if(e.priority!==t.priority)return e.priority-t.priority;const n=e.earlyStart.getTime()-t.earlyStart.getTime();return n!==0?n:e.totalFloat-t.totalFloat}function kr(e,t,n,s,o){const i=new Map;for(const g of s)e.has(g.taskId)&&n.has(g.resourceId)&&(i.has(g.taskId)||i.set(g.taskId,[]),i.get(g.taskId).push({resourceId:g.resourceId,units:g.units||1}));const a=new Map,l=new Map;for(const g of e.keys())a.set(g,[]),l.set(g,[]);for(const g of t.values()){if((g.type||"FS")!=="FS"||!e.has(g.source)||!e.has(g.target))continue;const w=g.lag||0;a.get(g.source).push({target:g.target,lag:w}),l.get(g.target).push({source:g.source,lag:w})}const d=new Map;for(const[g,p]of e){const w=he(p.startDate),m=he(p.endDate);d.set(g,{taskId:g,startDate:p.startDate,endDate:p.endDate,duration:Math.max(Bt(w,m),0)})}const u=new An;function h(){u.clear();for(const[g,p]of d){const w=i.get(g);if(!w)continue;const m=Ye(p.startDate,p.endDate);for(const T of w)u.allocate(T.resourceId,g,m,T.units)}}function y(g,p){const w=d.get(g);if(!w)return new Set;const m=new Set,T=w.startDate;if(p===T||he(p).getTime()<he(T).getTime())return m;const S=i.get(g);if(S){const k=Ye(w.startDate,w.endDate);for(const E of S)u.deallocate(E.resourceId,g,k,E.units)}if(w.startDate=p,w.endDate=je(p,w.duration),m.add(g),S){const k=Ye(w.startDate,w.endDate);for(const E of S)u.allocate(E.resourceId,g,k,E.units)}return m}function r(g){const p=new Set,w=d.get(g);if(!w)return p;const m=a.get(g)??[];for(const{target:T,lag:S}of m){const k=d.get(T);if(!k)continue;const E=je(w.endDate,S);if(he(k.startDate).getTime()<he(E).getTime()){const D=y(T,E);for(const C of D){p.add(C);const M=r(C);for(const L of M)p.add(L)}}}return p}function c(g){const p=l.get(g)??[];let w=d.get(g).startDate;w=e.get(g).startDate;for(const{source:T,lag:S}of p){const k=d.get(T);if(!k)continue;const E=je(k.endDate,S);he(E).getTime()>he(w).getTime()&&(w=E)}return w}h();for(let g=0;g<Zs;g++){const p=Ft(u,n);if(p.length===0)break;let w=!1;const m=p[0],T=m.taskIds.map(S=>o.get(S)).filter(S=>S!==void 0).sort(Qs);if(!(T.length<2))for(let S=1;S<T.length;S++){const k=T[S],E=d.get(k.taskId);if(!E)continue;const D=d.get(T[0].taskId);if(!D)continue;const C=D.endDate,M=c(k.taskId),L=he(C).getTime()>he(M).getTime()?C:M;he(L).getTime()>he(E.startDate).getTime()&&(y(k.taskId,L),r(k.taskId),w=!0);const R=u.getLoad(m.resourceId,m.date),x=n.get(m.resourceId).maxUnits;if(R<=x)break}}const f=new Map;let v=0;for(const[g,p]of d){const w=e.get(g),m=Bt(he(w.startDate),he(p.startDate));m!==0&&(f.set(g,{startDate:p.startDate,endDate:p.endDate,delayDays:m}),v+=m)}const b=Ft(u,n);return{adjustedTasks:f,totalDelay:v,conflicts:b,resolved:b.length===0}}function Er(e,t,n,s,o){const i=new Map;for(const p of s)e.has(p.taskId)&&n.has(p.resourceId)&&(i.has(p.taskId)||i.set(p.taskId,[]),i.get(p.taskId).push({resourceId:p.resourceId,units:p.units||1}));const a=new Map;for(const p of e.keys())a.set(p,[]);for(const p of t.values())(p.type||"FS")==="FS"&&(!e.has(p.source)||!e.has(p.target)||a.get(p.target).push({source:p.source,lag:p.lag||0}));const l=Array.from(e.keys()).map(p=>o.get(p)).filter(p=>p!==void 0).sort(Qs),d=new Map,u=new An,h=new Set,y=new Map;for(const[p,w]of e)y.set(p,Math.max(Bt(he(w.startDate),he(w.endDate)),0));function r(p){let m=e.get(p).startDate;const T=a.get(p)??[];for(const{source:S,lag:k}of T){const E=d.get(S);if(!E)continue;const D=je(E.endDate,k);he(D).getTime()>he(m).getTime()&&(m=D)}return m}function c(p,w,m){const T=i.get(p);if(!T||T.length===0)return w;let S=w;const k=365*5;for(let E=0;E<k;E++){const D=je(S,m),C=Ye(S,D);let M=!0;for(const L of T){const R=n.get(L.resourceId);if(!R||R.maxUnits===0)continue;const x=R.calendar?new Set(R.calendar):null;if(x&&C.some(_=>x.has(_))){M=!1;break}if(!u.canFit(L.resourceId,p,C,L.units,R.maxUnits)){M=!1;break}}if(M)return S;S=je(S,1)}return w}const f=new Set(l.map(p=>p.taskId));for(let p=0;p<Zs&&f.size>0;p++){let w=!1;for(const m of l){if(!f.has(m.taskId)||!(a.get(m.taskId)??[]).every(R=>h.has(R.source)))continue;const k=m.taskId,E=y.get(k)??0,D=r(k),C=c(k,D,E),M=je(C,E);d.set(k,{taskId:k,startDate:C,endDate:M,duration:E});const L=i.get(k);if(L){const R=Ye(C,M);for(const x of L)u.allocate(x.resourceId,k,R,x.units)}h.add(k),f.delete(k),w=!0}if(!w){for(const m of f){const T=e.get(m),S=y.get(m)??0;d.set(m,{taskId:m,startDate:T.startDate,endDate:T.endDate,duration:S});const k=i.get(m);if(k){const E=Ye(T.startDate,T.endDate);for(const D of k)u.allocate(D.resourceId,m,E,D.units)}h.add(m)}f.clear()}}const v=new Map;let b=0;for(const[p,w]of d){const m=e.get(p),T=Bt(he(m.startDate),he(w.startDate));T!==0&&(v.set(p,{startDate:w.startDate,endDate:w.endDate,delayDays:T}),b+=T)}const g=Ft(u,n);return{adjustedTasks:v,totalDelay:b,conflicts:g,resolved:g.length===0}}function Dr(e,t,n,s){const o=[],i=Ye(n,je(s,1)),a=i.length;for(const[l,d]of t){const u=new Map;let h=0,y=0;for(const f of i){const v=e.getLoad(l,f);u.set(f,v),h+=v,v>y&&(y=v)}const r=d.maxUnits===0?1:d.maxUnits,c=a>0?h/(a*r):0;o.push({resourceId:l,resourceName:d.name,dailyLoad:u,overallUtilization:Math.min(c,1),peakUtilization:y})}return o}function eo(e,t,n,s){const o=new An,i=new Map;for(const a of n)e.has(a.taskId)&&t.has(a.resourceId)&&(i.has(a.taskId)||i.set(a.taskId,[]),i.get(a.taskId).push({resourceId:a.resourceId,units:a.units||1}));for(const[a,l]of e){const d=i.get(a);if(!d)continue;const u=s.get(a),h=(u==null?void 0:u.startDate)??l.startDate,y=(u==null?void 0:u.endDate)??l.endDate,r=Ye(h,y);for(const c of d)o.allocate(c.resourceId,a,r,c.units)}return o}function Cr(e){const t=new Map;for(const r of e.resources)t.set(r.id,r);const n=e.priorityField??"priority",s=e.algorithm??"serial";let o=null,i=null,a=[];const l=[];function d(){return null}function u(){if(!o)return{adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0};const r=o.getState(),{tasks:c,dependencies:f}=r;if(c.size===0)return i={adjustedTasks:new Map,totalDelay:0,conflicts:[],resolved:!0},a=[],i;const v=d(),b=Sr(c,v,n);s==="parallel"?i=Er(c,f,t,e.assignments,b):i=kr(c,f,t,e.assignments,b);const g=h(c,i.adjustedTasks),p=eo(c,t,e.assignments,i.adjustedTasks);return a=Dr(p,t,g.start,g.end),i}function h(r,c){let f=1/0,v=-1/0;for(const[b,g]of r){const p=c.get(b),w=he((p==null?void 0:p.startDate)??g.startDate).getTime(),m=he((p==null?void 0:p.endDate)??g.endDate).getTime();w<f&&(f=w),m>v&&(v=m)}if(f===1/0){const b=ut(new Date);return{start:b,end:b}}return{start:ut(new Date(f)),end:ut(new Date(v))}}function y(r){const c=[];for(const f of e.assignments)f.taskId===r&&c.push(f.resourceId);return c}return{name:"ResourceLevelingPlugin",install(r){o=r,u(),l.push(r.on("resourceLeveling:run",(...c)=>{const f=c[0],v=u();f&&f(v)})),l.push(r.on("resourceLeveling:result",(...c)=>{const f=c[0];f&&f(i)})),l.push(r.on("resourceLeveling:utilization",(...c)=>{const f=c[0];f&&f(a)})),l.push(r.on("resourceLeveling:conflicts",(...c)=>{const f=c[0];if(!f)return;const v=r.getState(),b=eo(v.tasks,t,e.assignments,new Map);f(Ft(b,t))}))},middleware(r,c){c(r),["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY","ADD_TASK","REMOVE_TASK","UPDATE_TASK"].includes(r.type)&&u()},renderCanvas(r,c,f){if(!i||a.length===0)return;const{config:v}=c,{headerHeight:b,rowHeight:g}=v,p=c.scrollX,w=c.scrollY,m=o==null?void 0:o.getTimeScale();if(!m)return;r.save(),r.beginPath(),r.rect(0,b,r.canvas.width,r.canvas.height-b),r.clip(),r.translate(-p,0);const T=new Map;for(const S of a)T.set(S.resourceId,S);for(const S of f){const k=y(S.taskId);if(k.length===0)continue;const E=T.get(k[0]);if(!E)continue;const D=t.get(k[0]);if(!D)continue;const C=D.maxUnits===0?1:D.maxUnits,L=S.barY+S.barHeight-w+1;if(L+xt<b||L>r.canvas.height)continue;const R=c.tasks.get(S.taskId);if(!R)continue;const x=i.adjustedTasks.get(S.taskId),$=(x==null?void 0:x.startDate)??R.startDate,_=(x==null?void 0:x.endDate)??R.endDate,H=m.dateToX(he($)),K=m.dateToX(he(_))-H;if(K<2)continue;r.fillStyle=wr,r.fillRect(H,L,K,xt);const q=Ye($,_);for(const F of q){const I=E.dailyLoad.get(F)??0;if(I===0)continue;const O=m.dateToX(he(F)),N=m.dateToX(Js(he(F),1))-O,ee=Math.min(I/C,2)/2*xt,Z=I>C;r.globalAlpha=Tr,r.fillStyle=Z?br:vr,r.fillRect(O,L+xt-ee,N,ee),r.globalAlpha=1}}r.restore()},destroy(){for(const r of l)r();l.length=0,o=null,i=null,a=[]}}}const Ir=864e5,Mr=75,Ar=50,to=25,Ut=.3,Yt=.25,no=.2,Ln=.15,Wt=.1,Lr=.3,so=.5,Rr=20,oo=40,Pr=3,_r=5,$r=30,io=.25,ao=4,Or=2,Nr=5,Rn=5,ro=4,lo=.4,Hr=.003,qe=260,gt=260,co=16,We=14,xr="rgba(30, 30, 46, 0.92)",Pn="#e0e0e0",Br=10,Xt=32,Fr=6,zt="#EF4444",Gt="#F97316",Vt="#EAB308",Kt="#22C55E";function we(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Ce(e,t){return Math.round((t.getTime()-e.getTime())/Ir)}function De(e,t,n){return Math.max(t,Math.min(n,e))}function Ur(e){return e>=Mr?"critical":e>=Ar?"high":e>=to?"medium":"low"}function Yr(e){switch(e){case"critical":return zt;case"high":return Gt;case"medium":return Vt;case"low":return Kt}}function jt(){const e=new Date;return new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate()))}function Wr(e,t){const n=new Map,s=new Map;for(const g of e.keys())n.set(g,[]),s.set(g,[]);for(const g of t.values())!e.has(g.source)||!e.has(g.target)||(n.get(g.source).push(g.target),s.get(g.target).push(g.source));const o=new Map,i=new Set;function a(g){if(o.has(g))return o.get(g);if(i.has(g))return 0;i.add(g);let p=0;for(const w of n.get(g)||[])p+=1+a(w);return o.set(g,p),p}for(const g of e.keys())a(g);const l=new Map;for(const[g,p]of e){const w=we(p.startDate),m=we(p.endDate);l.set(g,Math.max(Ce(w,m),0))}const d=new Map,u=new Map,h=new Map;for(const g of e.keys())h.set(g,(s.get(g)||[]).length),d.set(g,l.get(g)||0),u.set(g,null);const y=[],r=new Map(h);for(const[g,p]of r)p===0&&y.push(g);for(;y.length>0;){const g=y.shift();for(const p of n.get(g)||[]){const w=d.get(g)+(l.get(p)||0);w>d.get(p)&&(d.set(p,w),u.set(p,g));const m=r.get(p)-1;r.set(p,m),m===0&&y.push(p)}}const c=new Set;let f=0,v=null;for(const[g,p]of d)p>f&&(f=p,v=g);let b=v;for(;b!==null;)c.add(b),b=u.get(b)??null;return{successors:n,predecessors:s,downstreamCount:o,criticalPathIds:c}}function Xr(e){const t=jt(),n=new Map;for(const[s,o]of e){if(!o.assignee||o.isCompleted)continue;const i=we(o.startDate),a=we(o.endDate);t.getTime()>=i.getTime()&&t.getTime()<=a.getTime()&&(n.has(o.assignee)||n.set(o.assignee,[]),n.get(o.assignee).push(s))}return{activeTasks:n}}function zr(e,t,n){const s=[],o=jt(),i=we(e.startDate),a=we(e.endDate),l=Math.max(Ce(i,a),1),d=Math.max(Ce(i,o),0),u=Math.max(Ce(o,a),0),h=e.progress??0;if(e.isCompleted||h>=1)return{taskId:e.id,taskName:e.name,riskLevel:"low",riskScore:0,factors:[],suggestion:void 0};let y=0;const r=o.getTime()>a.getTime();if(r){const E=Ce(a,o);y=De(80+E*2,80,100),s.push({type:"time-pressure",description:`Task is ${E} day${E===1?"":"s"} past its end date`,impact:Math.round(y*Ut)})}else{const E=u/l;E<.2&&h<.5?(y=85,s.push({type:"time-pressure",description:`Only ${Math.round(E*100)}% time remaining but only ${Math.round(h*100)}% complete`,impact:Math.round(y*Ut)})):(y=De(Math.round((1-E)*70),0,70),y>0&&s.push({type:"time-pressure",description:`${Math.round(E*100)}% of scheduled time remaining`,impact:Math.round(y*Ut)}))}let c=0;const f=De(d/l,0,1),v=f-h;v>so?(c=De(Math.round(v*150),75,100),s.push({type:"progress-deviation",description:`${Math.round(v*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Yt)})):v>Lr?(c=De(Math.round(v*130),40,74),s.push({type:"progress-deviation",description:`${Math.round(v*100)}% behind expected progress (expected ${Math.round(f*100)}%, actual ${Math.round(h*100)}%)`,impact:Math.round(c*Yt)})):v>.1&&(c=De(Math.round(v*100),10,39),s.push({type:"progress-deviation",description:`Slightly behind: expected ${Math.round(f*100)}% done, actual ${Math.round(h*100)}%`,impact:Math.round(c*Yt)}));let b=0;const g=t.downstreamCount.get(e.id)||0,p=t.criticalPathIds.has(e.id);if(g>0){b=De(Math.round(Math.log2(g+1)*20),0,70),p&&(b=De(Math.round(b*1.5),0,100));const E=p?" (on critical path)":"";s.push({type:"dependency-chain",description:`${g} downstream dependent${g===1?"":"s"}${E}`,impact:Math.round(b*no)})}let w=0;l>oo?(w=60,s.push({type:"duration",description:`Long task (${l} days) — consider breaking into smaller deliverables`,impact:Math.round(w*Ln)})):l>Rr&&(w=35,s.push({type:"duration",description:`Medium-length task (${l} days) — monitor closely`,impact:Math.round(w*Ln)}));let m=0;if(!e.assignee)m=50,s.push({type:"resource",description:"Task has no assignee",impact:Math.round(m*Wt)});else{const E=n.activeTasks.get(e.assignee)||[];E.length>_r?(m=80,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*Wt)})):E.length>Pr&&(m=45,s.push({type:"resource",description:`Assignee "${e.assignee}" has ${E.length} concurrent active tasks`,impact:Math.round(m*Wt)}))}const T=De(Math.round(y*Ut+c*Yt+b*no+w*Ln+m*Wt),0,100),S=Ur(T);let k;return r&&h===0?k="Task is overdue with no progress — escalate immediately":r?k="Task is past its deadline — review scope or extend timeline":v>so?k="Task is significantly behind schedule — investigate blockers":l>oo&&h<io?k="Large task with little progress — consider splitting into smaller work items":(S==="high"||S==="critical")&&(k="Multiple risk factors present — review with team lead"),{taskId:e.id,taskName:e.name,riskLevel:S,riskScore:T,factors:s,suggestion:k}}function Gr(e,t,n,s,o){const i=jt();let a=0,l=0,d=0;for(const[p,w]of e){if(w.isCompleted||(w.progress??0)>=1)continue;l++;const m=we(w.startDate),T=we(w.endDate),S=Math.max(Ce(m,T),1),k=Math.max(Ce(m,i),0),E=De(k/S,0,1);(w.progress??0)>=E-.1&&a++;const C=t.get(p);C&&(C.riskLevel==="high"||C.riskLevel==="critical")&&d++}const u=l>0?a/l:1;let h=0;for(const p of n.criticalPathIds){const w=e.get(p);if(!w||w.isCompleted)continue;const m=we(w.endDate);i.getTime()>m.getTime()&&(h+=Ce(m,i))}const y=[],r=[];for(const[p,w]of s.activeTasks)y.push(w.length),w.length>ao&&r.push(p);let c=100;if(y.length>1){const p=y.reduce((w,m)=>w+m,0)/y.length;if(p>0){const w=y.reduce((T,S)=>T+(S-p)**2,0)/y.length,m=Math.sqrt(w)/p;c=De(Math.round(100-m*50),0,100)}}let f=100;if(l>0){let p=0,w=0,m=0;for(const T of e.values()){if(T.isCompleted)continue;const S=we(T.startDate),k=we(T.endDate),E=Math.max(Ce(S,k),1),D=Math.max(Ce(S,i),0),C=De(D/E,0,2);p+=T.progress??0,w+=C,m++}if(m>0){const T=p/m,S=w/m;if(S>0){const k=T/S;f=De(Math.round(k*100),0,100)}}}const v=u*100,b=De(100-h*10,0,100);return{overallScore:De(Math.round(v*.25+b*.25+c*.25+f*.25),0,100),tasksAtRisk:d,criticalPathDelay:h,resourceBottlenecks:r,recommendations:o}}function Vr(e,t,n,s){const o=[],i=jt();let a=1;for(const[y,r]of e){if(r.isCompleted)continue;const c=we(r.endDate),f=Ce(c,i),v=r.progress??0;f>Nr&&v===0&&o.push({type:"escalate",description:`"${r.name}" is ${f} days overdue with zero progress — flag for management`,impact:`Prevents further ${f}-day cascade to dependents`,taskIds:[y],priority:a++})}for(const[y,r]of e){if(r.isCompleted)continue;const c=we(r.startDate),f=we(r.endDate),v=Ce(c,f),b=r.progress??0;if(v>$r&&b<io){const g=Math.ceil(v/15);o.push({type:"split",description:`"${r.name}" spans ${v} days — split into ${g} smaller work items`,impact:"Improves estimation accuracy and enables earlier risk detection",taskIds:[y],priority:a++})}}const l=[],d=[];for(const[y,r]of n.activeTasks)r.length>ao?l.push({assignee:y,taskIds:r}):r.length<Or&&d.push(y);if(l.length>0&&d.length>0)for(const{assignee:y,taskIds:r}of l){const c=r.filter(f=>!t.criticalPathIds.has(f));c.length>0&&o.push({type:"reassign",description:`"${y}" has ${r.length} active tasks — move non-critical work to ${d.join(", ")}`,impact:`Reduces ${y}'s load and unblocks parallel progress`,taskIds:c,priority:a++})}for(const y of t.criticalPathIds){const r=e.get(y);if(!r||r.isCompleted)continue;const c=we(r.endDate),f=Ce(i,c);if(f>=0&&f<=5){const v=s.get(y);v&&v.riskScore>=to&&o.push({type:"add-buffer",description:`"${r.name}" is on the critical path with only ${f} day${f===1?"":"s"} remaining — add schedule buffer`,impact:`Protects project end date from a ${f}-day slip`,taskIds:[y],priority:a++})}}const u=Array.from(t.criticalPathIds).map(y=>e.get(y)).filter(y=>y&&!y.isCompleted).sort((y,r)=>we(y.startDate).getTime()-we(r.startDate).getTime()),h=new Set;for(const[,y]of t.successors)for(const r of y);for(const[y,r]of t.predecessors)for(const c of r)h.add(`${c}->${y}`);for(let y=0;y<u.length;y++)for(let r=y+1;r<u.length;r++){const c=u[y],f=u[r],v=we(c.endDate),b=we(f.startDate);if(v.getTime()<=b.getTime()&&!(h.has(`${c.id}->${f.id}`)||h.has(`${f.id}->${c.id}`))){const p=Ce(v,b);p>0&&o.push({type:"parallel",description:`"${c.name}" and "${f.name}" are sequential but independent — run them in parallel`,impact:`Could save up to ${p} days on the critical path`,taskIds:[c.id,f.id],priority:a++});break}}return o.sort((y,r)=>y.priority-r.priority),o}function Kr(e,t,n,s,o,i,a){if(e.save(),i){const l=lo+(1-lo)*(.5+.5*Math.sin(a*Hr));e.globalAlpha=l}e.beginPath(),e.arc(t,n,s,0,Math.PI*2),e.fillStyle=o,e.fill(),e.restore()}function jr(e,t,n,s,o,i){const a=Math.PI*.75,l=Math.PI*2.25,d=l-a,u=a+d*(i/100);e.beginPath(),e.arc(t,n,s,a,l),e.strokeStyle="rgba(255,255,255,0.15)",e.lineWidth=o,e.lineCap="round",e.stroke();const h=i>=75?Kt:i>=50?Vt:i>=25?Gt:zt;e.beginPath(),e.arc(t,n,s,a,u),e.strokeStyle=h,e.lineWidth=o,e.lineCap="round",e.stroke(),e.fillStyle=Pn,e.font="bold 18px sans-serif",e.textAlign="center",e.textBaseline="middle",e.fillText(`${i}`,t,n),e.font="10px sans-serif",e.fillStyle="rgba(255,255,255,0.6)",e.fillText("Health",t,n+16)}function qr(e,t,n,s,o){const i=o.critical+o.high+o.medium+o.low;if(i===0)return;const a=[{count:o.critical,color:zt,label:"Critical"},{count:o.high,color:Gt,label:"High"},{count:o.medium,color:Vt,label:"Medium"},{count:o.low,color:Kt,label:"Low"}];let l=-Math.PI/2;for(const d of a){if(d.count===0)continue;const u=d.count/i*Math.PI*2;e.beginPath(),e.moveTo(t,n),e.arc(t,n,s,l,l+u),e.closePath(),e.fillStyle=d.color,e.fill(),l+=u}}function Zr(e,t,n,s,o){const i=t-qe-co,a=n+co;e.save(),e.beginPath();const l=Br;e.moveTo(i+l,a),e.lineTo(i+qe-l,a),e.arcTo(i+qe,a,i+qe,a+l,l),e.lineTo(i+qe,a+gt-l),e.arcTo(i+qe,a+gt,i+qe-l,a+gt,l),e.lineTo(i+l,a+gt),e.arcTo(i,a+gt,i,a+gt-l,l),e.lineTo(i,a+l),e.arcTo(i,a,i+l,a,l),e.closePath(),e.fillStyle=xr,e.fill(),e.fillStyle=Pn,e.font="bold 13px sans-serif",e.textAlign="left",e.textBaseline="top",e.fillText("Project Health",i+We,a+We);const d=i+We+Xt+4,u=a+We+20+Xt+8;jr(e,d,u,Xt,Fr,s.overallScore);const h=24,y=i+qe-We-h-4,r=u;qr(e,y,r,h,o),e.font="9px sans-serif",e.textAlign="center";const c=r+h+8,f=[{count:o.critical,color:zt,label:"C"},{count:o.high,color:Gt,label:"H"},{count:o.medium,color:Vt,label:"M"},{count:o.low,color:Kt,label:"L"}],v=28,b=y-f.length*v/2+v/2;for(let m=0;m<f.length;m++){const T=f[m],S=b+m*v;e.fillStyle=T.color,e.fillText(`${T.label}:${T.count}`,S,c)}const g=u+Xt+28;e.font="10px sans-serif",e.textAlign="left",e.fillStyle="rgba(255,255,255,0.7)",e.fillText(`At risk: ${s.tasksAtRisk}  |  CP delay: ${s.criticalPathDelay}d`,i+We,g);const p=g+18;e.font="10px sans-serif",e.fillStyle=Pn,e.fillText("Recommendations:",i+We,p);const w=s.recommendations.slice(0,3);for(let m=0;m<w.length;m++){const T=w[m],S=p+14+m*16,k=T.type==="escalate"?"⚠":T.type==="split"?"✂":T.type==="reassign"?"⇄":T.type==="parallel"?"⇉":T.type==="add-buffer"?"⏱":"ℹ",E=34,D=T.description.length>E?T.description.substring(0,E-1)+"…":T.description;e.fillStyle="rgba(255,255,255,0.55)",e.fillText(`${k} ${D}`,i+We,S)}w.length===0&&(e.fillStyle="rgba(255,255,255,0.4)",e.fillText("No action items — looking good!",i+We,p+14)),e.restore()}function Jr(){let e,t=[],n=new Map,s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]},o=[],i=!1,a=Date.now();function l(){const d=e.getState(),{tasks:u,dependencies:h}=d;if(u.size===0){n=new Map,o=[],s={overallScore:100,tasksAtRisk:0,criticalPathDelay:0,resourceBottlenecks:[],recommendations:[]};return}const y=Wr(u,h),r=Xr(u),c=new Map;for(const[f,v]of u)c.set(f,zr(v,y,r));n=c,o=Vr(u,y,r,n),s=Gr(u,n,y,r,o)}return{name:"RiskAnalysisPlugin",install(d){e=d,a=Date.now(),l(),t.push(e.on("risk:analysis",u=>{typeof u=="function"&&u(n)})),t.push(e.on("risk:health",u=>{typeof u=="function"&&u(s)})),t.push(e.on("risk:recommendations",u=>{typeof u=="function"&&u(o)})),t.push(e.on("risk:toggle-overlay",()=>{i=!i}))},middleware(d,u){u(d),["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(d.type)&&l()},renderCanvas(d,u,h){if(n.size===0)return;const{headerHeight:y}=u.config,r=u.scrollX,c=u.scrollY,f=y,v=Date.now()-a;d.save(),d.beginPath(),d.rect(0,f,d.canvas.width,d.canvas.height-f),d.clip(),d.translate(-r,0);for(const b of h){const g=n.get(b.taskId);if(!g||g.riskLevel==="low")continue;const p=b.x,w=b.barY-c,m=b.width,T=b.barHeight;if(w+T<f||w>d.canvas.height||p+m<0)continue;const S=p+m-Rn-ro,k=w+Rn+ro,E=Yr(g.riskLevel),D=g.riskLevel==="critical";Kr(d,S,k,Rn,E,D,v)}if(d.restore(),i){const b={critical:0,high:0,medium:0,low:0};for(const g of n.values())b[g.riskLevel]++;d.save(),Zr(d,d.canvas.width,y,s,b),d.restore()}},destroy(){for(const d of t)d();t=[],n=new Map,o=[]}}}const Re=160,Ze=80,_n=8,Qr=240,el=160,tl=100,nl=200,qt=8,uo=.1,go=3,sl=.001,ol=500,il=5,al=864e5,rl={Planning:"#6366F1",Development:"#3B82F6",Testing:"#F59E0B",Review:"#8B5CF6",Done:"#10B981",Blocked:"#EF4444","In Progress":"#3B82F6",Complete:"#10B981","Not Started":"#94A3B8"};function ho(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function ll(e,t){return Math.round((t.getTime()-e.getTime())/al)}function fo(e,t,n){return e+(t-e)*n}function Zt(e,t,n){return Math.max(t,Math.min(n,e))}function $n(e,t,n){if(e.measureText(t).width<=n)return t;let s=t;for(;s.length>0&&e.measureText(s+"...").width>n;)s=s.slice(0,-1);return s+"..."}function cl(e,t){const n=new Map,s=new Map,o=new Map,i=new Map;for(const l of e.keys())s.set(l,[]),o.set(l,[]),i.set(l,0);for(const l of t.values())!e.has(l.source)||!e.has(l.target)||(s.get(l.source).push(l.target),o.get(l.target).push(l.source),i.set(l.target,(i.get(l.target)||0)+1));const a=[];for(const[l,d]of i)d===0&&(a.push(l),n.set(l,0));for(;a.length>0;){const l=a.shift(),d=n.get(l);for(const u of s.get(l)){const h=n.get(u),y=d+1;(h===void 0||y>h)&&n.set(u,y);const r=i.get(u)-1;i.set(u,r),r===0&&a.push(u)}}for(const l of e.keys())n.has(l)||n.set(l,0);return n}function dl(e){const t=Math.max(0,...e.values()),n=[];for(let s=0;s<=t;s++)n.push([]);for(const[s,o]of e)n[o].push(s);return n}function ul(e,t,n){const s=new Map,o=new Map;for(const a of n.keys())s.set(a,new Set),o.set(a,new Set);for(const a of t.values())!n.has(a.source)||!n.has(a.target)||(s.get(a.source).add(a.target),o.get(a.target).add(a.source));const i=new Map;for(const a of e)for(let l=0;l<a.length;l++)i.set(a[l],l);for(let a=0;a<il;a++){for(let l=1;l<e.length;l++){const d=e[l],u=new Map;for(const h of d){const y=o.get(h);if(y.size===0){u.set(h,i.get(h)??0);continue}let r=0;for(const c of y)r+=i.get(c)??0;u.set(h,r/y.size)}d.sort((h,y)=>(u.get(h)??0)-(u.get(y)??0));for(let h=0;h<d.length;h++)i.set(d[h],h)}for(let l=e.length-2;l>=0;l--){const d=e[l],u=new Map;for(const h of d){const y=s.get(h);if(y.size===0){u.set(h,i.get(h)??0);continue}let r=0;for(const c of y)r+=i.get(c)??0;u.set(h,r/y.size)}d.sort((h,y)=>(u.get(h)??0)-(u.get(y)??0));for(let h=0;h<d.length;h++)i.set(d[h],h)}}}function gl(e,t){const n=new Map;if(t==="radial")return hl(e);const s=t==="lr",o=s?Qr:el,i=s?tl:nl;for(let a=0;a<e.length;a++){const l=e[a],h=-((l.length-1)*i)/2;for(let y=0;y<l.length;y++){const r=l[y],c=h+y*i;s?n.set(r,{x:a*o,y:c}):n.set(r,{x:c,y:a*o})}}return n}function hl(e){const t=new Map,n=180;for(let s=0;s<e.length;s++){const o=e[s];if(s===0)if(o.length===1)t.set(o[0],{x:0,y:0});else{const i=2*Math.PI/o.length;for(let a=0;a<o.length;a++){const l=a*i-Math.PI/2,d=n*.5;t.set(o[a],{x:Math.cos(l)*d,y:Math.sin(l)*d})}}else{const i=s*n,a=o.length>0?2*Math.PI/o.length:0;for(let l=0;l<o.length;l++){const d=l*a-Math.PI/2;t.set(o[l],{x:Math.cos(d)*i,y:Math.sin(d)*i})}}}return t}function Ct(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.beginPath(),e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.arcTo(t+s,n,t+s,n+a,a),e.lineTo(t+s,n+o-a),e.arcTo(t+s,n+o,t+s-a,n+o,a),e.lineTo(t+a,n+o),e.arcTo(t,n+o,t,n+o-a,a),e.lineTo(t,n+a),e.arcTo(t,n,t+a,n,a),e.closePath()}function fl(e,t){return e.color?e.color:e.status&&(t[e.status]||rl[e.status])||"#94A3B8"}function pl(e){const t=ho(e.startDate),n=ho(e.endDate);return Math.max(ll(t,n),0)}function ml(){let e,t=[],n=!1,s="lr",o=null,i=null,a=1,l=null,d=null,u=new Map,h=[],y=null,r=0,c=0,f=1,v=!1,b=0,g=0,p=0,w=0,m=null,T=0,S=0,k=null,E=null,D=new Set,C=!1,M=0,L=0,R=0,x=0;function $(X,P){return{x:(X-r)/f,y:(P-c)/f}}function _(X,P){const{x:B,y:z}=$(X,P);for(const G of u.values()){const V=G.x,ne=G.y;if(B>=V&&B<=V+Re&&z>=ne&&z<=ne+Ze)return G}return null}function H(){const X=e.getState(),{tasks:P,dependencies:B,config:z}=X;if(P.size===0){u=new Map,h=[];return}y=mn(P,B);const G=cl(P,B),V=dl(G);ul(V,B,P);const ne=gl(V,s);let oe=1/0,ae=-1/0,le=1/0,pe=-1/0;for(const{x:ue,y:ke}of ne.values())oe=Math.min(oe,ue),ae=Math.max(ae,ue+Re),le=Math.min(le,ke),pe=Math.max(pe,ke+Ze);const ve=(oe+ae)/2,Ie=(le+pe)/2,Me=u;u=new Map;for(const[ue,ke]of P){const Ae=ne.get(ue);if(!Ae)continue;const Ge=Ae.x-ve,nt=Ae.y-Ie,xe=Me.get(ue);u.set(ue,{id:ue,task:ke,layer:G.get(ue)??0,orderInLayer:0,x:xe?xe.x:Ge,y:xe?xe.y:nt,targetX:Ge,targetY:nt,isCritical:y.criticalTaskIds.has(ue),isDragging:!1})}for(const ue of V)for(let ke=0;ke<ue.length;ke++){const Ae=u.get(ue[ke]);Ae&&(Ae.orderInLayer=ke)}h=[];for(const ue of B.values())!P.has(ue.source)||!P.has(ue.target)||h.push({id:ue.id,dep:ue,sourceId:ue.source,targetId:ue.target,isCritical:y.criticalTaskIds.has(ue.source)&&y.criticalTaskIds.has(ue.target)})}function W(X){const P=e.getState(),B=new Set;B.add(X);const z=new Map,G=new Map;for(const oe of P.tasks.keys())z.set(oe,[]),G.set(oe,[]);for(const oe of P.dependencies.values())!P.tasks.has(oe.source)||!P.tasks.has(oe.target)||(z.get(oe.source).push(oe.target),G.get(oe.target).push(oe.source));const V=[X];for(;V.length>0;){const oe=V.shift();for(const ae of G.get(oe)||[])B.has(ae)||(B.add(ae),V.push(ae))}const ne=[X];for(;ne.length>0;){const oe=ne.shift();for(const ae of z.get(oe)||[])B.has(ae)||(B.add(ae),ne.push(ae))}return B}function K(){C&&cancelAnimationFrame(L),C=!0,M=performance.now(),q()}function q(){const X=performance.now()-M,P=Zt(X/ol,0,1),B=1-Math.pow(1-P,3);let z=!1;for(const G of u.values()){if(G.isDragging)continue;const V=Math.abs(G.x-G.targetX),ne=Math.abs(G.y-G.targetY);V>.5||ne>.5?(G.x=fo(G.x,G.targetX,B),G.y=fo(G.y,G.targetY,B),z=!0):(G.x=G.targetX,G.y=G.targetY)}if(F(),z&&P<1)L=requestAnimationFrame(q);else{C=!1;for(const G of u.values())G.isDragging||(G.x=G.targetX,G.y=G.targetY);F()}}function F(){if(!i||!o)return;const X=e.getState(),{config:P}=X,B=P.theme,z=P.colorMap,G=B.timelineBg==="#1A202C"||B.gridBg==="#1A202C"||B.timelineBg.toLowerCase()==="#1e1e1e"||parseInt(B.timelineBg.replace("#",""),16)<8421504;i.setTransform(a,0,0,a,0,0),i.fillStyle=G?"#1A202C":"#F7F8FA",i.fillRect(0,0,R,x),i.save(),i.translate(r,c),i.scale(f,f);for(const V of h){const ne=u.get(V.sourceId),oe=u.get(V.targetId);if(!ne||!oe)continue;const ae=D.has(V.sourceId)&&D.has(V.targetId),le=k===V.sourceId||k===V.targetId,pe=k!==null&&!le||E!==null&&!ae,ve=ne.x+Re,Ie=ne.y+Ze/2,Me=oe.x,ue=oe.y+Ze/2;i.save(),pe?i.globalAlpha=.15:(le||ae)&&(i.globalAlpha=1),V.isCritical?(i.strokeStyle=B.criticalPathColor||"#E53E3E",i.lineWidth=2.5):(i.strokeStyle=le?G?"#A0AEC0":"#4A5568":G?"#4A5568":"#CBD5E0",i.lineWidth=1.5);const ke=(ve+Me)/2;i.beginPath(),i.moveTo(ve,Ie),i.quadraticCurveTo(ke,Ie,(ve+Me)/2,(Ie+ue)/2),i.quadraticCurveTo(ke,ue,Me,ue),i.stroke();const Ae=Math.atan2(ue-(Ie+ue)/2,Me-ke);i.beginPath(),i.moveTo(Me,ue),i.lineTo(Me-qt*Math.cos(Ae-Math.PI/6),ue-qt*Math.sin(Ae-Math.PI/6)),i.lineTo(Me-qt*Math.cos(Ae+Math.PI/6),ue-qt*Math.sin(Ae+Math.PI/6)),i.closePath(),i.fillStyle=i.strokeStyle,i.fill();const Ge=V.dep.type||"FS",nt=V.dep.lag||0,xe=nt!==0?`${Ge} +${nt}d`:Ge!=="FS"?Ge:"";if(xe&&!pe){const At=(ve+Me)/2,Zn=(Ie+ue)/2-8;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="center",i.textBaseline="bottom",i.fillText(xe,At,Zn)}i.restore()}for(const V of u.values()){const ne=k!==null&&k!==V.id&&!O(k,V.id)||E!==null&&!D.has(V.id),oe=k===V.id,ae=E===V.id,le=fl(V.task,z),pe=V.x,ve=V.y;i.save(),ne&&(i.globalAlpha=.25),V.isCritical&&!ne&&(i.save(),i.shadowColor=B.criticalPathColor||"#E53E3E",i.shadowBlur=12,i.shadowOffsetX=0,i.shadowOffsetY=0,Ct(i,pe,ve,Re,Ze,_n),i.fillStyle="transparent",i.fill(),i.restore()),Ct(i,pe,ve,Re,Ze,_n),i.fillStyle=G?"#2D3748":"#FFFFFF",i.fill(),i.strokeStyle=le,i.lineWidth=oe||ae?2.5:1.5,i.stroke(),ae&&(i.strokeStyle=B.selectionColor||"#3182CE",i.lineWidth=2,Ct(i,pe-2,ve-2,Re+4,Ze+4,_n+2),i.stroke()),i.font=`600 12px ${B.fontFamily}`,i.fillStyle=G?"#E2E8F0":"#1A202C",i.textAlign="left",i.textBaseline="top";const Ie=$n(i,V.task.name,Re-20);i.fillText(Ie,pe+10,ve+8);const Me=ve+26;i.beginPath(),i.arc(pe+16,Me+5,4,0,Math.PI*2),i.fillStyle=le,i.fill(),i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textBaseline="top";const ue=V.task.status||"No status";i.fillText($n(i,ue,Re-40),pe+24,Me);const ke=pl(V.task),Ae=ke===1?"1 day":`${ke} days`;i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#A0AEC0":"#718096",i.textAlign="left",i.textBaseline="top",i.fillText(Ae,pe+10,ve+42),V.task.assignee&&(i.font=`10px ${B.fontFamily}`,i.fillStyle=G?"#718096":"#A0AEC0",i.textAlign="right",i.textBaseline="top",i.fillText($n(i,V.task.assignee,Re/2-10),pe+Re-10,ve+42));const Ge=V.task.progress??0,nt=ve+Ze-6,xe=Re-20,At=3;if(Ct(i,pe+10,nt,xe,At,1.5),i.fillStyle=G?"#4A5568":"#E2E8F0",i.fill(),Ge>0){const Zn=Math.max(At,xe*Zt(Ge,0,1));Ct(i,pe+10,nt,Zn,At,1.5),i.fillStyle=le,i.fill()}i.restore()}i.restore(),I(G,B.fontFamily)}function I(X,P){if(!i)return;const B={lr:"Left → Right",tb:"Top → Bottom",radial:"Radial"};i.save(),i.font=`11px ${P}`,i.fillStyle=X?"rgba(255,255,255,0.5)":"rgba(0,0,0,0.4)",i.textAlign="left",i.textBaseline="top",i.fillText(`Network Graph • ${B[s]}`,12,12),i.textAlign="right",i.fillText(`${Math.round(f*100)}%`,R-12,12),i.restore()}function O(X,P){for(const B of h)if(B.sourceId===X&&B.targetId===P||B.sourceId===P&&B.targetId===X)return!0;return!1}function A(X){l=X;const P=X.querySelector(".ng-timeline-panel");if(!P)return;d=P.querySelector("canvas"),o=document.createElement("canvas"),o.className="ng-network-graph",o.style.display="none",o.style.position="absolute",o.style.top="0",o.style.left="0",o.style.width="100%",o.style.height="100%",o.style.touchAction="none",o.style.zIndex="5",P.appendChild(o);const B=o.getContext("2d");B&&(i=B,a=typeof window<"u"&&window.devicePixelRatio||1,o.addEventListener("mousedown",ge),o.addEventListener("mousemove",ye),o.addEventListener("mouseup",Y),o.addEventListener("mouseleave",te),o.addEventListener("dblclick",j),o.addEventListener("wheel",Q,{passive:!1}),o.addEventListener("touchstart",fe,{passive:!1}),o.addEventListener("touchmove",ce,{passive:!1}),o.addEventListener("touchend",Te))}function N(){if(!o||!l)return;const X=l.querySelector(".ng-timeline-panel");X&&(R=X.clientWidth,x=X.clientHeight,o.width=Math.round(R*a),o.height=Math.round(x*a),o.style.width=`${R}px`,o.style.height=`${x}px`)}function U(){if(o){n=!0,o.style.display="block",d&&(d.style.visibility="hidden"),N(),Z(),H();for(const X of u.values())X.x=X.targetX,X.y=X.targetY;F()}}function ee(){o&&(n=!1,o.style.display="none",d&&(d.style.visibility="visible"),k=null,E=null,D=new Set)}function Z(){r=R/2,c=x/2,f=1}function re(X){if(!o)return{x:0,y:0};const P=o.getBoundingClientRect();return{x:X.clientX-P.left,y:X.clientY-P.top}}function ge(X){const{x:P,y:B}=re(X),z=_(P,B);z?(m=z,z.isDragging=!0,T=$(P,B).x-z.x,S=$(P,B).y-z.y,E=z.id,D=W(z.id),e.dispatch({type:"SELECT_TASK",taskId:z.id}),F()):(v=!0,b=P,g=B,p=r,w=c,E&&(E=null,D=new Set,e.dispatch({type:"DESELECT_ALL"}),F()))}function ye(X){if(!o)return;const{x:P,y:B}=re(X);if(m){const V=$(P,B);m.x=V.x-T,m.y=V.y-S,m.targetX=m.x,m.targetY=m.y,F();return}if(v){const V=P-b,ne=B-g;r=p+V,c=w+ne,F();return}const z=_(P,B),G=z?z.id:null;G!==k&&(k=G,o.style.cursor=k?"pointer":"default",F())}function Y(X){m&&(m.isDragging=!1,m=null),v=!1}function te(X){m&&(m.isDragging=!1,m=null),v=!1,k&&(k=null,F())}function j(X){const{x:P,y:B}=re(X),z=_(P,B);if(z){const G=e.getState();G.tasks.get(z.id)&&G.config&&e.dispatch({type:"SELECT_TASK",taskId:z.id})}}function Q(X){if(X.preventDefault(),!o)return;const{x:P,y:B}=re(X),z=$(P,B),G=-X.deltaY*sl;f=Zt(f+G*f,uo,go);const V=$(P,B);r+=(V.x-z.x)*f,c+=(V.y-z.y)*f,F()}let se=0,de=0,ie=0;function fe(X){if(X.preventDefault(),!!o){if(X.touches.length===1){const P=X.touches[0],B=o.getBoundingClientRect(),z=P.clientX-B.left,G=P.clientY-B.top,V=_(z,G);V?(m=V,V.isDragging=!0,T=$(z,G).x-V.x,S=$(z,G).y-V.y,E=V.id,D=W(V.id),e.dispatch({type:"SELECT_TASK",taskId:V.id})):(v=!0,b=z,g=G,p=r,w=c),F()}else if(X.touches.length===2){v=!1,m&&(m.isDragging=!1,m=null);const P=X.touches[0],B=X.touches[1];se=Math.hypot(B.clientX-P.clientX,B.clientY-P.clientY),de=(P.clientX+B.clientX)/2,ie=(P.clientY+B.clientY)/2}}}function ce(X){if(X.preventDefault(),!o)return;const P=o.getBoundingClientRect();if(X.touches.length===1){const B=X.touches[0],z=B.clientX-P.left,G=B.clientY-P.top;if(m){const V=$(z,G);m.x=V.x-T,m.y=V.y-S,m.targetX=m.x,m.targetY=m.y,F()}else if(v){const V=z-b,ne=G-g;r=p+V,c=w+ne,F()}}else if(X.touches.length===2){const B=X.touches[0],z=X.touches[1],G=Math.hypot(z.clientX-B.clientX,z.clientY-B.clientY),V=(B.clientX+z.clientX)/2,ne=(B.clientY+z.clientY)/2,oe=V-P.left,ae=ne-P.top;if(se>0){const le=G/se,pe=$(oe,ae);f=Zt(f*le,uo,go);const ve=$(oe,ae);r+=(ve.x-pe.x)*f,c+=(ve.y-pe.y)*f}r+=V-de,c+=ne-ie,se=G,de=V,ie=ne,F()}}function Te(X){m&&(m.isDragging=!1,m=null),v=!1,se=0}function be(){o&&(o.removeEventListener("mousedown",ge),o.removeEventListener("mousemove",ye),o.removeEventListener("mouseup",Y),o.removeEventListener("mouseleave",te),o.removeEventListener("dblclick",j),o.removeEventListener("wheel",Q),o.removeEventListener("touchstart",fe),o.removeEventListener("touchmove",ce),o.removeEventListener("touchend",Te),o.remove(),o=null,i=null),d&&(d.style.visibility="visible",d=null),C&&(cancelAnimationFrame(L),C=!1)}return{name:"NetworkGraphPlugin",install(X){e=X,t.push(e.on("networkGraph:toggle",()=>{n?ee():U()})),t.push(e.on("networkGraph:layout",(...P)=>{const B=P[0];B!==s&&(s=B,n&&(H(),K()))})),t.push(e.on("stateChange",()=>{n&&(H(),K())}))},renderDOM(X,P){o||A(X),n&&(N(),F())},destroy(){for(const X of t)X();t=[],be(),u=new Map,h=[],y=null,n=!1}}}const po=300,mo="nimbus-gantt-config-panel",On="nimbus-gantt-config-panel-styles",yo=300,Nn=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],yl=`
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
    transition: opacity ${yo}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${po}px;
    width: ${po}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${yo}ms ease;
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
`;function Tl(){if(typeof localStorage>"u")return{};try{const e=localStorage.getItem(mo);return e?JSON.parse(e):{}}catch{return{}}}function bl(e){if(!(typeof localStorage>"u"))try{localStorage.setItem(mo,JSON.stringify(e))}catch{}}function To(e){const t=e.getFullYear(),n=String(e.getMonth()+1).padStart(2,"0"),s=String(e.getDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Jt(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function vl(){if(typeof document>"u"||document.getElementById(On))return;const e=document.createElement("style");e.id=On,e.textContent=yl,document.head.appendChild(e)}function wl(){if(typeof document>"u")return;const e=document.getElementById(On);e&&e.remove()}function Qt(e,t,n,s,o,i){const a=document.createElement("div");a.className="ng-config-row";const l=document.createElement("span");l.className="ng-config-label",l.textContent=e;const d=document.createElement("input");d.type="range",d.className="ng-config-slider",d.min=String(t),d.max=String(n),d.step=String(o),d.value=String(s);const u=document.createElement("span");return u.className="ng-config-slider-value",u.textContent=String(s),d.addEventListener("input",()=>{const h=Number(d.value);u.textContent=String(h),i(h)}),a.appendChild(l),a.appendChild(d),a.appendChild(u),a}function It(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("div");i.className="ng-config-toggle"+(t?" ng-active":"");const a=document.createElement("div");a.className="ng-config-toggle-knob",i.appendChild(a);let l=t;return i.addEventListener("click",()=>{l=!l,i.classList.toggle("ng-active",l),n(l)}),s.appendChild(o),s.appendChild(i),s}function en(e,t,n){const s=document.createElement("div");s.className="ng-config-row";const o=document.createElement("span");o.className="ng-config-label",o.textContent=e;const i=document.createElement("input");return i.type="color",i.className="ng-config-color-input",i.value=bo(t),i.addEventListener("input",()=>{n(i.value)}),s.appendChild(o),s.appendChild(i),s}function bo(e){return e.startsWith("#")&&(e.length===7||e.length===4)?e.length===4?"#"+e[1]+e[1]+e[2]+e[2]+e[3]+e[3]:e:"#3b82f6"}function Sl(){let e=null,t={},n=null,s=null,o=null,i=!1,a=!0;const l=[];function d(){if(!e)return;const k=e.getState();e.dispatch({type:"SET_SCROLL",x:k.scrollX,y:k.scrollY})}function u(k){Object.assign(t,k),bl(t)}function h(k,E,D){k[E]=D}function y(k,E){if(!e)return;const D=e.getState();h(D.config,k,E),u({[k]:E}),d()}function r(k,E){if(!e)return;const D=e.getState();h(D.config.theme,k,E),d()}function c(k){if(!e)return;const E=Nn.find(C=>C.name===k);if(!E)return;const D=e.getState();Object.assign(D.config.theme,E.values),u({themePreset:k}),d()}function f(){i||!o||!s||(i=!0,s.classList.add("ng-visible"),o.classList.add("ng-open"))}function v(){!i||!o||!s||(i=!1,o.classList.remove("ng-open"),s.classList.remove("ng-visible"))}function b(k,E){var X;const{config:D}=E;n||(n=document.createElement("button"),n.className="ng-config-gear",n.innerHTML="⚙",n.title="Configuration",n.addEventListener("click",()=>{i?v():f()}),k.appendChild(n)),s||(s=document.createElement("div"),s.className="ng-config-overlay",s.addEventListener("click",v),k.appendChild(s)),o||(o=document.createElement("div"),o.className="ng-config-panel",k.appendChild(o)),o.innerHTML="";const C=document.createElement("div");C.className="ng-config-panel-header",C.innerHTML="<span>Configuration</span>";const M=document.createElement("button");M.className="ng-config-close",M.innerHTML="×",M.addEventListener("click",v),C.appendChild(M),o.appendChild(C);const L=g("Display Settings");L.appendChild(Qt("Row height",24,60,D.rowHeight,2,P=>y("rowHeight",P))),L.appendChild(Qt("Bar height",16,40,D.barHeight,2,P=>y("barHeight",P))),L.appendChild(Qt("Grid width",0,500,D.gridWidth,10,P=>y("gridWidth",P))),L.appendChild(Qt("Font size",10,16,D.theme.fontSize,1,P=>{h(E.config.theme,"fontSize",P),u({fontSize:P}),d()})),L.appendChild(It("Today marker",D.showToday,P=>{h(E.config,"showToday",P),u({showToday:P}),d()})),L.appendChild(It("Weekends",D.showWeekends,P=>{h(E.config,"showWeekends",P),u({showWeekends:P}),d()})),L.appendChild(It("Progress bars",D.showProgress,P=>{h(E.config,"showProgress",P),u({showProgress:P}),d()})),L.appendChild(It("Dependency arrows",a,P=>{a=P,u({showDependencies:P}),d()})),L.appendChild(It("Labels on bars",t.showBarLabels!==!1,P=>{u({showBarLabels:P}),d()})),o.appendChild(L);const R=g("Color Theme"),x=document.createElement("div");x.className="ng-config-row";const $=document.createElement("span");$.className="ng-config-label",$.textContent="Preset";const _=document.createElement("select");_.className="ng-config-select";const H=document.createElement("option");H.value="",H.textContent="Custom",_.appendChild(H);for(const P of Nn){const B=document.createElement("option");B.value=P.name,B.textContent=P.name,t.themePreset===P.name&&(B.selected=!0),_.appendChild(B)}_.addEventListener("change",()=>{_.value&&c(_.value)}),x.appendChild($),x.appendChild(_),R.appendChild(x),R.appendChild(en("Bar default",D.theme.barDefaultColor,P=>{r("barDefaultColor",P),u({customColors:{...t.customColors,barDefault:P}})})),R.appendChild(en("Today line",D.theme.todayLineColor,P=>{r("todayLineColor",P),u({customColors:{...t.customColors,todayLine:P}})})),R.appendChild(en("Grid lines",D.theme.timelineGridColor,P=>{r("timelineGridColor",P),u({customColors:{...t.customColors,gridLines:P}})})),R.appendChild(en("Background",D.theme.timelineBg,P=>{r("timelineBg",P),u({customColors:{...t.customColors,background:P}})}));const W=document.createElement("div");W.style.cssText="font-size: 11px; color: #888; margin: 10px 0 6px; font-weight: 600;",W.textContent="Status Color Map",R.appendChild(W);const K={...D.colorMap,...t.statusColorMap},q=document.createElement("div");function F(){q.innerHTML="";const P=Object.entries(K);for(const[z,G]of P){const V=document.createElement("div");V.className="ng-config-color-map-entry";const ne=document.createElement("input");ne.className="ng-config-color-map-status",ne.value=z,ne.readOnly=!0;const oe=document.createElement("input");oe.type="color",oe.className="ng-config-color-input",oe.value=bo(G),oe.addEventListener("input",()=>{K[z]=oe.value,D.colorMap[z]=oe.value,u({statusColorMap:{...K}}),d()});const ae=document.createElement("button");ae.className="ng-config-color-map-remove",ae.innerHTML="×",ae.addEventListener("click",()=>{delete K[z],delete D.colorMap[z],u({statusColorMap:{...K}}),F(),d()}),V.appendChild(ne),V.appendChild(oe),V.appendChild(ae),q.appendChild(V)}const B=document.createElement("button");B.className="ng-config-color-map-add",B.textContent="+ Add status color",B.addEventListener("click",()=>{const z=prompt("Status name:");!z||z.trim()===""||(K[z.trim()]="#3b82f6",D.colorMap[z.trim()]="#3b82f6",u({statusColorMap:{...K}}),F(),d())}),q.appendChild(B)}F(),R.appendChild(q),o.appendChild(R);const I=g("Zoom & Time"),O=document.createElement("div");O.className="ng-config-row";const A=document.createElement("span");A.className="ng-config-label",A.textContent="Zoom";const N=document.createElement("div");N.className="ng-config-zoom-group";const U=["day","week","month","quarter"];for(const P of U){const B=document.createElement("button");B.className="ng-config-zoom-btn"+(E.zoomLevel===P?" ng-active":""),B.textContent=P.charAt(0).toUpperCase()+P.slice(1),B.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_ZOOM",level:P}),u({zoomLevel:P}),N.querySelectorAll(".ng-config-zoom-btn").forEach(z=>z.classList.toggle("ng-active",z===B)))}),N.appendChild(B)}O.appendChild(A),O.appendChild(N),I.appendChild(O);const ee=document.createElement("div");ee.className="ng-config-row";const Z=document.createElement("span");Z.className="ng-config-label",Z.textContent="Start date";const re=document.createElement("input");re.type="date",re.className="ng-config-date-input",re.value=To(E.dateRange.start),re.addEventListener("change",()=>{if(!e||!re.value)return;const P=Jt(re.value),B=e.getState().dateRange.end;e.dispatch({type:"SET_DATE_RANGE",start:P,end:B}),u({dateRangeStart:re.value})}),ee.appendChild(Z),ee.appendChild(re),I.appendChild(ee);const ge=document.createElement("div");ge.className="ng-config-row";const ye=document.createElement("span");ye.className="ng-config-label",ye.textContent="End date";const Y=document.createElement("input");Y.type="date",Y.className="ng-config-date-input",Y.value=To(E.dateRange.end),Y.addEventListener("change",()=>{if(!e||!Y.value)return;const P=e.getState().dateRange.start,B=Jt(Y.value);e.dispatch({type:"SET_DATE_RANGE",start:P,end:B}),u({dateRangeEnd:Y.value})}),ge.appendChild(ye),ge.appendChild(Y),I.appendChild(ge);const te=document.createElement("div");te.style.cssText="margin-top: 8px;";const j=document.createElement("button");j.className="ng-config-btn ng-primary",j.textContent="Fit to View",j.addEventListener("click",()=>{e&&(h(e.getState().config,"fitToView",!0),d())}),te.appendChild(j),I.appendChild(te),o.appendChild(I);const Q=g("Export"),se=document.createElement("div");se.style.cssText="display: flex; flex-wrap: wrap;";const de=document.createElement("button");de.className="ng-config-btn",de.textContent="PNG",de.addEventListener("click",()=>{e&&(e.dispatch({type:"SET_SCROLL",x:E.scrollX,y:E.scrollY}),p("export:png"))}),se.appendChild(de);const ie=document.createElement("button");ie.className="ng-config-btn",ie.textContent="SVG",ie.addEventListener("click",()=>p("export:svg")),se.appendChild(ie);const fe=document.createElement("button");fe.className="ng-config-btn",fe.textContent="CSV",fe.addEventListener("click",()=>{e&&m(e.getState())}),se.appendChild(fe);const ce=document.createElement("button");ce.className="ng-config-btn",ce.textContent="Copy Table",ce.addEventListener("click",()=>{e&&T(e.getState())}),se.appendChild(ce),Q.appendChild(se),o.appendChild(Q);const Te=g("Plugin Toggles"),be=[{key:"CriticalPath",label:"Critical Path",event:"criticalpath:toggle"},{key:"RiskAnalysis",label:"Risk Analysis",event:"risk:toggle"},{key:"Milestones",label:"Milestones",event:"milestones:toggle"},{key:"Grouping",label:"Grouping",event:"grouping:toggle"}];for(const P of be){const B=document.createElement("div");B.className="ng-config-plugin-row";const z=document.createElement("span");z.className="ng-config-plugin-name",z.textContent=P.label;const G=((X=t.pluginToggles)==null?void 0:X[P.key])!==!1,V=document.createElement("span");V.className="ng-config-plugin-status"+(G?" ng-active-status":""),V.textContent=G?"Active":"Inactive";const ne=document.createElement("div");ne.className="ng-config-toggle"+(G?" ng-active":"");const oe=document.createElement("div");oe.className="ng-config-toggle-knob",ne.appendChild(oe);let ae=G;ne.addEventListener("click",()=>{ae=!ae,ne.classList.toggle("ng-active",ae),V.className="ng-config-plugin-status"+(ae?" ng-active-status":""),V.textContent=ae?"Active":"Inactive";const pe={...t.pluginToggles,[P.key]:ae};u({pluginToggles:pe}),p(P.event)});const le=document.createElement("div");le.style.cssText="display: flex; align-items: center;",le.appendChild(z),le.appendChild(V),B.appendChild(le),B.appendChild(ne),Te.appendChild(B)}o.appendChild(Te)}function g(k){const E=document.createElement("div");E.className="ng-config-section";const D=document.createElement("div");return D.className="ng-config-section-title",D.textContent=k,E.appendChild(D),E}function p(k){e&&w.forEach(E=>E(k))}const w=[];function m(k){const E=Array.from(k.tasks.values());if(E.length===0)return;const D=["ID","Name","Start Date","End Date","Progress","Status","Assignee","Priority","Group"],C=E.map($=>[$.id,`"${($.name||"").replace(/"/g,'""')}"`,$.startDate,$.endDate,String(Math.round(($.progress??0)*100))+"%",$.status||"",$.assignee||"",$.priority||"",$.groupName||""]),M=[D.join(","),...C.map($=>$.join(","))].join(`
`),L=new Blob([M],{type:"text/csv;charset=utf-8;"}),R=URL.createObjectURL(L),x=document.createElement("a");x.href=R,x.download="gantt-tasks.csv",document.body.appendChild(x),x.click(),document.body.removeChild(x),URL.revokeObjectURL(R)}function T(k){const E=Array.from(k.tasks.values());if(E.length===0)return;const D=["Name","Start","End","Progress","Status","Assignee"],C=E.map(R=>[R.name,R.startDate,R.endDate,Math.round((R.progress??0)*100)+"%",R.status||"",R.assignee||""]),L=[D.join("	"),...C.map(R=>R.join("	"))].join(`
`);navigator.clipboard&&navigator.clipboard.writeText(L).catch(()=>{})}function S(k){const E=t;if(E.rowHeight!==void 0&&h(k.config,"rowHeight",E.rowHeight),E.barHeight!==void 0&&h(k.config,"barHeight",E.barHeight),E.gridWidth!==void 0&&h(k.config,"gridWidth",E.gridWidth),E.fontSize!==void 0&&h(k.config.theme,"fontSize",E.fontSize),E.showToday!==void 0&&h(k.config,"showToday",E.showToday),E.showWeekends!==void 0&&h(k.config,"showWeekends",E.showWeekends),E.showProgress!==void 0&&h(k.config,"showProgress",E.showProgress),E.showDependencies!==void 0&&(a=E.showDependencies),E.themePreset){const D=Nn.find(C=>C.name===E.themePreset);D&&Object.assign(k.config.theme,D.values)}E.customColors&&(E.customColors.barDefault&&h(k.config.theme,"barDefaultColor",E.customColors.barDefault),E.customColors.todayLine&&h(k.config.theme,"todayLineColor",E.customColors.todayLine),E.customColors.gridLines&&h(k.config.theme,"timelineGridColor",E.customColors.gridLines),E.customColors.background&&h(k.config.theme,"timelineBg",E.customColors.background)),E.statusColorMap&&Object.assign(k.config.colorMap,E.statusColorMap),E.zoomLevel&&(e==null||e.dispatch({type:"SET_ZOOM",level:E.zoomLevel})),E.dateRangeStart&&E.dateRangeEnd&&(e==null||e.dispatch({type:"SET_DATE_RANGE",start:Jt(E.dateRangeStart),end:Jt(E.dateRangeEnd)}))}return{name:"ConfigPanelPlugin",install(k){e=k,vl(),t=Tl();const E=k.on("render",()=>{E(),S(k.getState()),d()});l.push(E);const D=k.on("config:open",()=>f()),C=k.on("config:close",()=>v()),M=k.on("config:toggle",()=>{i?v():f()});l.push(D,C,M)},renderDOM(k,E){b(k,E)},destroy(){l.forEach(k=>k()),l.length=0,n&&(n.remove(),n=null),s&&(s.remove(),s=null),o&&(o.remove(),o=null),wl(),e=null,i=!1}}}const vo=864e5,Hn="nimbus-gantt-heatmap-styles",Se=28,Pe=2,Je=48,_e=160,kl=3,wo="#1e1e2e",So="#166534",ko="#a16207",Eo="#b91c1c",El=`
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
`;function Do(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Dl(e){return String(e.getUTCDate())}function Cl(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCFullYear()}`}function Il(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Co(e,t){return Math.round((t.getTime()-e.getTime())/vo)}function Io(e,t){return new Date(e.getTime()+t*vo)}function ht(e){const t=e.getUTCFullYear(),n=String(e.getUTCMonth()+1).padStart(2,"0"),s=String(e.getUTCDate()).padStart(2,"0");return`${t}-${n}-${s}`}function Ml(e,t){return e===0?wo:e===1?So:e===2?ko:Eo}function Al(e,t){return e===0?.3:t<=1?.9:.5+.5*(e/t)}function Ll(){if(typeof document>"u"||document.getElementById(Hn))return;const e=document.createElement("style");e.id=Hn,e.textContent=El,document.head.appendChild(e)}function Rl(){if(typeof document>"u")return;const e=document.getElementById(Hn);e&&e.remove()}function Pl(e){const t=Array.from(e.tasks.values()),n=new Set;for(const h of t){const y=h.assignee||"Unassigned";n.add(y)}const s=Array.from(n).sort();let o=e.dateRange.start,i=e.dateRange.end;const a=Co(o,i)+1,l=[];for(let h=0;h<a;h++)l.push(Io(o,h));const d=new Map;let u=0;for(const h of s)for(const y of l){const r=`${h}|${ht(y)}`;d.set(r,{assignee:h,date:y,dateKey:ht(y),tasks:[],count:0})}for(const h of t){const y=h.assignee||"Unassigned",r=Do(h.startDate),c=Do(h.endDate),f=Co(r,c)+1;for(let v=0;v<f;v++){const b=Io(r,v),g=`${y}|${ht(b)}`,p=d.get(g);p&&(p.tasks.push(h),p.count++,p.count>u&&(u=p.count))}}return{assignees:s,dates:l,cells:d,maxCount:u}}function _l(){let e=null,t=null,n=null,s=!1,o=null;const i=[];function a(){s=!s,t&&t.classList.toggle("ng-active",s),s&&e&&o&&u(o)}function l(){s=!0,t&&t.classList.add("ng-active"),e&&o&&u(o)}function d(){s=!1,t&&t.classList.remove("ng-active")}function u(y){if(!t||!s)return;const r=Pl(y);let c=t.querySelector(".ng-heatmap-grid-wrapper");c||(c=document.createElement("div"),c.className="ng-heatmap-grid-wrapper",t.appendChild(c)),c.innerHTML="";const f=document.createElement("canvas"),v=_e+r.dates.length*(Se+Pe),b=Je+r.assignees.length*(Se+Pe),g=window.devicePixelRatio||1;f.width=v*g,f.height=b*g,f.style.width=v+"px",f.style.height=b+"px",f.style.cursor="pointer";const p=f.getContext("2d");p.scale(g,g),p.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',p.textAlign="center",p.textBaseline="middle";let w="",m=_e;for(let T=0;T<r.dates.length;T++){const S=r.dates[T],k=Cl(S),E=_e+T*(Se+Pe);if(k!==w){if(w&&T>0){const D=(m+E)/2;p.fillStyle="#94a3b8",p.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',p.fillText(w,D,12)}m=E,w=k}}if(w){const T=_e+r.dates.length*(Se+Pe),S=(m+T)/2;p.fillStyle="#94a3b8",p.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',p.fillText(w,S,12)}p.font='10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';for(let T=0;T<r.dates.length;T++){const S=r.dates[T],k=_e+T*(Se+Pe)+Se/2,E=S.getUTCDay()===0||S.getUTCDay()===6;p.fillStyle=E?"#475569":"#64748b",p.fillText(Dl(S),k,32)}p.beginPath(),p.strokeStyle="#1e293b",p.lineWidth=1,p.moveTo(0,Je-.5),p.lineTo(v,Je-.5),p.stroke();for(let T=0;T<r.assignees.length;T++){const S=r.assignees[T],k=Je+T*(Se+Pe);p.font='12px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',p.textAlign="left",p.textBaseline="middle",p.fillStyle="#cbd5e1",p.save(),p.beginPath(),p.rect(0,k,_e-8,Se),p.clip(),p.fillText(S,8,k+Se/2),p.restore();for(let E=0;E<r.dates.length;E++){const D=r.dates[E],C=`${S}|${ht(D)}`,M=r.cells.get(C),L=(M==null?void 0:M.count)??0,R=_e+E*(Se+Pe),x=Ml(L),$=Al(L,r.maxCount);p.globalAlpha=$,p.fillStyle=x,h(p,R,k,Se,Se,kl),p.fill(),L>=2&&(p.globalAlpha=1,p.font='600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',p.textAlign="center",p.textBaseline="middle",p.fillStyle="#fff",p.fillText(String(L),R+Se/2,k+Se/2)),p.globalAlpha=1}}c.appendChild(f),f.addEventListener("mousemove",T=>{if(!n)return;const S=f.getBoundingClientRect(),k=T.clientX-S.left,E=T.clientY-S.top,D=Math.floor((k-_e)/(Se+Pe)),C=Math.floor((E-Je)/(Se+Pe));if(D<0||D>=r.dates.length||C<0||C>=r.assignees.length||k<_e||E<Je){n.classList.remove("ng-visible");return}const M=r.dates[D],L=r.assignees[C],R=`${L}|${ht(M)}`,x=r.cells.get(R);if(!x||x.count===0){n.classList.remove("ng-visible");return}n.innerHTML="";const $=document.createElement("div");$.className="ng-heatmap-tooltip-date",$.textContent=`${L} - ${Il(M)}`,n.appendChild($);for(const W of x.tasks){const K=document.createElement("div");K.className="ng-heatmap-tooltip-task",K.textContent=`• ${W.name}`,n.appendChild(K)}n.classList.add("ng-visible");const _=T.clientX+12,H=T.clientY+12;n.style.left=_+"px",n.style.top=H+"px"}),f.addEventListener("mouseleave",()=>{n&&n.classList.remove("ng-visible")}),f.addEventListener("click",T=>{if(!e)return;const S=f.getBoundingClientRect(),k=T.clientX-S.left,E=T.clientY-S.top,D=Math.floor((k-_e)/(Se+Pe)),C=Math.floor((E-Je)/(Se+Pe));if(D<0||D>=r.dates.length||C<0||C>=r.assignees.length||k<_e||E<Je)return;const M=r.dates[D],R=`${r.assignees[C]}|${ht(M)}`,x=r.cells.get(R);if(!(!x||x.count===0)){d();for(const $ of x.tasks)e.dispatch({type:"SELECT_TASK",taskId:$.id,multi:!0})}})}function h(y,r,c,f,v,b){y.beginPath(),y.moveTo(r+b,c),y.lineTo(r+f-b,c),y.quadraticCurveTo(r+f,c,r+f,c+b),y.lineTo(r+f,c+v-b),y.quadraticCurveTo(r+f,c+v,r+f-b,c+v),y.lineTo(r+b,c+v),y.quadraticCurveTo(r,c+v,r,c+v-b),y.lineTo(r,c+b),y.quadraticCurveTo(r,c,r+b,c),y.closePath()}return{name:"HeatmapViewPlugin",install(y){e=y,Ll();const r=y.on("heatmap:toggle",()=>a()),c=y.on("heatmap:show",()=>l()),f=y.on("heatmap:hide",()=>d());i.push(r,c,f)},renderDOM(y,r){if(o=r,!t){t=document.createElement("div"),t.className="ng-heatmap-container";const c=document.createElement("div");c.className="ng-heatmap-header-bar";const f=document.createElement("span");f.className="ng-heatmap-title",f.textContent="Resource Heatmap",c.appendChild(f);const v=document.createElement("div");v.className="ng-heatmap-legend";const b=[{color:wo,label:"None"},{color:So,label:"1 task"},{color:ko,label:"2 tasks"},{color:Eo,label:"3+ tasks"}];for(const p of b){const w=document.createElement("span");w.className="ng-heatmap-legend-swatch",w.style.background=p.color,v.appendChild(w);const m=document.createElement("span");m.textContent=p.label,v.appendChild(m)}c.appendChild(v);const g=document.createElement("button");g.className="ng-heatmap-close",g.textContent="Back to Gantt",g.addEventListener("click",d),c.appendChild(g),t.appendChild(c),n=document.createElement("div"),n.className="ng-heatmap-tooltip",document.body.appendChild(n),y.appendChild(t)}s&&u(r)},destroy(){i.forEach(y=>y()),i.length=0,t&&(t.remove(),t=null),n&&(n.remove(),n=null),Rl(),e=null,s=!1,o=null}}}const Qe=200,et=80,Mo=12,Ao=6,$l="rgba(255, 255, 255, 0.95)",Ol="#cbd5e1",Nl="rgba(59, 130, 246, 0.3)",Hl="rgba(59, 130, 246, 0.7)",xl=1.5,Bl=2,Fl=1,xn="nimbus-gantt-minimap-styles",Ul=864e5,Yl=`
  .ng-minimap {
    position: absolute;
    bottom: ${Mo}px;
    right: ${Mo}px;
    width: ${Qe}px;
    height: ${et}px;
    z-index: 900;
    border-radius: ${Ao}px;
    border: 1px solid ${Ol};
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
    border-radius: ${Ao}px;
  }
`;function Wl(){if(typeof document>"u"||document.getElementById(xn))return;const e=document.createElement("style");e.id=xn,e.textContent=Yl,document.head.appendChild(e)}function Xl(){if(typeof document>"u")return;const e=document.getElementById(xn);e&&e.remove()}function zl(){let e=null,t=null,n=null,s=null,o=!0,i=!1;const a=[];let l=1,d=1,u=0,h=0,y=0,r=0;function c(){o=!o,t&&t.classList.toggle("ng-hidden",!o)}function f(){o=!0,t&&t.classList.remove("ng-hidden")}function v(){o=!1,t&&t.classList.add("ng-hidden")}function b(T,S){const k=T/l-y/2,E=S/d-r/2;return{x:Math.max(0,Math.min(k,u-y)),y:Math.max(0,Math.min(E,h-r))}}function g(T){if(!e||!n)return;T.preventDefault(),i=!0;const S=n.getBoundingClientRect(),k=T.clientX-S.left,E=T.clientY-S.top,D=b(k,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function p(T){if(!i||!e||!n)return;T.preventDefault();const S=n.getBoundingClientRect(),k=Math.max(0,Math.min(T.clientX-S.left,Qe)),E=Math.max(0,Math.min(T.clientY-S.top,et)),D=b(k,E);e.dispatch({type:"SET_SCROLL",x:D.x,y:D.y})}function w(){i=!1}function m(T,S){if(!s||!n||!o)return;const k=window.devicePixelRatio||1;n.width=Qe*k,n.height=et*k,n.style.width=Qe+"px",n.style.height=et+"px",s.scale(k,k);const{config:E,scrollX:D,scrollY:C,dateRange:M}=T,L=e.getTimeScale(),R=Math.round((M.end.getTime()-M.start.getTime())/Ul),x=L.getColumnWidth();if(u=Math.max(R*x,1),h=Math.max(T.flatVisibleIds.length*E.rowHeight,1),y=u>0?Math.min(u,1200):1200,r=h>0?Math.min(h,600):600,t&&t.parentElement){const A=t.parentElement;y=A.clientWidth-E.gridWidth,r=A.clientHeight-E.headerHeight}l=Qe/Math.max(u,1),d=et/Math.max(h,1),s.fillStyle=$l,s.fillRect(0,0,Qe,et);const $=new Map;for(const A of S)$.has(A.rowIndex)||$.set(A.rowIndex,[]),$.get(A.rowIndex).push(A);for(const A of S){const N=A.x*l,U=Math.max(A.width*l,1),ee=A.rowIndex*E.rowHeight*d;s.fillStyle=A.color||E.theme.barDefaultColor,s.globalAlpha=.7,s.fillRect(N,ee,U,Math.max(Bl,E.rowHeight*d-Fl))}s.globalAlpha=1;const _=D*l,H=C*d,W=y*l,K=r*d,q=Math.max(0,Math.min(_,Qe-1)),F=Math.max(0,Math.min(H,et-1)),I=Math.min(W,Qe-q),O=Math.min(K,et-F);s.fillStyle=Nl,s.fillRect(q,F,I,O),s.strokeStyle=Hl,s.lineWidth=xl,s.strokeRect(q,F,I,O)}return{name:"MiniMapPlugin",install(T){e=T,Wl();const S=T.on("minimap:toggle",()=>c()),k=T.on("minimap:show",()=>f()),E=T.on("minimap:hide",()=>v());a.push(S,k,E),typeof document<"u"&&(document.addEventListener("mousemove",p),document.addEventListener("mouseup",w))},renderDOM(T,S){t||(t=document.createElement("div"),t.className="ng-minimap"+(o?"":" ng-hidden"),n=document.createElement("canvas"),s=n.getContext("2d"),n.addEventListener("mousedown",g),t.appendChild(n),T.appendChild(t));const k=(e==null?void 0:e.getLayouts())??[];m(S,k)},destroy(){a.forEach(T=>T()),a.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",p),document.removeEventListener("mouseup",w)),t&&(t.remove(),t=null),n=null,s=null,Xl(),e=null,o=!0,i=!1}}}const Gl="#f59e0b",Vl=[6,4],Kl=1,ot=16,jl=4,ql="rgba(15, 23, 42, 0.95)",Zl="#e2e8f0",Jl="#334155",Ql=6,it=10,Lo=220,Ro=12,Po=13;function ec(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function Mt(e,t){const n=e.replace("#","");let s,o,i;n.length===3?(s=parseInt(n[0]+n[0],16),o=parseInt(n[1]+n[1],16),i=parseInt(n[2]+n[2],16)):(s=parseInt(n.substring(0,2),16),o=parseInt(n.substring(2,4),16),i=parseInt(n.substring(4,6),16)),s=Math.round(s*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const a=l=>l.toString(16).padStart(2,"0");return`#${a(s)}${a(o)}${a(i)}`}function tc(e,t,n,s,o){const i=s/2,a=t-i*.4;e.beginPath(),e.strokeStyle=Mt(o,.2),e.lineWidth=1.5,e.moveTo(a,n-i),e.lineTo(a,n+i),e.stroke(),e.beginPath(),e.moveTo(a,n-i),e.lineTo(a+s*.7,n-i+s*.3),e.lineTo(a,n-i+s*.6),e.closePath(),e.fillStyle=o,e.fill()}function nc(e,t,n,s,o){const i=s/2,a=i*.4,l=5;e.beginPath();for(let d=0;d<l*2;d++){const u=d%2===0?i:a,h=Math.PI/2*-1+Math.PI/l*d,y=t+Math.cos(h)*u,r=n+Math.sin(h)*u;d===0?e.moveTo(y,r):e.lineTo(y,r)}e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Mt(o,.25),e.lineWidth=.5,e.stroke()}function sc(e,t,n,s,o){const i=s/2;e.beginPath(),e.moveTo(t,n-i),e.lineTo(t+i,n+i*.7),e.lineTo(t-i,n+i*.7),e.closePath(),e.fillStyle=o,e.fill(),e.strokeStyle=Mt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.45}px sans-serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("!",t,n+i*.05)}function oc(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Mt(o,.25),e.lineWidth=.5,e.stroke(),e.fillStyle="#fff",e.font=`bold ${s*.55}px serif`,e.textAlign="center",e.textBaseline="middle",e.fillText("i",t,n+1)}function ic(e,t,n,s,o){const i=s/2;e.beginPath(),e.arc(t,n,i,0,Math.PI*2),e.fillStyle=o,e.fill(),e.strokeStyle=Mt(o,.25),e.lineWidth=.5,e.stroke(),e.beginPath(),e.strokeStyle="#fff",e.lineWidth=1.5,e.lineCap="round",e.moveTo(t,n),e.lineTo(t-i*.25,n-i*.45),e.stroke(),e.beginPath(),e.moveTo(t,n),e.lineTo(t+i*.4,n-i*.2),e.stroke(),e.beginPath(),e.arc(t,n,1.5,0,Math.PI*2),e.fillStyle="#fff",e.fill()}const _o={flag:tc,star:nc,warning:sc,info:oc,deadline:ic};function ac(e,t,n,s,o){e.save();const i=`${Ro}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,a=`600 ${Po}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;e.font=a;const l=e.measureText(t.label).width;e.font=i;const d=[];let u=0;if(t.description){const b=t.description.split(" ");let g="";for(const p of b){const w=g?g+" "+p:p;e.measureText(w).width>Lo-it*2&&g?(d.push(g),u=Math.max(u,e.measureText(g).width),g=p):g=w}g&&(d.push(g),u=Math.max(u,e.measureText(g).width))}const h=Math.min(Lo,Math.max(l,u)+it*2),y=Ro+4,r=Po+4,c=it*2+r+(d.length>0?4+d.length*y:0);let f=n-h/2;const v=s-c-8;if(f<4&&(f=4),f+h>o-4&&(f=o-h-4),e.beginPath(),rc(e,f,v,h,c,Ql),e.fillStyle=ql,e.fill(),e.strokeStyle=Jl,e.lineWidth=1,e.stroke(),e.font=a,e.fillStyle=Zl,e.textAlign="left",e.textBaseline="top",e.fillText(t.label,f+it,v+it),d.length>0){e.font=i,e.fillStyle="#94a3b8";let b=v+it+r+4;for(const g of d)e.fillText(g,f+it,b),b+=y}e.restore()}function rc(e,t,n,s,o,i){e.moveTo(t+i,n),e.lineTo(t+s-i,n),e.quadraticCurveTo(t+s,n,t+s,n+i),e.lineTo(t+s,n+o-i),e.quadraticCurveTo(t+s,n+o,t+s-i,n+o),e.lineTo(t+i,n+o),e.quadraticCurveTo(t,n+o,t,n+o-i),e.lineTo(t,n+i),e.quadraticCurveTo(t,n,t+i,n)}function lc(e){let t=null,n=[...e.notes],s=null,o=[];const i=[];let a=-1,l=-1,d=null,u=null;function h(g){return n.find(p=>p.id===g)}function y(g){n.push(g),v()}function r(g){n=n.filter(p=>p.id!==g),v()}function c(g,p){const w=h(g);w&&(Object.assign(w,p),v())}function f(){return[...n]}function v(){if(!t)return;const g=t.getState();t.dispatch({type:"SET_SCROLL",x:g.scrollX,y:g.scrollY})}function b(g){const p=g.canvas;u!==p&&(u&&d&&u.removeEventListener("mousemove",d),u=p,d=w=>{const m=p.getBoundingClientRect();a=w.clientX-m.left,l=w.clientY-m.top;let T=null;for(const S of o){const k=a-S.x,E=l-S.y;if(Math.sqrt(k*k+E*E)<=S.size){T=S.note.id;break}}T!==s&&(s=T,p.style.cursor=s?"pointer":"",v())},p.addEventListener("mousemove",d))}return{name:"TimelineNotesPlugin",install(g){t=g;const p=g.on("notes:add",(...S)=>{const k=S[0];k&&k.id&&k.date&&k.label&&y(k)}),w=g.on("notes:remove",(...S)=>{const k=S[0];k&&r(k)}),m=g.on("notes:update",(...S)=>{const k=S[0];if(k&&k.id){const{id:E,...D}=k;c(E,D)}}),T=g.on("notes:list",(...S)=>{const k=S[0];typeof k=="function"&&k(f())});i.push(p,w,m,T)},renderCanvas(g,p,w){if(!t||n.length===0)return;const{config:m,scrollX:T,scrollY:S,dateRange:k}=p,{theme:E}=m,D=m.headerHeight,C=t.getTimeScale();b(g);const M=g.canvas.width/(window.devicePixelRatio||1),L=g.canvas.height/(window.devicePixelRatio||1),R=D,x=L-R;o=[],g.save();for(const $ of n){const _=ec($.date);if(_<k.start||_>k.end)continue;const H=$.color||Gl,W=$.icon||"flag",K=C.dateToX(_)-T;if(K<-ot||K>M+ot)continue;g.save(),g.beginPath(),g.setLineDash(Vl),g.strokeStyle=H,g.globalAlpha=.5,g.lineWidth=Kl,g.moveTo(K,R),g.lineTo(K,R+x),g.stroke(),g.setLineDash([]),g.globalAlpha=1,g.restore();const q=K,F=R+jl+ot/2,I=_o[W]||_o.flag;g.save(),g.beginPath(),g.arc(q,F,ot/2+3,0,Math.PI*2),g.fillStyle="rgba(0, 0, 0, 0.4)",g.fill(),g.restore(),g.save(),I(g,q,F,ot,H),g.restore(),o.push({note:$,x:q,y:F,size:ot/2+4}),s===$.id&&ac(g,$,q,F-ot/2-4,M)}g.restore()},destroy(){i.forEach(g=>g()),i.length=0,u&&d&&u.removeEventListener("mousemove",d),t=null,u=null,d=null,s=null,o=[]}}}const cc=500,dc=40,$o=7,Oo=3,No=5,uc=500,Bn="nimbus-gantt-timetravel-styles",Ho={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},gc=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${dc}px;
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
    width: ${$o*2}px;
    height: ${$o*2}px;
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
    width: ${Oo*2}px;
    height: ${Oo*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${No*2}px;
    height: ${No*2}px;
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
`;function hc(e){return e==="TASK_MOVE"?"move":e==="TASK_RESIZE"?"resize":e==="ADD_TASK"||e==="ADD_DEPENDENCY"?"add":e==="REMOVE_TASK"||e==="REMOVE_DEPENDENCY"?"remove":e==="UPDATE_TASK"?"update":"data"}function fc(e,t){switch(e.type){case"SET_DATA":return`Loaded ${e.tasks.length} tasks`;case"TASK_MOVE":{const n=t.tasks.get(e.taskId);return`Moved ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"TASK_RESIZE":{const n=t.tasks.get(e.taskId);return`Resized ${n?`'${n.name}'`:e.taskId} to ${e.startDate} - ${e.endDate}`}case"UPDATE_TASK":{const n=t.tasks.get(e.taskId),s=n?`'${n.name}'`:e.taskId,o=Object.keys(e.changes).join(", ");return`Updated ${s}: ${o}`}case"ADD_TASK":return`Added task '${e.task.name}'`;case"REMOVE_TASK":{const n=t.tasks.get(e.taskId);return`Removed task ${n?`'${n.name}'`:e.taskId}`}case"ADD_DEPENDENCY":return`Added dependency ${e.dependency.source} -> ${e.dependency.target}`;case"REMOVE_DEPENDENCY":return`Removed dependency ${e.dependencyId}`;default:return e.type}}function pc(e,t){const n=[];for(const o of e.tasks.values())n.push({id:o.id,name:o.name,startDate:o.startDate,endDate:o.endDate,progress:o.progress??0,status:o.status});const s=[];for(const o of e.dependencies.values())s.push({id:o.id,source:o.source,target:o.target});return{timestamp:Date.now(),action:t,tasks:n,dependencies:s}}function mc(e){return new Date(e).toLocaleTimeString(void 0,{hour:"2-digit",minute:"2-digit",second:"2-digit"})}function yc(){if(typeof document>"u"||document.getElementById(Bn))return;const e=document.createElement("style");e.id=Bn,e.textContent=gc,document.head.appendChild(e)}function Tc(){if(typeof document>"u")return;const e=document.getElementById(Bn);e&&e.remove()}const xo=new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","UPDATE_TASK","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]),tn=[.5,1,2,4];function bc(e){const t=(e==null?void 0:e.maxSnapshots)??cc,n=(e==null?void 0:e.autoRecord)??!0;let s=null;const o=[];let i=-1,a=!1,l=!1,d=null,u=1;const h=[];let y=null,r=null,c=null,f=null,v=null,b=null,g=null,p=!1;function w(F){if(!s||a)return;const I=s.getState(),O=pc(I,F);i<o.length-1&&(o.length=i+1),o.push(O),o.length>t&&o.shift(),i=o.length-1}function m(F){if(!s||o.length===0)return;const I=Math.max(0,Math.min(F,o.length-1));i=I;const O=o[I];a=!0;const A=O.tasks.map(U=>({id:U.id,name:U.name,startDate:U.startDate,endDate:U.endDate,progress:U.progress,status:U.status})),N=O.dependencies.map(U=>({id:U.id,source:U.source,target:U.target}));s.dispatch({type:"SET_DATA",tasks:A,dependencies:N}),a=!1,R()}function T(){o.length>0&&m(o.length-1),k()}function S(){if(l||o.length<=1)return;l=!0;const F=tn[u],I=uc/F;d=setInterval(()=>{if(i>=o.length-1){k();return}m(i+1)},I),R()}function k(){l=!1,d!==null&&(clearInterval(d),d=null),R()}function E(){l?k():S()}function D(){u=(u+1)%tn.length,l&&(k(),S()),R()}function C(){k(),i>0&&m(i-1)}function M(){k(),i<o.length-1&&m(i+1)}function L(){k(),o.length=0,i=-1,a=!1,R()}function R(){if(y){if(f){const F=o.length,I=F>0?i+1:0;f.textContent=`${I} / ${F}`}v&&(v.textContent=l?"⏸":"▶",v.classList.toggle("ng-active",l)),b&&(b.textContent=`${tn[u]}x`),x(),$()}}function x(){if(!c||!r||o.length===0){c&&(c.style.display="none");return}c.style.display="block";const F=o.length<=1?50:i/(o.length-1)*100;c.style.left=`${F}%`}function $(){if(!g||!r||(g.innerHTML="",o.length===0))return;const F=200,I=o.length>F?Math.ceil(o.length/F):1;for(let O=0;O<o.length;O+=I){const A=o[O],N=o.length<=1?50:O/(o.length-1)*100,U=hc(A.action.split(" ")[0]==="Loaded"?"SET_DATA":_(A.action)),ee=Ho[U]||Ho.data,Z=document.createElement("div");Z.className="ng-timetravel-dot",Z.style.left=`${N}%`,Z.style.background=ee;const re=document.createElement("div");re.className="ng-timetravel-tooltip",re.textContent=`${A.action}
${mc(A.timestamp)}`,re.style.whiteSpace="pre",Z.appendChild(re);const ge=O;Z.addEventListener("click",ye=>{ye.stopPropagation(),k(),m(ge)}),g.appendChild(Z)}}function _(F){return F.startsWith("Moved")?"TASK_MOVE":F.startsWith("Resized")?"TASK_RESIZE":F.startsWith("Added task")?"ADD_TASK":F.startsWith("Added dependency")?"ADD_DEPENDENCY":F.startsWith("Removed task")?"REMOVE_TASK":F.startsWith("Removed dependency")?"REMOVE_DEPENDENCY":F.startsWith("Updated")?"UPDATE_TASK":(F.startsWith("Loaded"),"SET_DATA")}function H(F){if(!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),A=Math.round(O*(o.length-1));k(),m(A)}function W(F){F.preventDefault(),F.stopPropagation(),p=!0,c&&c.classList.add("ng-dragging"),k()}function K(F){if(!p||!r||o.length<=1)return;const I=r.getBoundingClientRect(),O=Math.max(0,Math.min(1,(F.clientX-I.left)/I.width)),A=Math.round(O*(o.length-1));m(A)}function q(){p&&(p=!1,c&&c.classList.remove("ng-dragging"))}return{name:"TimeTravelPlugin",install(F){s=F,yc(),h.push(F.on("timeTravel:record",()=>{s&&(s.getState(),w("Manual snapshot"))}),F.on("timeTravel:scrub",(...I)=>{const O=I[0];k(),m(O)}),F.on("timeTravel:play",()=>S()),F.on("timeTravel:pause",()=>k()),F.on("timeTravel:present",()=>T()),F.on("timeTravel:clear",()=>L()),F.on("timeTravel:history",(...I)=>{const O=I[0];typeof O=="function"&&O([...o])})),typeof document<"u"&&(document.addEventListener("mousemove",K),document.addEventListener("mouseup",q))},middleware(F,I){let O="";n&&xo.has(F.type)&&s&&!a&&(O=fc(F,s.getState())),I(F),n&&xo.has(F.type)&&!a&&O&&w(O)},renderDOM(F,I){if(!y){y=document.createElement("div"),y.className="ng-timetravel";const O=document.createElement("button");O.className="ng-timetravel-btn",O.textContent="◀",O.title="Step backward",O.addEventListener("click",()=>C()),y.appendChild(O),v=document.createElement("button"),v.className="ng-timetravel-btn",v.textContent="▶",v.title="Play / Pause",v.addEventListener("click",()=>E()),y.appendChild(v);const A=document.createElement("button");A.className="ng-timetravel-btn",A.textContent="▶",A.title="Step forward",A.addEventListener("click",()=>M()),y.appendChild(A),b=document.createElement("span"),b.className="ng-timetravel-speed ng-timetravel-btn",b.textContent=`${tn[u]}x`,b.title="Click to cycle speed",b.addEventListener("click",()=>D()),y.appendChild(b),r=document.createElement("div"),r.className="ng-timetravel-track",r.addEventListener("click",H);const N=document.createElement("div");N.className="ng-timetravel-rail",r.appendChild(N),g=document.createElement("div"),g.style.position="absolute",g.style.inset="0",r.appendChild(g),c=document.createElement("div"),c.className="ng-timetravel-playhead",c.addEventListener("mousedown",W),r.appendChild(c),y.appendChild(r),f=document.createElement("span"),f.className="ng-timetravel-counter",y.appendChild(f);const U=document.createElement("button");U.className="ng-timetravel-btn ng-present",U.textContent="Present",U.title="Return to latest state",U.addEventListener("click",()=>T()),y.appendChild(U),F.appendChild(y)}R()},destroy(){k();for(const F of h)F();h.length=0,typeof document<"u"&&(document.removeEventListener("mousemove",K),document.removeEventListener("mouseup",q)),y&&(y.remove(),y=null),r=null,c=null,f=null,v=null,b=null,g=null,Tc(),o.length=0,i=-1,a=!1,l=!1,p=!1,s=null}}}const Bo=864e5,vc=60,wc=2,Fo=[6,4],Fn="nimbus-gantt-montecarlo-styles",Uo={.5:"#22C55E",.75:"#EAB308",.9:"#F97316",.95:"#EF4444"},Sc=.08,kc=`
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
`;function Un(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function nn(e,t){return Math.round((t.getTime()-e.getTime())/Bo)}function at(e,t){return new Date(e.getTime()+t*Bo)}function Yo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Wo(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}, ${e.getUTCFullYear()}`}function Ec(e,t,n){const s=Math.random(),o=(t-e)/(n-e);return s<o?e+Math.sqrt(s*(n-e)*(t-e)):n-Math.sqrt((1-s)*(n-e)*(n-t))}function Dc(e,t){const n=Math.random(),s=Math.random(),o=Math.sqrt(-2*Math.log(n||1e-10))*Math.cos(2*Math.PI*s);return Math.max(.5,e+o*t)}function Cc(e,t){return e+Math.random()*(t-e)}function Ic(e,t,n,s,o,i,a,l){const d=e.length;if(d===0)return 0;const u=new Float64Array(d),h=new Float64Array(d),y=new Int32Array(l),r=[];for(let v=0;v<d;v++)y[v]===0&&(r.push(v),u[v]=o[v],h[v]=o[v]+s[v]);let c=0;for(;c<r.length;){const v=r[c++],b=h[v],g=i[v];for(let p=0;p<g.length;p++){const w=g[p];b>u[w]&&(u[w]=b,h[w]=b+s[w]),y[w]--,y[w]===0&&r.push(w)}}for(let v=0;v<d;v++)h[v]===0&&s[v]>0&&(u[v]=o[v],h[v]=o[v]+s[v]);let f=0;for(let v=0;v<d;v++)h[v]>f&&(f=h[v]);return f}function Mc(e,t,n,s,o,i){const a=new Float64Array(e),l=new Float64Array(e),d=new Float64Array(e),u=new Float64Array(e),h=new Int32Array(i),y=[],r=[];for(let b=0;b<e;b++)h[b]===0&&(r.push(b),a[b]=n[b],l[b]=n[b]+t[b]);let c=0;for(;c<r.length;){const b=r[c++];y.push(b);const g=l[b];for(const p of s[b])g>a[p]&&(a[p]=g,l[p]=g+t[p]),h[p]--,h[p]===0&&r.push(p)}for(let b=0;b<e;b++)l[b]===0&&t[b]>0&&(a[b]=n[b],l[b]=n[b]+t[b],y.push(b));let f=0;for(let b=0;b<e;b++)l[b]>f&&(f=l[b]);for(let b=0;b<e;b++)s[b].length===0?(u[b]=f,d[b]=f-t[b]):(u[b]=1/0,d[b]=1/0);for(let b=y.length-1;b>=0;b--){const g=y[b];if(u[g]===1/0){let p=1/0;for(const w of s[g])d[w]<p&&(p=d[w]);p===1/0?u[g]=f:u[g]=p,d[g]=u[g]-t[g]}}const v=new Set;for(let b=0;b<e;b++){const g=d[b]-a[b];Math.abs(g)<.5&&v.add(b)}return v}function Ac(e,t,n){const{iterations:s,variability:o,distribution:i,confidenceLevels:a}=n,l=[],d=new Map;for(const N of e.keys())d.set(N,l.length),l.push(N);const u=l.length;if(u===0)return{iterations:s,finishDates:[],percentiles:new Map,meanFinishDate:new Date,medianFinishDate:new Date,earliestFinish:new Date,latestFinish:new Date,standardDeviation:0,taskRisk:new Map,criticalPathFrequency:new Map};const h=new Float64Array(u),y=new Float64Array(u);let r=1/0;for(const N of e.values()){const U=Un(N.startDate).getTime();U<r&&(r=U)}const c=new Date(r);for(let N=0;N<u;N++){const U=e.get(l[N]),ee=Un(U.startDate),Z=Un(U.endDate);h[N]=Math.max(nn(ee,Z),1),y[N]=nn(c,ee)}const f=Array.from({length:u},()=>[]),v=Array.from({length:u},()=>[]),b=new Int32Array(u);for(const N of t.values()){if((N.type||"FS")!=="FS")continue;const ee=d.get(N.source),Z=d.get(N.target);ee===void 0||Z===void 0||(f[ee].push(Z),v[Z].push(ee),b[Z]++)}const g=f.map(N=>new Int32Array(N)),p=v.map(N=>new Int32Array(N)),w=new Float64Array(s),m=new Float64Array(u),T=new Float64Array(u),S=new Float64Array(u),k=new Float64Array(u),E=new Float64Array(u),D=Math.max(1,Math.floor(s/100));for(let N=0;N<s;N++){for(let U=0;U<u;U++){const ee=h[U];let Z;switch(i){case"triangular":{const re=ee*(1-o),ge=ee,ye=ee*(1+o*1.5);Z=Ec(re,ge,ye);break}case"normal":{Z=Dc(ee,ee*o);break}case"uniform":{Z=Cc(ee*(1-o),ee*(1+o));break}}m[U]=Math.max(.5,Z),T[U]+=m[U],S[U]+=m[U]*m[U],m[U]>h[U]&&k[U]++}if(w[N]=Ic(l,d,h,m,y,g,p,b),N%D===0){const U=Mc(u,m,y,g,p,b);for(const ee of U)E[ee]++}}const C=Array.from(w).sort((N,U)=>N-U),M=C.map(N=>at(c,N)),L=new Map;for(const N of a){const U=Math.min(Math.floor(N*C.length),C.length-1);L.set(N,at(c,C[U]))}let R=0;for(let N=0;N<s;N++)R+=C[N];const x=R/s,$=at(c,x),_=Math.floor(s/2),H=at(c,C[_]);let W=0;for(let N=0;N<s;N++){const U=C[N]-x;W+=U*U}const K=Math.sqrt(W/s),q=at(c,C[0]),F=at(c,C[C.length-1]),I=new Map;for(let N=0;N<u;N++){const U=T[N]/s,ee=S[N]/s-U*U;I.set(l[N],{meanDuration:U,stdDev:Math.sqrt(Math.max(0,ee)),delayProbability:k[N]/s})}const O=Math.floor(s/D),A=new Map;for(let N=0;N<u;N++)E[N]>0&&A.set(l[N],E[N]/O);return{iterations:s,finishDates:M,percentiles:L,meanFinishDate:$,medianFinishDate:H,earliestFinish:q,latestFinish:F,standardDeviation:K,taskRisk:I,criticalPathFrequency:A}}function Lc(){if(typeof document>"u"||document.getElementById(Fn))return;const e=document.createElement("style");e.id=Fn,e.textContent=kc,document.head.appendChild(e)}function Rc(){if(typeof document>"u")return;const e=document.getElementById(Fn);e&&e.remove()}function Pc(e){const t={iterations:(e==null?void 0:e.iterations)??1e3,variability:(e==null?void 0:e.variability)??.3,distribution:(e==null?void 0:e.distribution)??"triangular",confidenceLevels:(e==null?void 0:e.confidenceLevels)??[.5,.75,.9,.95]};let n=null,s=null,o=!0;const i=[];let a=null;function l(r){if(!n)return;const c={iterations:(r==null?void 0:r.iterations)??t.iterations,variability:(r==null?void 0:r.variability)??t.variability,distribution:(r==null?void 0:r.distribution)??t.distribution,confidenceLevels:(r==null?void 0:r.confidenceLevels)??t.confidenceLevels},f=n.getState();s=Ac(f.tasks,f.dependencies,c),h()}function d(){o=!o,a&&a.classList.toggle("ng-hidden",!o)}function u(r){r.iterations!==void 0&&(t.iterations=r.iterations),r.variability!==void 0&&(t.variability=r.variability),r.distribution!==void 0&&(t.distribution=r.distribution),r.confidenceLevels!==void 0&&(t.confidenceLevels=r.confidenceLevels)}function h(){if(!a||!s)return;let r="",c=0;for(const[g,p]of s.criticalPathFrequency)p>c&&(c=p,r=g);let f=r;if(n){const g=n.getState().tasks.get(r);g&&(f=g.name)}let v=`
      <div class="ng-montecarlo-title">Finish Date Prediction</div>
      <button class="ng-montecarlo-close" title="Toggle overlay">✕</button>
    `;for(const g of t.confidenceLevels){const p=s.percentiles.get(g);if(!p)continue;const w=Math.round(g*100),m=Uo[g]||"#94A3B8";v+=`
        <div class="ng-montecarlo-row">
          <span class="ng-montecarlo-label">${w}% chance by:</span>
          <span class="ng-montecarlo-value" style="color:${m}">${Wo(p)}</span>
        </div>
      `}if(v+=`
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Most likely:</span>
        <span class="ng-montecarlo-value">${Wo(s.medianFinishDate)}</span>
      </div>
      <div class="ng-montecarlo-row">
        <span class="ng-montecarlo-label">Std deviation:</span>
        <span class="ng-montecarlo-value">${s.standardDeviation.toFixed(1)} days</span>
      </div>
    `,r&&c>0){const g=Math.round(c*100);v+=`
        <div class="ng-montecarlo-risk">
          Highest risk: ${f} (on critical path ${g}% of runs)
        </div>
      `}a.innerHTML=v;const b=a.querySelector(".ng-montecarlo-close");b&&b.addEventListener("click",()=>d())}function y(r,c){if(!s||!n||s.finishDates.length===0)return;const f=n.getTimeScale(),{headerHeight:v}=c.config,b=c.scrollX,g=r.canvas.width/(window.devicePixelRatio||1),p=r.canvas.height/(window.devicePixelRatio||1),w=v,m=p-w,T=s.earliestFinish,S=s.latestFinish,k=Math.max(nn(T,S),1),E=f.getColumnWidth(),D=Math.max(E,wc),C=Math.max(Math.ceil(k),1),M=new Uint32Array(C);for(const _ of s.finishDates){const H=nn(T,_),W=Math.min(Math.max(Math.floor(H),0),C-1);M[W]++}let L=0;for(let _=0;_<C;_++)M[_]>L&&(L=M[_]);if(L===0)return;r.save(),r.beginPath(),r.rect(0,w,g,m),r.clip(),r.translate(-b,0);const R=s.finishDates[Math.floor(s.finishDates.length*.1)],x=s.finishDates[Math.floor(s.finishDates.length*.9)];if(R&&x){const _=f.dateToX(R),H=f.dateToX(x),W=r.createLinearGradient(_,0,H,0);W.addColorStop(0,"rgba(34, 197, 94, 0.0)"),W.addColorStop(.3,"rgba(234, 179, 8, 0.12)"),W.addColorStop(.7,"rgba(249, 115, 22, 0.12)"),W.addColorStop(1,"rgba(239, 68, 68, 0.0)"),r.fillStyle=W,r.globalAlpha=Sc*5,r.fillRect(_,w,H-_,m),r.globalAlpha=1}const $=p-8;for(let _=0;_<C;_++){if(M[_]===0)continue;const H=at(T,_),W=f.dateToX(H),K=M[_]/L*vc,q=C>1?_/(C-1):.5;let F,I,O;if(q<.5){const A=q*2;F=Math.round(34+200*A),I=Math.round(197+-18*A),O=Math.round(94+-86*A)}else{const A=(q-.5)*2;F=Math.round(234+5*A),I=Math.round(179+-111*A),O=Math.round(8+60*A)}r.fillStyle=`rgba(${F}, ${I}, ${O}, 0.6)`,r.fillRect(W,$-K,Math.max(D-1,1),K)}r.setLineDash(Fo),r.lineWidth=1.5;for(const[_,H]of s.percentiles){const W=f.dateToX(H),K=Uo[_]||"#94A3B8",q=`P${Math.round(_*100)}`;r.strokeStyle=K,r.beginPath(),r.moveTo(W,w),r.lineTo(W,p),r.stroke(),r.setLineDash([]),r.fillStyle=K,r.font="600 10px -apple-system, BlinkMacSystemFont, sans-serif",r.textAlign="center",r.textBaseline="top";const F=r.measureText(`${q}: ${Yo(H)}`).width,I=`${q}: ${Yo(H)}`,O=F+8,A=16,N=W-O/2,U=w+4;r.globalAlpha=.85,r.fillStyle="#0F172A",r.beginPath(),r.moveTo(N+3,U),r.lineTo(N+O-3,U),r.arcTo(N+O,U,N+O,U+3,3),r.lineTo(N+O,U+A-3),r.arcTo(N+O,U+A,N+O-3,U+A,3),r.lineTo(N+3,U+A),r.arcTo(N,U+A,N,U+A-3,3),r.lineTo(N,U+3),r.arcTo(N,U,N+3,U,3),r.closePath(),r.fill(),r.globalAlpha=1,r.fillStyle=K,r.fillText(I,W,U+3),r.setLineDash(Fo)}r.setLineDash([]),r.restore()}return{name:"MonteCarloPlugin",install(r){n=r,Lc(),i.push(r.on("montecarlo:run",(...c)=>{const f=c[0];l(f)}),r.on("montecarlo:result",(...c)=>{const f=c[0];typeof f=="function"&&f(s)}),r.on("montecarlo:toggle-overlay",()=>d()),r.on("montecarlo:configure",(...c)=>{const f=c[0];f&&u(f)})),i.push(r.on("stateChange",()=>{!s&&n&&n.getState().tasks.size>0&&l()}))},middleware(r,c){c(r),new Set(["SET_DATA","TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]).has(r.type)&&n&&l()},renderCanvas(r,c,f){!o||!s||y(r,c)},renderDOM(r,c){a||(a=document.createElement("div"),a.className="ng-montecarlo-summary"+(o?"":" ng-hidden"),r.appendChild(a)),s&&h()},destroy(){for(const r of i)r();i.length=0,a&&(a.remove(),a=null),Rc(),s=null,n=null}}}const sn=864e5,Xo=400,Yn="nimbus-gantt-narrative-styles",zo=300;function Xe(e){const[t,n,s]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(s)))}function Wn(e,t){return Math.round((t.getTime()-e.getTime())/sn)}function Go(e){return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][e.getUTCMonth()]} ${e.getUTCDate()}`}function Vo(e){const t=e.getUTCDay(),n=t===0?6:t-1;return new Date(e.getTime()-n*sn)}function Ko(e,t){return new Date(e.getTime()+t*sn)}function _c(e,t){const n=Array.from(e.values());if(n.length===0)return{title:"Project Narrative",generatedAt:Date.now(),summary:"No tasks found. Add tasks to generate a project narrative.",chapters:[],insights:[]};let s=1/0,o=-1/0;for(const D of n){const C=Xe(D.startDate).getTime(),M=Xe(D.endDate).getTime();C<s&&(s=C),M>o&&(o=M)}const i=new Date(s),a=new Date(o),l=Wn(i,a),d=new Date;d.setUTCHours(0,0,0,0);const u=new Map,h=new Map;for(const D of t.values())!e.has(D.source)||!e.has(D.target)||(u.has(D.source)||u.set(D.source,[]),u.get(D.source).push(D.target),h.has(D.target)||h.set(D.target,[]),h.get(D.target).push(D.source));const y=Hc(n,t),r=Vo(i),c=Vo(a),f=[];let v=r;for(;v.getTime()<=c.getTime();)f.push({start:new Date(v),end:Ko(v,6)}),v=Ko(v,7);const b=[];for(let D=0;D<f.length;D++){const C=f[D],M=C.start,L=C.end,R=[],x=[],$=[],_=[],H=[],W=[],K=[];for(const A of n){const N=Xe(A.startDate),U=Xe(A.endDate);N>=M&&N<=L&&(R.push(A),A.isMilestone?(W.push(A),K.push(`Milestone: ${A.name}`)):K.push(`Started: ${A.name}`)),U>=M&&U<=L&&(A.isCompleted||A.progress!==void 0&&A.progress>=1)&&(x.push(A),K.push(`Completed: ${A.name}`)),N<=L&&U>=M&&(H.push(A),N<M&&!A.isCompleted&&(A.progress===void 0||A.progress===0)&&$.push(A),!A.isCompleted&&A.progress!==void 0&&A.progress>0&&A.progress<1&&_.push(A))}for(const A of n)if(A.isMilestone){const N=Xe(A.startDate);N>=M&&N<=L&&!W.includes(A)&&(W.push(A),K.push(`Milestone: ${A.name}`))}const q=H.filter(A=>y.has(A.id)),F=$c(R,x,$,H,q),I=Oc(R,x,$,_,H,q,W,u,e),O=`Week ${D+1} (${Go(M)}–${Go(L)})`;b.push({weekLabel:O,headline:F,body:I,metrics:{started:R.length,completed:x.length,delayed:$.length,onTrack:_.length},events:K})}const g=n.length,p=n.filter(D=>D.isCompleted||D.progress!==void 0&&D.progress>=1).length,w=n.filter(D=>!D.isCompleted&&D.progress!==void 0&&D.progress>0&&D.progress<1).length,m=g-p-w,T=g>0?Math.round(p/g*100):0,S=T>=75?"strong":T>=50?"moderate":T>=25?"early-stage":"just getting started",k=`This project spans ${l} days across ${f.length} weeks with ${g} tasks. Progress is ${S} at ${T}% completion (${p} done, ${w} in progress, ${m} not started).`,E=Nc(n,y,u,h,i,a,d);return{title:"Project Narrative",generatedAt:Date.now(),summary:k,chapters:b,insights:E}}function $c(e,t,n,s,o){return o.length>0&&n.length>0?`Crunch time: critical path tasks ${o.slice(0,2).map(a=>a.name).join(", ")} in play`:n.length>=3?`Headwinds: ${n.length} tasks falling behind schedule`:n.length>0&&t.length>0?`Mixed signals: ${t.length} completed but ${n.length} delayed`:t.length>=3?`Momentum builds: ${t.length} tasks completed`:t.length>0&&e.length>0?`Progress: ${t.length} finished, ${e.length} new tasks launched`:e.length>=4?`Busy launch: ${e.length} new tasks kicked off`:e.length>0?`${e.length} new task${e.length>1?"s":""} kicked off this week`:n.length>0?`Caution: ${n.length} task${n.length>1?"s":""} with no progress`:s.length>0?`Steady progress across ${s.length} active tasks`:"Quiet week with no scheduled activity"}function Oc(e,t,n,s,o,i,a,l,d){const u=[];if(e.length>0)if(e.length<=3){const r=e.map(c=>c.name).join(", ");u.push(`Work began on ${r}.`)}else{const r=e.slice(0,2).map(c=>c.name).join(", ");u.push(`${e.length} tasks kicked off including ${r} and ${e.length-2} more.`)}if(t.length>0)if(t.length<=3){const r=t.map(c=>c.name).join(", ");u.push(`${r} ${t.length===1?"was":"were"} completed.`)}else u.push(`${t.length} tasks reached completion this week.`);if(s.length>0&&u.push(`${s.length} task${s.length>1?"s are":" is"} progressing on schedule.`),a.length>0){const r=a.map(c=>c.name).join(", ");u.push(`Milestone${a.length>1?"s":""} reached: ${r}.`)}if(n.length>0){if(n.length<=3){const c=n.map(f=>f.name).join(", ");u.push(`${c} ${n.length===1?"has":"have"} not started despite being past the planned start date.`)}else u.push(`${n.length} tasks have not started despite being past their planned start dates.`);const r=[];for(const c of n){const f=l.get(c.id);if(f)for(const v of f){const b=d.get(v);b&&!r.includes(b.name)&&r.push(b.name)}}if(r.length>0){const c=r.slice(0,3).join(", ");u.push(`This puts downstream work at risk, including ${c}${r.length>3?` and ${r.length-3} more`:""}.`)}}if(i.length>0&&u.length<4){const r=i.slice(0,2).map(c=>c.name).join(" and ");u.push(`Critical path activity: ${r} — any delay here pushes the project finish date.`)}const h=new Map;for(const r of o)r.assignee&&h.set(r.assignee,(h.get(r.assignee)||0)+1);const y=Array.from(h.entries()).sort((r,c)=>c[1]-r[1]);return y.length>0&&y[0][1]>=3&&u.push(`${y[0][0]} is carrying a heavy load with ${y[0][1]} concurrent tasks.`),u.length===0&&u.push("No significant activity scheduled for this week."),u.join(" ")}function Nc(e,t,n,s,o,i,a){const l=[];if(t.size>0){const b=e.filter(w=>t.has(w.id)),g=b.slice(0,4).map(w=>w.name).join(", "),p=b.length>4?` and ${b.length-4} more`:"";l.push(`The critical path runs through ${g}${p} — any delay here pushes the project finish.`)}const d=new Map;for(const b of e)b.assignee&&!b.isCompleted&&d.set(b.assignee,(d.get(b.assignee)||0)+1);const u=Array.from(d.entries()).sort((b,g)=>g[1]-b[1]);u.length>0&&u[0][1]>=2&&l.push(`${u[0][0]} is carrying the heaviest load with ${u[0][1]} concurrent tasks.`);const h=e.filter(b=>b.isCompleted?!1:Xe(b.startDate)<a&&(b.progress===void 0||b.progress===0));h.length>0&&l.push(`${h.length} task${h.length>1?"s have":" has"} zero progress despite being past ${h.length>1?"their":"its"} start date${h.length>1?"s":""}.`);const y=Wn(o,i),r=Wn(o,a);if(r>0&&y>0){const b=Math.round(r/y*100),g=e.filter(m=>m.isCompleted||m.progress!==void 0&&m.progress>=1).length,p=Math.round(g/e.length*100),w=p-b;Math.abs(w)>=5?w>0?l.push(`Project is running ahead: ${p}% of tasks completed with ${b}% of time elapsed.`):l.push(`Project is running behind: only ${p}% of tasks completed with ${b}% of time elapsed.`):l.push(`Project is tracking close to schedule: ${p}% complete at ${b}% of elapsed time.`)}const c=e.filter(b=>{if(b.isCompleted||b.progress!==void 0&&b.progress>0)return!1;const g=s.get(b.id);return!g||g.length===0});c.length>0&&c.length<=e.length*.5&&l.push(`${c.length} task${c.length>1?"s are":" is"} unblocked and ready to start.`);let f=0,v="";for(const b of e){const g=n.get(b.id);g&&g.length>f&&(f=g.length,v=b.name)}return f>=3&&l.push(`"${v}" is a bottleneck with ${f} downstream tasks depending on it.`),l}function Hc(e,t){const n=new Map;for(const c of e)n.set(c.id,c);const s=new Map,o=new Map;for(const c of e)s.set(c.id,[]),o.set(c.id,0);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||(s.get(c.source).push({target:c.target,lag:c.lag||0}),o.set(c.target,(o.get(c.target)||0)+1)));const i=new Map,a=[];for(const c of e)o.get(c.id)===0&&a.push(c.id);for(const c of e){const f=Xe(c.endDate).getTime();i.set(c.id,f)}const l=new Map(o);for(;a.length>0;){const c=a.shift(),f=i.get(c);for(const v of s.get(c)){const b=n.get(v.target),g=Xe(b.endDate).getTime()-Xe(b.startDate).getTime(),p=f+v.lag*sn+g;p>i.get(v.target)&&i.set(v.target,p);const w=l.get(v.target)-1;l.set(v.target,w),w===0&&a.push(v.target)}}let d=-1/0,u="";for(const[c,f]of i)f>d&&(d=f,u=c);if(!u)return new Set;const h=new Set,y=new Map;for(const c of e)y.set(c.id,[]);for(const c of t.values())(c.type||"FS")==="FS"&&(!n.has(c.source)||!n.has(c.target)||y.get(c.target).push({source:c.source,lag:c.lag||0}));let r=u;for(;r;){h.add(r);const c=y.get(r);if(!c||c.length===0)break;let f="",v=-1/0;for(const b of c){const g=i.get(b.source)||0;g>v&&(v=g,f=b.source)}if(!f||h.has(f))break;r=f}return h}const xc=`
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
    transition: opacity ${zo}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${Xo}px;
    width: ${Xo}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${zo}ms ease;
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
`;function Bc(){if(typeof document>"u"||document.getElementById(Yn))return;const e=document.createElement("style");e.id=Yn,e.textContent=xc,document.head.appendChild(e)}function Fc(){if(typeof document>"u")return;const e=document.getElementById(Yn);e&&e.remove()}function Uc(e){const{started:t,completed:n,delayed:s}=e.metrics;return s>=3?"troubled":s>0&&(n>0||t>0)?"mixed":n>0||t>0?"good":s>0?"troubled":"quiet"}function Yc(){let e=null,t=null,n=!1,s=[],o=null,i=null,a=null;function l(){if(!e)return;const r=e.getState();t=_c(r.tasks,r.dependencies)}function d(){n=!0,l(),i&&i.classList.add("ng-visible"),a&&a.classList.add("ng-open"),h()}function u(){n=!1,i&&i.classList.remove("ng-visible"),a&&a.classList.remove("ng-open")}function h(){if(!a||!t)return;a.innerHTML="";const r=document.createElement("div");r.className="ng-narrative-header";const c=document.createElement("div");c.className="ng-narrative-header-left";const f=document.createElement("span");f.textContent="📖",c.appendChild(f);const v=document.createElement("span");v.textContent="Project Story",c.appendChild(v),r.appendChild(c);const b=document.createElement("div");b.style.display="flex",b.style.alignItems="center",b.style.gap="4px";const g=document.createElement("button");g.className="ng-narrative-refresh",g.innerHTML="↻",g.title="Regenerate",g.addEventListener("click",()=>{l(),h()}),b.appendChild(g);const p=document.createElement("button");p.className="ng-narrative-close",p.innerHTML="×",p.addEventListener("click",u),b.appendChild(p),r.appendChild(b),a.appendChild(r);const w=document.createElement("div");if(w.className="ng-narrative-summary",w.textContent=t.summary,a.appendChild(w),t.chapters.length===0){const S=document.createElement("div");S.className="ng-narrative-empty",S.textContent="No weekly chapters to display.",a.appendChild(S)}else for(const S of t.chapters){const k=document.createElement("div");k.className="ng-narrative-chapter";const E=Uc(S),D=document.createElement("div");D.className=`ng-narrative-chapter-header ng-${E}`;const C=document.createElement("div");C.className="ng-narrative-week-label",C.textContent=S.weekLabel,D.appendChild(C);const M=document.createElement("div");M.className="ng-narrative-headline",M.textContent=S.headline,D.appendChild(M),k.appendChild(D);const L=document.createElement("div");if(L.className="ng-narrative-metrics",S.metrics.started>0&&L.appendChild(y("started",`${S.metrics.started} started`)),S.metrics.completed>0&&L.appendChild(y("completed",`${S.metrics.completed} done`)),S.metrics.delayed>0&&L.appendChild(y("delayed",`${S.metrics.delayed} delayed`)),S.metrics.onTrack>0&&L.appendChild(y("ontrack",`${S.metrics.onTrack} on track`)),L.children.length>0&&k.appendChild(L),S.body){const R=document.createElement("div");R.className="ng-narrative-body",R.textContent=S.body,k.appendChild(R)}a.appendChild(k)}if(t.insights.length>0){const S=document.createElement("div");S.className="ng-narrative-insights";const k=document.createElement("div");k.className="ng-narrative-insights-title",k.innerHTML="<span>💡</span> Key Insights",S.appendChild(k);for(const E of t.insights){const D=document.createElement("div");D.className="ng-narrative-insight";const C=document.createElement("span");C.className="ng-narrative-insight-icon",C.textContent="•",D.appendChild(C);const M=document.createElement("span");M.textContent=E,D.appendChild(M),S.appendChild(D)}a.appendChild(S)}const m=document.createElement("div");m.className="ng-narrative-timestamp";const T=new Date(t.generatedAt);m.textContent=`Generated ${T.toLocaleString()}`,a.appendChild(m)}function y(r,c){const f=document.createElement("span");return f.className=`ng-narrative-badge ng-${r}`,f.textContent=c,f}return{name:"NarrativePlugin",install(r){e=r,Bc(),l(),s.push(r.on("narrative:generate",()=>{l(),n&&h()}),r.on("narrative:show",()=>d()),r.on("narrative:hide",()=>u()),r.on("narrative:get",()=>{t||l()}))},renderDOM(r,c){o||(o=document.createElement("button"),o.className="ng-narrative-btn",o.innerHTML='<span class="ng-narrative-btn-icon">📖</span> Story',o.title="View project narrative",o.addEventListener("click",()=>{n?u():d()}),r.appendChild(o)),i||(i=document.createElement("div"),i.className="ng-narrative-overlay",i.addEventListener("click",u),r.appendChild(i)),a||(a=document.createElement("div"),a.className="ng-narrative-panel",r.appendChild(a)),n&&(l(),h())},destroy(){for(const r of s)r();s=[],o&&(o.remove(),o=null),i&&(i.remove(),i=null),a&&(a.remove(),a=null),Fc(),e=null,t=null,n=!1}}}const Wc=864e5,Xc=10,Xn="nimbus-gantt-whatif-styles",jo=.25,zc=.6,on=6,qo="#38A169",Zo="#E53E3E",Jo="#A0AEC0",zn=36,Gc="#F6AD55",Qo="#1a202c",Vc=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${zn}px;
    background: ${Gc};
    color: ${Qo};
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
    color: ${Qo};
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
    top: ${zn}px;
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
    top: ${zn+8}px;
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
    color: ${qo};
  }
  .ng-whatif-summary-value--worsened {
    color: ${Zo};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${Jo};
  }
`;function ze(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ei(e){const t=ze(e);return`${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.getUTCMonth()]} ${t.getUTCDate()}`}function an(e,t){return Math.round((t.getTime()-e.getTime())/Wc)}function ti(){return"wi_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7)}function Kc(e){return{...e,metadata:e.metadata?{...e.metadata}:void 0}}function jc(e){return{...e}}function qc(){if(typeof document>"u"||document.getElementById(Xn))return;const e=document.createElement("style");e.id=Xn,e.textContent=Vc,document.head.appendChild(e)}function Zc(){if(typeof document>"u")return;const e=document.getElementById(Xn);e&&e.remove()}function Jc(e){const t=new Map;for(const[o,i]of e.tasks)t.set(o,Kc(i));const n=new Map;for(const[o,i]of e.dependencies)n.set(o,jc(i));let s="";for(const o of t.values())(!s||o.endDate>s)&&(s=o.endDate);return{tasks:t,dependencies:n,projectFinish:s}}function ni(e){let t="";for(const n of e.values())(!t||n.endDate>t)&&(t=n.endDate);return t}function Qc(){let e=null,t=!1,n=!1,s=!1,o=null,i=[],a=[];const l=[];let d=null,u=null,h=null,y=null,r=null,c=null,f=null;function v(){t||!e||(o=Jc(e.getState()),i=[],t=!0,n=!1,E())}function b(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),t=!1,n=!1,o=null,i=[],E(),M(),R())}function g(){!t||!e||!o||(e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())}),i=[],n=!1,D(),M())}function p(I){if(!t||!e||!o)return;a.length>=Xc&&a.shift();const O=e.getState(),A=ni(O.tasks),N=ze(o.projectFinish),U=ze(A),ee=an(N,U);let Z=0;for(const[ge,ye]of o.tasks){const Y=O.tasks.get(ge);if(!Y){Z++;continue}(Y.startDate!==ye.startDate||Y.endDate!==ye.endDate||Y.assignee!==ye.assignee)&&Z++}for(const ge of O.tasks.keys())o.tasks.has(ge)||Z++;const re={id:ti(),name:I,createdAt:Date.now(),changes:[...i],result:{projectFinish:A,criticalPathDelta:ee,tasksAffected:Z}};a.push(re),H()}function w(I){if(!e||!o)return;const O=a.find(A=>A.id===I);if(O){t||v(),e.dispatch({type:"SET_DATA",tasks:Array.from(o.tasks.values()),dependencies:Array.from(o.dependencies.values())});for(const A of O.changes)T(A);i=[...O.changes],D()}}function m(I){a=a.filter(O=>O.id!==I),H()}function T(I){if(e)switch(I.type){case"move":case"resize":I.taskId&&I.after&&I.after.startDate&&I.after.endDate&&e.dispatch({type:I.type==="move"?"TASK_MOVE":"TASK_RESIZE",taskId:I.taskId,startDate:I.after.startDate,endDate:I.after.endDate});break;case"add":I.after&&e.dispatch({type:"ADD_TASK",task:I.after});break;case"remove":I.taskId&&e.dispatch({type:"REMOVE_TASK",taskId:I.taskId});break;case"reassign":I.taskId&&I.after&&e.dispatch({type:"UPDATE_TASK",taskId:I.taskId,changes:I.after});break;case"add-dependency":I.dependency&&e.dispatch({type:"ADD_DEPENDENCY",dependency:{id:I.dependencyId||ti(),source:I.dependency.source,target:I.dependency.target,type:I.dependency.type||"FS"}});break;case"remove-dependency":I.dependencyId&&e.dispatch({type:"REMOVE_DEPENDENCY",dependencyId:I.dependencyId});break}}function S(){t&&(n=!n,n?C():M())}function k(){if(!e||!o)return{baselineFinish:"",sandboxFinish:"",deltaDays:0,tasksAffected:0};const I=e.getState(),O=ni(I.tasks),A=ze(o.projectFinish),N=ze(O),U=an(A,N);let ee=0;for(const[Z,re]of o.tasks){const ge=I.tasks.get(Z);if(!ge){ee++;continue}(ge.startDate!==re.startDate||ge.endDate!==re.endDate||ge.assignee!==re.assignee)&&ee++}for(const Z of I.tasks.keys())o.tasks.has(Z)||ee++;return{baselineFinish:o.projectFinish,sandboxFinish:O,deltaDays:U,tasksAffected:ee}}function E(){d&&d.classList.toggle("ng-hidden",!t)}function D(){y&&(y.textContent=`${i.length} change${i.length!==1?"s":""} made`)}function C(){if(!h)return;const I=k();let O="ng-whatif-summary-value--unchanged",A="No change";I.deltaDays<0?(O="ng-whatif-summary-value--improved",A=`${Math.abs(I.deltaDays)} day${Math.abs(I.deltaDays)!==1?"s":""} earlier`):I.deltaDays>0&&(O="ng-whatif-summary-value--worsened",A=`${I.deltaDays} day${I.deltaDays!==1?"s":""} later`),h.innerHTML=`
      <div class="ng-whatif-summary-title">Comparison Summary</div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Project finish</span>
        <span class="ng-whatif-summary-value">
          ${ei(I.baselineFinish)} &rarr; ${ei(I.sandboxFinish)}
        </span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Schedule impact</span>
        <span class="ng-whatif-summary-value ${O}">${A}</span>
      </div>
      <div class="ng-whatif-summary-row">
        <span class="ng-whatif-summary-label">Tasks affected</span>
        <span class="ng-whatif-summary-value">${I.tasksAffected}</span>
      </div>
    `,h.classList.remove("ng-hidden")}function M(){h&&h.classList.add("ng-hidden")}function L(){s=!s,u&&u.classList.toggle("ng-open",s),s&&H()}function R(){s=!1,u&&u.classList.remove("ng-open")}function x(){r&&(r.classList.add("ng-active"),c==null||c.focus())}function $(){r&&r.classList.remove("ng-active"),c&&(c.value="")}function _(){if(!c)return;const I=c.value.trim();I&&(p(I),$())}function H(){if(f){if(a.length===0){f.innerHTML='<div class="ng-whatif-empty">No saved scenarios yet</div>';return}f.innerHTML=a.map(I=>{var U;const O=new Date(I.createdAt).toLocaleDateString(),A=((U=I.result)==null?void 0:U.criticalPathDelta)??0;let N="No impact";return A<0?N=`${Math.abs(A)}d earlier`:A>0&&(N=`${A}d later`),`
          <div class="ng-whatif-scenario-card" data-scenario-id="${I.id}">
            <div class="ng-whatif-scenario-name">${W(I.name)}</div>
            <div class="ng-whatif-scenario-meta">
              <span>${O}</span>
              <span>${I.changes.length} changes</span>
              <span>${N}</span>
            </div>
            <div class="ng-whatif-scenario-actions">
              <button class="ng-whatif-scenario-btn" data-action="load" data-id="${I.id}">Load</button>
              <button class="ng-whatif-scenario-btn" data-action="compare" data-id="${I.id}">Compare</button>
              <button class="ng-whatif-scenario-btn ng-whatif-scenario-btn--delete" data-action="delete" data-id="${I.id}">Delete</button>
            </div>
          </div>
        `}).join("")}}function W(I){const O=document.createElement("div");return O.textContent=I,O.innerHTML}function K(I){const O=I.target,A=O.getAttribute("data-action"),N=O.getAttribute("data-id");if(!(!A||!N))switch(A){case"load":w(N),R();break;case"compare":w(N),n=!0,C(),R();break;case"delete":m(N);break}}function q(I,O){switch(I.type){case"TASK_MOVE":{const A=O.tasks.get(I.taskId);A&&i.push({type:"move",taskId:I.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"TASK_RESIZE":{const A=O.tasks.get(I.taskId);A&&i.push({type:"resize",taskId:I.taskId,before:{startDate:A.startDate,endDate:A.endDate},after:{startDate:I.startDate,endDate:I.endDate}});break}case"ADD_TASK":i.push({type:"add",taskId:I.task.id,after:{...I.task}});break;case"REMOVE_TASK":i.push({type:"remove",taskId:I.taskId,before:O.tasks.get(I.taskId)?{...O.tasks.get(I.taskId)}:void 0});break;case"UPDATE_TASK":{const A=O.tasks.get(I.taskId);A&&i.push({type:"reassign",taskId:I.taskId,before:{...A},after:I.changes});break}case"ADD_DEPENDENCY":i.push({type:"add-dependency",dependencyId:I.dependency.id,dependency:{source:I.dependency.source,target:I.dependency.target,type:I.dependency.type}});break;case"REMOVE_DEPENDENCY":i.push({type:"remove-dependency",dependencyId:I.dependencyId});break}D()}function F(I,O,A,N,U,ee){const Z=Math.min(ee,N/2,U/2);I.beginPath(),I.moveTo(O+Z,A),I.lineTo(O+N-Z,A),I.arcTo(O+N,A,O+N,A+Z,Z),I.lineTo(O+N,A+U-Z),I.arcTo(O+N,A+U,O+N-Z,A+U,Z),I.lineTo(O+Z,A+U),I.arcTo(O,A+U,O,A+U-Z,Z),I.lineTo(O,A+Z),I.arcTo(O,A,O+Z,A,Z),I.closePath()}return{name:"WhatIfPlugin",install(I){e=I,qc(),l.push(I.on("whatif:enter",()=>v())),l.push(I.on("whatif:exit",()=>b())),l.push(I.on("whatif:compare",()=>S())),l.push(I.on("whatif:discard",()=>g())),l.push(I.on("whatif:save",(...O)=>{const A=typeof O[0]=="string"?O[0]:void 0;A?p(A):x()})),l.push(I.on("whatif:load",(...O)=>{const A=typeof O[0]=="string"?O[0]:void 0;A?w(A):L()})),l.push(I.on("whatif:list-scenarios",(...O)=>{const A=typeof O[0]=="function"?O[0]:void 0;A?A([...a]):L()})),l.push(I.on("whatif:delete-scenario",(...O)=>{const A=typeof O[0]=="string"?O[0]:void 0;A&&m(A)}))},middleware(I,O){if(!t){O(I);return}if(["TASK_MOVE","TASK_RESIZE","ADD_TASK","REMOVE_TASK","UPDATE_TASK","ADD_DEPENDENCY","REMOVE_DEPENDENCY"].includes(I.type)&&e){const N=e.getState();q(I,N)}O(I)},renderCanvas(I,O,A){if(!t||!e)return;const{theme:N,headerHeight:U,barHeight:ee}=O.config,Z=O.scrollX,re=O.scrollY,ge=U,ye=e.getTimeScale(),Y=N.barBorderRadius;if(I.save(),I.beginPath(),I.rect(0,ge,I.canvas.width,I.canvas.height-ge),I.clip(),I.translate(-Z,0),o){const te=new Set;for(const j of A){const Q=o.tasks.get(j.taskId),se=O.tasks.get(j.taskId);(!Q&&se||Q&&se&&(Q.startDate!==se.startDate||Q.endDate!==se.endDate||Q.assignee!==se.assignee))&&te.add(j.taskId)}for(const j of A){if(!te.has(j.taskId))continue;const Q=j.x,se=j.barY-re,de=j.width,ie=j.barHeight;se+ie<ge||se>I.canvas.height||(I.save(),I.setLineDash([4,3]),I.strokeStyle="#F6AD55",I.lineWidth=2,F(I,Q,se,de,ie,Y),I.stroke(),I.restore())}}if(n&&o){const te=ee*zc;for(const j of A){if(j.isMilestone)continue;const Q=o.tasks.get(j.taskId);if(!Q)continue;const se=O.tasks.get(j.taskId);if(!se)continue;const de=ze(Q.startDate),ie=ze(Q.endDate),fe=ze(se.startDate),ce=ze(se.endDate),Te=an(de,fe),be=an(ie,ce);if(Te===0&&be===0)continue;let X=Jo;be<0?X=qo:be>0&&(X=Zo);const P=ye.dateToX(de),B=ye.dateToX(ie),z=Math.max(B-P,2),G=j.barY-re,V=G+ee+2;I.save(),I.globalAlpha=jo,I.fillStyle=X,F(I,P,V,z,te,Y),I.fill(),I.globalAlpha=jo*2,I.strokeStyle=X,I.lineWidth=1,I.stroke(),I.restore();const ne=P+z/2,oe=V+te/2,ae=j.x+j.width/2,le=G+ee/2;I.save(),I.globalAlpha=.6,I.strokeStyle=X,I.lineWidth=1.5,I.setLineDash([3,2]),I.beginPath(),I.moveTo(ne,oe),I.lineTo(ae,le),I.stroke();const pe=Math.atan2(le-oe,ae-ne),ve=ae,Ie=le;I.setLineDash([]),I.beginPath(),I.moveTo(ve,Ie),I.lineTo(ve-on*Math.cos(pe-Math.PI/6),Ie-on*Math.sin(pe-Math.PI/6)),I.lineTo(ve-on*Math.cos(pe+Math.PI/6),Ie-on*Math.sin(pe+Math.PI/6)),I.closePath(),I.fillStyle=X,I.fill(),I.restore()}}I.restore()},renderDOM(I,O){if(!d){d=document.createElement("div"),d.className="ng-whatif-banner ng-hidden";const A=document.createElement("div");A.className="ng-whatif-banner-left";const N=document.createElement("span");N.className="ng-whatif-badge",N.textContent="What-If Mode",A.appendChild(N);const U=document.createElement("span");U.textContent="Changes are hypothetical",U.style.fontSize="12px",U.style.opacity="0.7",A.appendChild(U);const ee=document.createElement("span");ee.textContent="·",ee.style.opacity="0.4",A.appendChild(ee),y=document.createElement("span"),y.className="ng-whatif-change-count",y.textContent="0 changes made",A.appendChild(y),d.appendChild(A);const Z=document.createElement("div");Z.className="ng-whatif-banner-right",r=document.createElement("div"),r.className="ng-whatif-save-input",c=document.createElement("input"),c.type="text",c.placeholder="Scenario name...",c.addEventListener("keydown",se=>{se.key==="Enter"&&_(),se.key==="Escape"&&$()});const re=document.createElement("button");re.className="ng-whatif-btn ng-whatif-btn--primary",re.textContent="Save",re.addEventListener("click",_);const ge=document.createElement("button");ge.className="ng-whatif-btn",ge.textContent="Cancel",ge.addEventListener("click",()=>$()),r.appendChild(c),r.appendChild(re),r.appendChild(ge),Z.appendChild(r);const ye=document.createElement("button");ye.className="ng-whatif-btn",ye.textContent="Scenarios",ye.addEventListener("click",()=>L()),Z.appendChild(ye);const Y=document.createElement("button");Y.className="ng-whatif-btn ng-whatif-btn--primary",Y.textContent="Compare with Baseline",Y.addEventListener("click",()=>S()),Z.appendChild(Y);const te=document.createElement("button");te.className="ng-whatif-btn",te.textContent="Save Scenario",te.addEventListener("click",()=>x()),Z.appendChild(te);const j=document.createElement("button");j.className="ng-whatif-btn ng-whatif-btn--danger",j.textContent="Discard",j.addEventListener("click",()=>g()),Z.appendChild(j);const Q=document.createElement("button");Q.className="ng-whatif-btn ng-whatif-btn--danger",Q.textContent="Exit",Q.addEventListener("click",()=>b()),Z.appendChild(Q),d.appendChild(Z),I.appendChild(d)}if(h||(h=document.createElement("div"),h.className="ng-whatif-summary ng-hidden",I.appendChild(h)),!u){u=document.createElement("div"),u.className="ng-whatif-panel";const A=document.createElement("div");A.className="ng-whatif-panel-title";const N=document.createElement("span");N.textContent="Saved Scenarios",A.appendChild(N);const U=document.createElement("button");U.className="ng-whatif-panel-close",U.textContent="×",U.addEventListener("click",()=>R()),A.appendChild(U),u.appendChild(A),f=document.createElement("div"),f.addEventListener("click",K),u.appendChild(f),I.appendChild(u),H()}E(),n&&C()},destroy(){for(const I of l)I();l.length=0,d&&(d.remove(),d=null),u&&(u.remove(),u=null),h&&(h.remove(),h=null),y=null,r=null,c=null,f=null,Zc(),t=!1,n=!1,s=!1,o=null,i=[],a=[],e=null}}}const Gn={major:[0,2,4,5,7,9,11],minor:[0,2,3,5,7,8,10],pentatonic:[0,2,4,7,9],chromatic:[0,1,2,3,4,5,6,7,8,9,10,11]},ed=261.63;function td(e){return ed*Math.pow(2,e/12)}function nd(e,t,n){const s=t.length,o=Math.floor(e/s),i=e%s,a=t[i]+o*12;return td(n?a+12:a)}const Vn="nimbus-gantt-sonification-styles",Kn=64,rn=64,si=.05,sd=.1,od=.7,oi=.2,jn="#F6AD55",id=2,ad="rgba(246, 173, 85, 0.35)",ii=12,rd=`
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
    height: ${Kn}px;
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
`;function qn(e){const[t,n,s]=e.split("-").map(Number);return new Date(Date.UTC(t,n-1,s))}function ld(){if(typeof document>"u"||document.getElementById(Vn))return;const e=document.createElement("style");e.id=Vn,e.textContent=rd,document.head.appendChild(e)}function cd(){if(typeof document>"u")return;const e=document.getElementById(Vn);e&&e.remove()}function dd(e){let t=(e==null?void 0:e.tempo)??120,n=(e==null?void 0:e.scale)??"major",s=(e==null?void 0:e.instrument)??"sine",o=(e==null?void 0:e.duration)??10,i=(e==null?void 0:e.volume)??.3,a=null,l=null,d=null,u=null,h=null;const y=new Map;let r="stopped",c=0,f=0,v=0,b=0,g=0,p=0,w=0,m=null,T=null,S=null,k=null,E=null,D=null;const C=[];let M=[],L=[];function R(){if(l)return;const Y=typeof window<"u"&&(window.AudioContext||window.webkitAudioContext)||null;Y&&(l=new Y,d=l.createGain(),d.gain.value=i,u=l.createAnalyser(),u.fftSize=256,h=new Uint8Array(u.frequencyBinCount),d.connect(u),u.connect(l.destination))}function x(){l&&l.state==="suspended"&&l.resume()}function $(){if(!a)return;const Y=a.getState(),te=Date.now();let j=1/0,Q=-1/0;const se=[],de=new Set,ie=Y.flatVisibleIds,fe=new Map;for(let ce=0;ce<ie.length;ce++)fe.set(ie[ce],ce);for(const[ce,Te]of Y.tasks){const be=qn(Te.startDate).getTime(),X=qn(Te.endDate).getTime();be<j&&(j=be),X>Q&&(Q=X);const P=Te.groupId||"__default__";de.add(P);const B=fe.get(ce)??0,z=!Te.isCompleted&&X<te&&(Te.progress??0)<1;se.push({id:ce,startMs:be,endMs:X,rowIndex:B,progress:Te.progress??0,groupId:P,isCritical:!1,isOverdue:z})}M=se,L=Array.from(de),g=j===1/0?0:j,p=Q===-1/0?0:Q,w=Math.max(p-g,1)}function _(Y){if(!l||!d||y.has(Y.id))return;const te=Gn[n]||Gn.major,j=nd(Y.rowIndex,te,Y.isCritical),Q=l.createOscillator();Q.type=s,Q.frequency.value=j,Y.isOverdue&&(Q.detune.value=25);const se=.3+Y.progress*.7,de=Y.isOverdue?1.3:1,ie=Math.min(se*de,1),fe=l.createGain();fe.gain.setValueAtTime(0,l.currentTime),fe.gain.linearRampToValueAtTime(ie,l.currentTime+si),fe.gain.linearRampToValueAtTime(ie*od,l.currentTime+si+sd);const ce=l.createStereoPanner();if(L.length<=1)ce.pan.value=0;else{const Te=L.indexOf(Y.groupId);ce.pan.value=L.length>1?Te/(L.length-1)*2-1:0}Q.connect(fe),fe.connect(ce),ce.connect(d),Q.start(),y.set(Y.id,{taskId:Y.id,oscillator:Q,gainNode:fe,panNode:ce})}function H(Y){const te=y.get(Y);if(!te||!l)return;const j=l.currentTime;te.gainNode.gain.cancelScheduledValues(j),te.gainNode.gain.setValueAtTime(te.gainNode.gain.value,j),te.gainNode.gain.linearRampToValueAtTime(0,j+oi),te.oscillator.stop(j+oi+.05),y.delete(Y)}function W(){for(const Y of Array.from(y.keys()))H(Y)}function K(){if(r!=="playing"||!l)return;const Y=l.currentTime-c;if(f=Math.min(Y/o,1),f>=1){I();return}const te=g+f*w;for(const j of M){const Q=te>=j.startMs&&te<j.endMs,se=y.has(j.id);Q&&!se?_(j):!Q&&se&&H(j.id)}Z(),b=requestAnimationFrame(K)}function q(){R(),x(),l&&($(),r==="paused"?c=l.currentTime-v*o:(c=l.currentTime,f=0),r="playing",N(),U(),b=requestAnimationFrame(K))}function F(){r==="playing"&&(r="paused",v=f,W(),cancelAnimationFrame(b),N())}function I(){r="stopped",f=0,v=0,W(),cancelAnimationFrame(b),N(),ee()}function O(){r==="playing"?F():q()}function A(Y){const te=qn(Y).getTime(),j=Math.max(0,Math.min((te-g)/w,1));r==="playing"&&l?c=l.currentTime-j*o:(v=j,f=j)}function N(){E&&(r==="playing"?(E.innerHTML=ge(),E.classList.add("ng-son-btn--active")):(E.innerHTML=re(),E.classList.remove("ng-son-btn--active")))}function U(){T&&T.classList.remove("ng-hidden")}function ee(){T&&T.classList.add("ng-hidden")}function Z(){if(!u||!h||!k||!S)return;u.getByteFrequencyData(h);const Y=S.width,te=S.height;k.clearRect(0,0,Y,te);const j=k.createLinearGradient(0,0,0,te);j.addColorStop(0,"rgba(26, 32, 44, 0)"),j.addColorStop(1,"rgba(26, 32, 44, 0.6)"),k.fillStyle=j,k.fillRect(0,0,Y,te);const Q=Y/rn*.8,se=Y/rn*.2,de=Math.floor(h.length/rn);for(let ie=0;ie<rn;ie++){let fe=0;for(let z=0;z<de;z++)fe+=h[ie*de+z]??0;const ce=fe/de,Te=ce/255*te*.85,be=ie*(Q+se),X=te-Te,P=30+ce/255*15,B=55+ce/255*15;k.fillStyle=`hsl(${P}, 90%, ${B}%)`,k.fillRect(be,X,Q,Te)}}function re(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>'}function ge(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>'}function ye(){return'<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z"/></svg>'}return{name:"SonificationPlugin",install(Y){a=Y,ld(),C.push(Y.on("sonification:play",()=>q())),C.push(Y.on("sonification:pause",()=>F())),C.push(Y.on("sonification:stop",()=>I())),C.push(Y.on("sonification:scrub",(...te)=>{const j=typeof te[0]=="string"?te[0]:void 0;j&&A(j)})),C.push(Y.on("sonification:configure",(...te)=>{const j=te[0];j&&(j.tempo!==void 0&&(t=j.tempo),j.scale!==void 0&&(n=j.scale),j.instrument!==void 0&&(s=j.instrument),j.duration!==void 0&&(o=j.duration),j.volume!==void 0&&(i=j.volume,d&&(d.gain.value=i)))}))},renderCanvas(Y,te,j){if(r==="stopped"||!a)return;const{headerHeight:Q}=te.config,se=te.scrollX,de=te.scrollY,ie=Q,fe=a.getTimeScale(),ce=g+f*w,Te=new Date(ce),be=fe.dateToX(Te);Y.save(),Y.beginPath(),Y.rect(0,ie,Y.canvas.width,Y.canvas.height-ie),Y.clip(),Y.translate(-se,0),Y.save(),Y.shadowColor=jn,Y.shadowBlur=ii,Y.strokeStyle=jn,Y.lineWidth=id,Y.beginPath(),Y.moveTo(be,ie),Y.lineTo(be,Y.canvas.height+de),Y.stroke(),Y.restore();const X=new Map;for(const P of j)X.set(P.taskId,P);for(const P of y.values()){const B=X.get(P.taskId);if(!B)continue;const z=B.x,G=B.barY-de,V=B.width,ne=B.barHeight;if(G+ne<ie||G>Y.canvas.height)continue;const oe=((l==null?void 0:l.currentTime)??0)*4%(2*Math.PI),ae=.15+.15*Math.sin(oe);Y.save(),Y.globalAlpha=ae,Y.shadowColor=ad,Y.shadowBlur=ii,Y.fillStyle=jn;const le=Math.min(te.config.theme.barBorderRadius,V/2,ne/2);Y.beginPath(),Y.moveTo(z+le,G),Y.lineTo(z+V-le,G),Y.arcTo(z+V,G,z+V,G+le,le),Y.lineTo(z+V,G+ne-le),Y.arcTo(z+V,G+ne,z+V-le,G+ne,le),Y.lineTo(z+le,G+ne),Y.arcTo(z,G+ne,z,G+ne-le,le),Y.lineTo(z,G+le),Y.arcTo(z,G,z+le,G,le),Y.closePath(),Y.fill(),Y.restore()}Y.restore()},renderDOM(Y,te){if(!m){m=document.createElement("div"),m.className="ng-sonification-controls",E=document.createElement("button"),E.className="ng-son-btn",E.innerHTML=re(),E.title="Play / Pause",E.addEventListener("click",()=>O()),m.appendChild(E),D=document.createElement("button"),D.className="ng-son-btn",D.innerHTML=ye(),D.title="Stop",D.addEventListener("click",()=>I()),m.appendChild(D);const j=document.createElement("div");j.className="ng-son-sep",m.appendChild(j);const Q=document.createElement("div");Q.style.display="flex",Q.style.flexDirection="column",Q.style.alignItems="center",Q.style.gap="2px";const se=document.createElement("span");se.className="ng-son-label",se.textContent="Tempo",Q.appendChild(se);const de=document.createElement("input");de.type="range",de.className="ng-son-slider",de.min="40",de.max="240",de.value=String(t),de.addEventListener("input",()=>{t=Number(de.value),o=120/t*((e==null?void 0:e.duration)??10)}),Q.appendChild(de),m.appendChild(Q);const ie=document.createElement("div");ie.style.display="flex",ie.style.flexDirection="column",ie.style.alignItems="center",ie.style.gap="2px";const fe=document.createElement("span");fe.className="ng-son-label",fe.textContent="Scale",ie.appendChild(fe);const ce=document.createElement("select");ce.className="ng-son-select";for(const B of Object.keys(Gn)){const z=document.createElement("option");z.value=B,z.textContent=B.charAt(0).toUpperCase()+B.slice(1),B===n&&(z.selected=!0),ce.appendChild(z)}ce.addEventListener("change",()=>{n=ce.value}),ie.appendChild(ce),m.appendChild(ie);const Te=document.createElement("div");Te.className="ng-son-sep",m.appendChild(Te);const be=document.createElement("div");be.style.display="flex",be.style.flexDirection="column",be.style.alignItems="center",be.style.gap="2px";const X=document.createElement("span");X.className="ng-son-label",X.textContent="Vol",be.appendChild(X);const P=document.createElement("input");P.type="range",P.className="ng-son-slider",P.min="0",P.max="100",P.value=String(Math.round(i*100)),P.addEventListener("input",()=>{i=Number(P.value)/100,d&&(d.gain.value=i)}),be.appendChild(P),m.appendChild(be),Y.appendChild(m)}if(!T){T=document.createElement("div"),T.className="ng-sonification-waveform ng-hidden",S=document.createElement("canvas"),k=S.getContext("2d");const j=(typeof window<"u"?window.devicePixelRatio:1)||1,Q=Y.getBoundingClientRect();S.width=Q.width*j,S.height=Kn*j,S.style.width="100%",S.style.height=Kn+"px",k&&k.scale(j,j),T.appendChild(S),Y.appendChild(T)}},destroy(){for(const Y of C)Y();C.length=0,I(),W(),l&&(l.close(),l=null),d=null,u=null,h=null,m&&(m.remove(),m=null),T&&(T.remove(),T=null),S=null,k=null,E=null,D=null,cd(),a=null,M=[],L=[]}}}const ud=.55,gd=[4,3],hd=1,fd=4,pd=600;function md(e={}){let t=null;const n=ai(e.futureFadeStrength??ud,0,1),s=e.futureDashedBorder!==!1,o=e.futureDashPattern??gd,i=e.futureDashWidth??hd,a=e.pastShowCheckmark!==!1,l=e.todayProvider??(()=>new Date);return{name:"TemporalAsymmetryPlugin",install(d){t=d},renderCanvas(d,u,h){if(!t||h.length===0)return;const{config:y,scrollX:r,scrollY:c,tasks:f}=u,{theme:v}=y,b=y.headerHeight,g=v.barBorderRadius,p=l();let w;try{w=t.getTimeScale().dateToX(p)}catch{return}const m=e.futureFadeColor??v.timelineBg??"#ffffff",T=typeof window<"u"&&window.devicePixelRatio||1,S=d.canvas.width/T,k=d.canvas.height/T;d.save();const E=b,D=k-E;d.beginPath(),d.rect(0,E,S,D),d.clip(),d.translate(-r,0);for(const C of h){if(C.isMilestone)continue;const M=f.get(C.taskId);if(!M||M.status==="group-header")continue;const L=C.x,R=C.barY-c,x=C.width,$=C.barHeight;if(R+$<0||R>D)continue;const _=L+x,H=L>=w,W=_<=w,K=!H&&!W;if(H||K){const q=H?L:w,F=H?x:_-w;F>.5&&(d.save(),d.beginPath(),ri(d,L,R,x,$,g),d.clip(),d.globalAlpha=n,d.fillStyle=m,d.fillRect(q,R,F,$),d.restore())}if(s&&(H||K)){const q=e.futureDashColor??Td(C.color,.4);if(d.save(),d.lineWidth=i,d.strokeStyle=q,d.setLineDash(o),H)yd(d,L,R,x,$,g);else{const F=R+.5,I=R+$-.5;d.beginPath(),d.moveTo(w,F),d.lineTo(_-g,F),d.moveTo(w,I),d.lineTo(_-g,I),d.moveTo(w,R),d.lineTo(w,R+$),d.stroke()}d.setLineDash([]),d.restore()}if(a&&W&&(M.progress??0)>=1){const q=L+fd+5,F=R+$/2,I=e.pastCheckmarkColor??bd(C.color);d.save(),d.font=`${pd} ${Math.max(10,v.fontSize-1)}px ${v.fontFamily}`,d.textBaseline="middle",d.textAlign="left",d.fillStyle=I,d.fillText("✓",q-5,F),d.restore()}}d.restore()},destroy(){t=null}}}function ai(e,t,n){return Math.max(t,Math.min(n,e))}function ri(e,t,n,s,o,i){const a=Math.min(i,s/2,o/2);e.moveTo(t+a,n),e.lineTo(t+s-a,n),e.quadraticCurveTo(t+s,n,t+s,n+a),e.lineTo(t+s,n+o-a),e.quadraticCurveTo(t+s,n+o,t+s-a,n+o),e.lineTo(t+a,n+o),e.quadraticCurveTo(t,n+o,t,n+o-a),e.lineTo(t,n+a),e.quadraticCurveTo(t,n,t+a,n)}function yd(e,t,n,s,o,i){e.beginPath(),ri(e,t,n,s,o,i),e.stroke()}function Td(e,t){const n=li(e);if(!n)return e;const s=Math.round((n.r+n.g+n.b)/3),o=i=>Math.round(i*(1-t)+s*t);return vd(o(n.r),o(n.g),o(n.b))}function bd(e){const t=li(e);return t?.299*t.r+.587*t.g+.114*t.b>140?"#1f2937":"#ffffff":"#1f2937"}function li(e){const t=e.replace("#","");return t.length===3?{r:parseInt(t[0]+t[0],16),g:parseInt(t[1]+t[1],16),b:parseInt(t[2]+t[2],16)}:t.length===6?{r:parseInt(t.substring(0,2),16),g:parseInt(t.substring(2,4),16),b:parseInt(t.substring(4,6),16)}:null}function vd(e,t,n){const s=o=>ai(o,0,255).toString(16).padStart(2,"0");return`#${s(e)}${s(t)}${s(n)}`}const wd=5e3,Sd=3e4,kd=500,Ed=new Set(["SET_DATA","UPDATE_TASK","ADD_TASK","REMOVE_TASK","TASK_MOVE","TASK_RESIZE","ADD_DEPENDENCY","REMOVE_DEPENDENCY"]);function tt(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),kind:e,...t??{}})}function Dd(e={}){const t=Math.max(100,e.capacity??wd),n=e.compactAfterIdleMs??Sd,s=Math.min(t,Math.max(50,e.compactKeep??kd)),o=[],i=[];let a=null,l=null,d=null,u=null;function h(){u&&clearTimeout(u),u=setTimeout(y,n)}function y(){if(o.length<=s)return;const p=o.length-s;o.splice(0,p),tt("history:compaction",{dropped:p,kept:o.length})}function r(p){var w;if(o.push(p),tt("history:entry-recorded",{actionType:p.action.type,ts:p.wallTs,source:p.source}),o.length>t){const m=o.splice(0,1);tt("history:overflow-drop",{ts:(w=m[0])==null?void 0:w.wallTs})}if(h(),e.onEntry)try{const m=e.onEntry(p);m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}e.hydrate&&o.push(...e.hydrate),e.hydrateAnnotations&&i.push(...e.hydrateAnnotations);function c(p,w){switch(w.type){case"SET_DATA":{const m=Array.from(p.tasks.values()),T=Array.from(p.dependencies.values());return{type:"SET_DATA",tasks:m,dependencies:T}}case"UPDATE_TASK":{const m=p.tasks.get(w.taskId);if(!m)return null;const T={};for(const S of Object.keys(w.changes))T[S]=m[S];return{type:"UPDATE_TASK",taskId:w.taskId,changes:T}}case"ADD_TASK":return{type:"REMOVE_TASK",taskId:w.task.id};case"REMOVE_TASK":{const m=p.tasks.get(w.taskId);return m?{type:"ADD_TASK",task:m}:null}case"TASK_MOVE":case"TASK_RESIZE":{const m=p.tasks.get(w.taskId);return m?{type:w.type,taskId:w.taskId,startDate:m.startDate,endDate:m.endDate}:null}case"ADD_DEPENDENCY":return{type:"REMOVE_DEPENDENCY",dependencyId:w.dependency.id};case"REMOVE_DEPENDENCY":{const m=p.dependencies.get(w.dependencyId);return m?{type:"ADD_DEPENDENCY",dependency:m}:null}default:return null}}function f(p,w){if(!Ed.has(p.type)){w(p);return}const m=a?a():null;if(!m){w(p);return}const T=c(m,p);w(p);const S=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),k=Date.now();r({ts:S,wallTs:k,action:p,inverse:T,actor:e.defaultActor,source:e.defaultSource??"local"})}function v(p){if(!a)return null;const w=p.getTime(),m=a();if(o.length===0)return m;const T=o[0].wallTs;if(w<T)return tt("history:snapshot-miss",{target:w,baselineTs:T}),null;const S=new ln(m);for(let k=o.length-1;k>=0;k--){const E=o[k];if(E.wallTs<=w)break;E.inverse&&S.dispatch(E.inverse)}return S.getState()}function b(p){const w=typeof performance<"u"&&typeof performance.now=="function"?performance.now():Date.now(),m=Date.now(),T={ts:w,wallTs:m,...p};if(i.push(T),tt("history:annotation-added",{kind:T.kind,taskId:T.taskId}),e.onAnnotation)try{const S=e.onAnnotation(T);S&&typeof S.catch=="function"&&S.catch(()=>{})}catch{}}const g={entries:()=>o,annotations:()=>i,snapshotAt:v,appendAnnotation:b,lastWallTs:()=>o.length>0?o[o.length-1].wallTs:null,scrubTo:p=>{l==null||l.setTimeCursor(p),tt("history:scrub",{cursorWallTs:p?p.getTime():null})},scrubToNow:()=>{l==null||l.setTimeCursor(null),tt("history:scrub",{cursorWallTs:null})}};return{name:"HistoryPlugin",install(p){a=p.getState,l=p.__gantt??null,l&&(l.history=g,typeof l.registerReplayProvider=="function"&&(d=l.registerReplayProvider({snapshotAt:w=>v(w)}))),tt("history:hydrate",{entryCount:o.length})},middleware:f,destroy(){u&&(clearTimeout(u),u=null),d&&(d(),d=null),l&&l.history===g&&(l.history=null),l=null}}}const Cd="#3b82f6",Id=2,Md="#10b981",Ad=864e5;function Ld(e={}){let t=null,n=null,s=null;const o=e.cursorColor??Cd,i=e.cursorWidth??Id,a=e.showNowBracket!==!1,l=e.nowBracketColor??Md,d=e.enableKeyboardShortcuts!==!1,u=e.stepMs??Ad;function h(c){if(!n)return;const v=n.getTimeCursor()??new Date,b=new Date(v.getTime()+c);n.setTimeCursor(b)}function y(){if(!(n!=null&&n.history))return;const c=n.history.entries();c.length!==0&&n.setTimeCursor(new Date(c[0].wallTs))}function r(c){const f=document.activeElement;if(!(f&&(f.tagName==="INPUT"||f.tagName==="TEXTAREA"||f.isContentEditable))){if(c.key==="Home"){c.preventDefault(),y();return}if(c.key==="End"){c.preventDefault(),n==null||n.setTimeCursor(null);return}if(c.key==="ArrowLeft"&&(c.altKey||c.metaKey)){c.preventDefault(),h(-u);return}if(c.key==="ArrowRight"&&(c.altKey||c.metaKey)){c.preventDefault(),h(u);return}}}return{name:"TimeCursorPlugin",install(c){t=c,n=c.__gantt??null,d&&typeof document<"u"&&(s=r,document.addEventListener("keydown",s))},renderCanvas(c,f,v){if(!t)return;const{config:b,scrollX:g}=f,p=b.headerHeight,w=typeof window<"u"&&window.devicePixelRatio||1,m=c.canvas.width/w,T=c.canvas.height/w,S=p,k=T-S;let E;try{E=t.getTimeScale()}catch{return}if(c.save(),c.beginPath(),c.rect(0,S,m,k),c.clip(),c.translate(-g,0),a){const C=E.dateToX(new Date);c.save(),c.strokeStyle=l,c.lineWidth=3,c.beginPath(),c.moveTo(C-6,S+1),c.lineTo(C+6,S+1),c.moveTo(C-6,S+k-1),c.lineTo(C+6,S+k-1),c.stroke(),c.restore()}const D=f.timeCursorDate;if(D){const C=E.dateToX(D);c.save(),c.strokeStyle=o,c.lineWidth=i,c.beginPath(),c.moveTo(C,S),c.lineTo(C,S+k),c.stroke(),c.fillStyle=o,c.beginPath(),c.moveTo(C-6,S),c.lineTo(C+6,S),c.lineTo(C,S+8),c.closePath(),c.fill(),c.restore()}c.restore()},destroy(){s&&typeof document<"u"&&document.removeEventListener("keydown",s),s=null,t=null,n=null}}}const Rd=14,Pd=4,_d=6,$d="#6b7280",Od={comment:"#3b82f6",decision:"#8b5cf6","agent-note":"#10b981",view:"#a3a3a3"};function Nd(e={}){let t=null,n=null;const s=e.height??Rd,o=e.position??"above-body",i=e.markerRadius??Pd,a=e.clusterDistancePx??_d,l=e.fallbackColor??$d,d={...Od,...e.colorByKind??{}};return{name:"HistoryStripPlugin",install(u){t=u,n=u.__gantt??null},renderCanvas(u,h,y){if(!t||!(n!=null&&n.history))return;const r=n.history.annotations();if(r.length===0)return;const{config:c,scrollX:f}=h,v=c.headerHeight,b=typeof window<"u"&&window.devicePixelRatio||1,g=u.canvas.width/b;let p;try{p=t.getTimeScale()}catch{return}const w=o==="above-body"?v-s:v+2;u.save(),u.beginPath(),u.rect(0,w,g,s),u.clip(),u.translate(-f,0);const m=[];for(const k of r){const E=p.dateToX(new Date(k.wallTs));m.push({x:E,ann:k})}m.sort((k,E)=>k.x-E.x);const T=[];for(const k of m){const E=T[T.length-1];E&&Math.abs(k.x-E.x)<=a?(E.entries.push(k),E.x=E.entries.reduce((D,C)=>D+C.x,0)/E.entries.length):T.push({x:k.x,entries:[k]})}const S=[];for(const k of T){const E=w+s/2,D=k.entries.length>1,C=k.entries[0].ann.kind,M=d[C]??l;u.fillStyle=M,u.beginPath(),u.arc(k.x,E,D?i+1:i,0,Math.PI*2),u.fill(),D&&(u.fillStyle="#ffffff",u.font="600 9px sans-serif",u.textBaseline="middle",u.textAlign="center",u.fillText(String(k.entries.length),k.x,E+.5)),S.push({cx:k.x,cy:E,r:D?i+1:i,annotations:k.entries.map(L=>L.ann)})}u.restore()},destroy(){t=null,n=null}}}const ci="nimbus-gantt-ctxmenu-styles",me="ng-ctxmenu",di={maxCalls:1,windowMs:2e3};function Hd(e){if(e===!1)return()=>!0;const t=e??di,n=[];return function(){const o=Date.now(),i=o-t.windowMs;for(;n.length>0&&n[0]<i;)n.shift();return n.length>=t.maxCalls?!1:(n.push(o),!0)}}function ui(e,t){if(typeof window>"u")return;const n=window.__nga_diag;Array.isArray(n)&&n.push({t:Date.now(),kind:e,...t??{}})}function xd(e={}){let t=null,n=null,s=null,o=null,i=null,a=null;const l=Hd(e.agentRateLimit===void 0?di:e.agentRateLimit);async function d(g,p){if(e.onConfirmDestructive)try{return!!await e.onConfirmDestructive(g,p)}catch{return!1}if(typeof window<"u"&&typeof window.confirm=="function"){const w=g==="task"?`Delete task "${p}"?`:`Delete dependency "${p}"?`;try{return window.confirm(w)}catch{return!1}}return!0}function u(){if(typeof document>"u"||document.getElementById(ci))return;const g=document.createElement("style");g.id=ci,g.textContent=`
      .${me} {
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
      .${me}-item {
        padding: 6px 12px;
        cursor: pointer;
        display: flex;
        align-items: center;
        gap: 8px;
        white-space: nowrap;
      }
      .${me}-item:hover { background: #f1f5f9; }
      .${me}-item[aria-disabled="true"] { color: #94a3b8; cursor: default; }
      .${me}-item[aria-disabled="true"]:hover { background: transparent; }
      .${me}-icon { width: 16px; text-align: center; font-size: 12px; }
      .${me}-label { flex: 1; }
      .${me}-shortcut { color: #94a3b8; font-size: 11px; margin-left: auto; }
      .${me}-arrow { color: #94a3b8; }
      .${me}-divider { border-top: 1px solid #e2e8f0; margin: 4px 0; }
      .${me}-agent-glyph { color: #8b5cf6; font-weight: 600; }
      .${me}-submenu { position: relative; }
    `,document.head.appendChild(g)}function h(){if(s){try{s.remove()}catch{}s=null}a&&typeof document<"u"&&(document.removeEventListener("pointerdown",a,!0),document.removeEventListener("keydown",a,!0),a=null)}function y(g,p,w){if(typeof document>"u"||g.length===0)return;h(),u();const m=document.createElement("div");m.className=me,m.setAttribute("role","menu"),m.style.left=`${p.x}px`,m.style.top=`${p.y}px`,m.addEventListener("pointerdown",T=>{T.stopPropagation()});for(const T of g){if(T.divider){const D=document.createElement("div");D.className=`${me}-divider`,m.appendChild(D);continue}const S=document.createElement("div");S.className=`${me}-item`,T.disabled&&S.setAttribute("aria-disabled","true");const k=document.createElement("span");k.className=`${me}-icon`,T.agentSuggested&&k.classList.add(`${me}-agent-glyph`),k.textContent=T.icon??(T.agentSuggested?"✦":""),S.appendChild(k);const E=document.createElement("span");if(E.className=`${me}-label`,E.textContent=T.label,S.appendChild(E),T.shortcut){const D=document.createElement("span");D.className=`${me}-shortcut`,D.textContent=T.shortcut,S.appendChild(D)}if(T.children&&T.children.length>0){const D=document.createElement("span");D.className=`${me}-arrow`,D.textContent="▸",S.appendChild(D);let C=null;S.addEventListener("mouseenter",()=>{if(C)return;const M=S.getBoundingClientRect();C=document.createElement("div"),C.className=me,C.style.left=`${M.right+2}px`,C.style.top=`${M.top}px`;for(const L of T.children){const R=r(L,w);C.appendChild(R)}document.body.appendChild(C)}),S.addEventListener("mouseleave",()=>{if(C){try{C.remove()}catch{}C=null}})}else T.disabled||S.addEventListener("click",D=>{D.stopPropagation(),c(T,w,p)});m.appendChild(S)}document.body.appendChild(m),s=m,a=T=>{T instanceof KeyboardEvent&&T.key!=="Escape"||h()},document.addEventListener("pointerdown",a,!0),document.addEventListener("keydown",a,!0),requestAnimationFrame(()=>{if(!s)return;const T=s.getBoundingClientRect(),S=window.innerWidth,k=window.innerHeight;let E=T.left,D=T.top;T.right>S&&(E=Math.max(4,S-T.width-4)),T.bottom>k&&(D=Math.max(4,k-T.height-4)),s.style.left=`${E}px`,s.style.top=`${D}px`})}function r(g,p){if(g.divider){const S=document.createElement("div");return S.className=`${me}-divider`,S}const w=document.createElement("div");w.className=`${me}-item`,g.disabled&&w.setAttribute("aria-disabled","true");const m=document.createElement("span");m.className=`${me}-icon`,g.agentSuggested&&m.classList.add(`${me}-agent-glyph`),m.textContent=g.icon??(g.agentSuggested?"✦":""),w.appendChild(m);const T=document.createElement("span");return T.className=`${me}-label`,T.textContent=g.label,w.appendChild(T),g.disabled||w.addEventListener("click",S=>{S.stopPropagation(),c(g,p,{x:0,y:0})}),w}function c(g,p,w){if(h(),g.agentSuggested&&g.prompt&&e.onAgentRequest&&(t!=null&&t.agent)){if(!l()){ui("ctxmenu:agent-rate-limited",{itemId:g.id});return}const m={hit:p,pos:w,prompt:g.prompt,snapshot:t.agent.getSnapshot()};try{const T=e.onAgentRequest(m);T&&typeof T.catch=="function"&&T.catch(()=>{})}catch{}return}if(g.onClick)try{const m=g.onClick();m&&typeof m.catch=="function"&&m.catch(()=>{})}catch{}}function f(g,p,w){return async()=>{await d(g,p)?w():ui("ctxmenu:destructive-cancelled",{kind:g,label:p})}}function v(g,p){const w=[],m=!!e.onAgentRequest&&!e.hideAgentSubmenu;switch(g.zone){case"bar":return w.push({id:"edit",label:"Edit task…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",g.task,p)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",g.task,p)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",g.task,p)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",g.task,p)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",g.task,p)})}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-why",label:"Ask Claude: why is this scheduled here?",agentSuggested:!0,prompt:`Explain why task "${g.task.name}" (id ${g.task.id}) is scheduled from ${g.task.startDate} to ${g.task.endDate} given current dependencies, parent context, and bucket assignment.`},{id:"agent-blocks",label:"Ask Claude: what blocks this?",agentSuggested:!0,prompt:`What dependencies, capacity constraints, or upstream blockers are gating task "${g.task.name}" (id ${g.task.id})? Walk the dependency graph and list the critical path.`},{id:"agent-resched",label:"Ask Claude: reschedule with critical-path optimization",agentSuggested:!0,prompt:`Suggest a new schedule for task "${g.task.name}" (id ${g.task.id}) that optimizes the critical path. Stage hypotheses via gantt.agent if possible.`}),w;case"row-label":return w.push({id:"edit",label:"Edit name…",icon:"✎",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"edit",g.task,p)}},{id:"reparent",label:"Change parent…",icon:"↳",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"reparent",g.task,p)}},{id:"change-bucket",label:"Change bucket…",icon:"◧",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"change-bucket",g.task,p)}},{id:"mark-complete",label:"Mark complete",icon:"✓",onClick:()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"mark-complete",g.task,p)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete",icon:"×",onClick:f("task",g.task.name||g.task.id,()=>{var T;return(T=e.onTaskAction)==null?void 0:T.call(e,"delete",g.task,p)})}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-summarize",label:"Ask Claude: summarize this task",agentSuggested:!0,prompt:`Summarize task "${g.task.name}" (id ${g.task.id}) including its current status, parent, dependencies, and recent history if available.`}),w;case"date-header":{const T=g.date.toISOString().slice(0,10);return w.push({id:"scroll-here",label:`Scroll to ${T}`,icon:"↔",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"scroll-here",g.date,p)}},{id:"zoom-to",label:"Zoom to this range",icon:"⊕",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"zoom-to",g.date,p)}},{id:"add-milestone",label:`Add milestone on ${T}`,icon:"◆",onClick:()=>{var S;return(S=e.onDateAction)==null?void 0:S.call(e,"add-milestone",g.date,p)}}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-summary",label:`Ask Claude: what's happening around ${T}?`,agentSuggested:!0,prompt:`Summarize tasks, milestones, and dependencies that intersect ${T}. Note any clusters, conflicts, or capacity hotspots.`}),w}case"canvas-empty":{const T=g.date.toISOString().slice(0,10),S=T,k=(()=>{const E=new Date(g.date);return E.setUTCDate(E.getUTCDate()+5),E.toISOString().slice(0,10)})();return w.push({id:"create-task",label:`Create work item starting ${T}`,icon:"＋",onClick:()=>{var E,D;return(D=e.onCreateTask)==null?void 0:D.call(e,{startDate:S,endDate:k,parentId:((E=g.nearestTask)==null?void 0:E.parentId)??null,bucket:g.bucketId},p)}},{id:"create-milestone",label:`Insert milestone on ${T}`,icon:"◆",onClick:()=>{var E,D;return(D=e.onCreateTask)==null?void 0:D.call(e,{startDate:T,endDate:T,parentId:((E=g.nearestTask)==null?void 0:E.parentId)??null,bucket:g.bucketId},p)}}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-suggest",label:"Ask Claude: suggest a task here",agentSuggested:!0,prompt:`Given the project context and the dates around ${T}${g.bucketId?` in bucket "${g.bucketId}"`:""}, suggest a sensible work item to insert. Consider open dependencies, capacity, and priority.`}),w}case"bucket-header":{const T=g.bucketTask.name||g.bucketId||"(bucket)";return w.push({id:"add-to-bucket",label:`Add task to ${T}`,icon:"＋",onClick:()=>{var S;return(S=e.onCreateTask)==null?void 0:S.call(e,{startDate:new Date().toISOString().slice(0,10),endDate:new Date(Date.now()+432e6).toISOString().slice(0,10),parentId:g.bucketTask.id,bucket:g.bucketId},p)}},{id:"collapse",label:`Collapse all in ${T}`,icon:"⊟",onClick:()=>{var S;return(S=e.onTaskAction)==null?void 0:S.call(e,"collapse",g.bucketTask,p)}},{id:"expand",label:`Expand all in ${T}`,icon:"⊞",onClick:()=>{var S;return(S=e.onTaskAction)==null?void 0:S.call(e,"expand",g.bucketTask,p)}}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-rebalance",label:`Ask Claude: rebalance ${T}`,agentSuggested:!0,prompt:`Review the tasks in bucket "${T}" for capacity, sequencing, and priority alignment. Suggest moves to/from adjacent buckets and reordering within.`}),w}case"below-rows":{const T=g.date.toISOString().slice(0,10);return w.push({id:"create-end",label:`Add new task at end (starts ${T})`,icon:"＋",onClick:()=>{var S;return(S=e.onCreateTask)==null?void 0:S.call(e,{startDate:T,endDate:new Date(g.date.getTime()+432e6).toISOString().slice(0,10),parentId:null,bucket:null},p)}}),w}case"dependency":return w.push({id:"change-fs",label:"Change type → Finish-to-Start (FS)",icon:"→",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-fs",g.depId,p)}},{id:"change-ss",label:"Change type → Start-to-Start (SS)",icon:"↦",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ss",g.depId,p)}},{id:"change-ff",label:"Change type → Finish-to-Finish (FF)",icon:"↤",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-ff",g.depId,p)}},{id:"change-sf",label:"Change type → Start-to-Finish (SF)",icon:"↔",onClick:()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"change-type-sf",g.depId,p)}},{id:"div1",label:"",divider:!0},{id:"delete",label:"Delete dependency",icon:"×",onClick:f("dependency",g.depId,()=>{var T;return(T=e.onDependencyAction)==null?void 0:T.call(e,"delete",g.depId,p)})}),m&&w.push({id:"div-agent",label:"",divider:!0},{id:"agent-explain-dep",label:"Ask Claude: is this dependency necessary?",agentSuggested:!0,prompt:`Evaluate dependency ${g.depId}. Is it logically required, or could the predecessor and successor run in parallel? Consider data flow, resource contention, and external constraints.`}),w;case"outside":default:return[]}}function b(g){if(!t||!n||g.button!==void 0&&g.button!==2)return;const p=t.hitTestAt(g.clientX,g.clientY);if(p.zone==="outside")return;g.preventDefault(),g.stopPropagation();const w={x:g.clientX,y:g.clientY};let m=null;if(e.onContextMenu)try{m=e.onContextMenu(p,w)}catch{m=null}const T=m&&Array.isArray(m)&&m.length>0?m:v(p,w);T.length>0&&y(T,w,p)}return{name:"ContextMenuPlugin",install(g){t=g.__gantt??null,n=(t&&t.rootEl)??null;const p=n??(typeof document<"u"?document:null);p&&(o=w=>b(w),p.addEventListener("contextmenu",o),e.disablePointerDownFallback||(i=w=>{w.button===2&&b(w)},p.addEventListener("pointerdown",i)))},destroy(){h();const g=n??(typeof document<"u"?document:null);g&&(o&&g.removeEventListener("contextmenu",o),i&&g.removeEventListener("pointerdown",i)),o=null,i=null,t=null,n=null}}}return J.BaselinePlugin=Aa,J.CLOUD_NIMBUS_PRIORITY_BUCKETS=ga,J.ConfigPanelPlugin=Sl,J.ContextMenuPlugin=xd,J.CriticalPathPlugin=ba,J.DARK_THEME=fs,J.DarkThemePlugin=Xa,J.DependencyRenderer=us,J.EventBus=Qn,J.ExportPlugin=Ha,J.GroupingPlugin=la,J.HeatmapViewPlugin=_l,J.HistoryPlugin=Dd,J.HistoryStripPlugin=Nd,J.HitTest=ls,J.KeyboardPlugin=Xi,J.LIGHT_THEME=gn,J.LayoutEngine=os,J.MSProjectPlugin=rr,J.MilestonePlugin=Zi,J.MiniMapPlugin=zl,J.MonteCarloPlugin=Pc,J.MotionControlPlugin=tr,J.NarrativePlugin=Yc,J.NetworkGraphPlugin=ml,J.NimbusGantt=Hi,J.PriorityGroupingPlugin=ua,J.ResourceLevelingPlugin=Cr,J.RiskAnalysisPlugin=Jr,J.SonificationPlugin=dd,J.SplitTaskPlugin=yr,J.TelemetryPlugin=Ja,J.TemporalAsymmetryPlugin=md,J.TimeCursorPlugin=Ld,J.TimeScale=ns,J.TimeTravelPlugin=bc,J.TimelineNotesPlugin=lc,J.TooltipManager=hs,J.UndoRedoPlugin=Yi,J.VirtualScrollPlugin=_a,J.WhatIfPlugin=Qc,J.WorkCalendarPlugin=ja,J.computeCPM=mn,J.exportMSProjectXML=Dn,J.getAllParentIds=ys,J.getDescendantIds=Ts,J.hoursWeightedProgress=ha,J.importMSProjectXML=En,J.parseDate=pt,J.resolveConfig=ps,J.rollupHoursDeduped=Fi,Object.defineProperty(J,Symbol.toStringTag,{value:"Module"}),J})({});typeof window<"u"&&(window.NimbusGantt=NimbusGantt);
//# sourceMappingURL=nimbus-gantt.iife.js.map
